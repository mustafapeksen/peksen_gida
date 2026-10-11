-- Phase 10 / F10-01. No delivery mutations, payment corrections or stock-shortage approvals.
begin;
alter table public.orders drop constraint orders_credit_check_state_check;
alter table public.orders add constraint orders_credit_check_state_check
 check (credit_check_state in ('not_evaluated','within_limit','exceeded','approved','rejected'));
comment on column public.orders.credit_check_state is 'F10-01: NULL legacy; not_evaluated unconfigured limit; within_limit/exceeded checkout evaluation; approved/rejected explicit credit decision. Submission never posts delivery debt.';
alter table public.order_approvals add column approval_kind text not null default 'legacy'
 check (approval_kind in ('legacy','stock','credit'));
comment on column public.order_approvals.approval_kind is 'Legacy reasons are never guessed. Only explicit credit requests may be decided by Phase 10.';
alter table public.audit_logs drop constraint audit_logs_action_check;
alter table public.audit_logs add constraint audit_logs_action_check check(action in (
 'price_changed','stock_movement','stock_count_approved','order_status_changed','alternative_accepted','alternative_rejected',
 'payment_recorded','payment_corrected','payment_cancelled','credit_approved','credit_rejected','delivery_disputed',
 'delivery_resolved','role_changed','permission_changed','order_request_decided','payment_verified','credit_limit_changed'));
create table private.finance_receipts (
 operation_key uuid primary key, actor_id uuid not null references public.profiles(id),
 payload jsonb not null, response jsonb not null
);
alter table private.finance_receipts enable row level security;
revoke all on private.finance_receipts from public,anon,authenticated;

create function private.delivery_finalized(target uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.delivery_confirmations c where c.order_id=target and c.finalizes_delivery
  and (c.event_type='resolution' or (c.event_type='customer' and c.customer_confirmed and
   exists(select 1 from public.delivery_confirmations d where d.order_id=target and d.event_type='driver' and d.driver_confirmed))));
$$;
-- NULL means unresolved facts, never zero debt. Closed correction/dispute workflows cannot be inferred.
create function private.order_balance(target uuid) returns numeric
language plpgsql stable security definer set search_path='' as $$
declare o public.orders; paid numeric;
begin
 select * into o from public.orders where id=target;
 if not found or o.status<>'delivered' or o.payment_status='disputed' or not private.delivery_finalized(target) then return null; end if;
 if exists(select 1 from public.payments p where p.order_id=target and
   (p.verification_status not in ('recorded','verified') or exists(select 1 from public.payment_adjustments a where a.payment_id=p.id))) then return null; end if;
 select coalesce(sum(payment_amount_kurus),0) into paid from public.payments where order_id=target;
 if paid>o.total_kurus then return null; end if;
 return o.total_kurus-paid;
end; $$;
create function private.customer_exposure(target uuid) returns numeric
language plpgsql stable security definer set search_path='' as $$
declare o public.orders; balance numeric; exposure numeric:=0;
begin
 for o in select * from public.orders where customer_id=target and status in
 ('delivered','submitted','picking','picked','assigned','loaded','out_for_delivery','delivery_pending_confirmation','delivery_disputed') loop
  if o.status='delivered' then
   balance:=private.order_balance(o.id);
   if balance is null then return null; end if;
   exposure:=exposure+balance;
  else
   -- An active order contributes its amount exactly once. No delivery/dispute resolution is invented.
   if exists(select 1 from public.payments where order_id=o.id) then return null; end if;
   exposure:=exposure+o.total_kurus;
  end if;
 end loop;
 return exposure;
end; $$;
create function private.finance_scope(target uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select coalesce(exists(select 1 from public.orders o join public.customers c on c.id=o.customer_id where o.id=target and (
  private.current_app_role() in ('manager','owner') or
  (c.active and (private.sales_customer(c.id) or
   (private.current_app_role()='accounting' and c.assigned_sales_operator_id is not null) or
   (private.current_app_role()='driver' and exists(select 1 from public.delivery_stops s join public.delivery_runs r on r.id=s.run_id
    where s.order_id=o.id and s.closed_at is null and r.ended_at is null and private.assigned_run(r.id))))))),false);
$$;
create function private.finance_actor(request_key uuid, payload jsonb, allowed public.app_role[]) returns jsonb
language plpgsql security definer set search_path='' as $$
declare previous private.finance_receipts;
begin
 perform 1 from auth.users where id=auth.uid() for share;
 perform 1 from public.profiles where id=auth.uid() for share;
 if not coalesce(private.current_app_role()=any(allowed),false) then
  raise exception using errcode='42501',message='Finance action denied'; end if;
 if request_key is null then raise exception using errcode='22023',message='Key required'; end if;
 perform pg_advisory_xact_lock(hashtextextended(request_key::text,73010));
 select * into previous from private.finance_receipts where operation_key=request_key;
 if found then
  if previous.actor_id<>auth.uid() or previous.payload<>payload then
   raise exception using errcode='22023',message='Key already used with different payload'; end if;
  return previous.response;
 end if;
 return null;
end; $$;

create function public.record_payment(target_order uuid,amount_kurus bigint,payment_method text,payment_note text,request_key uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare payload jsonb:=jsonb_build_object('action','record','order',target_order,'amount',amount_kurus,'method',payment_method,'note',payment_note);
 result jsonb; customer uuid; o public.orders; balance numeric; payment uuid;
begin
 result:=private.finance_actor(request_key,payload,array['sales_operator','driver']::public.app_role[]);
 select customer_id into customer from public.orders where id=target_order;
 perform 1 from public.customers where id=customer for update;
 select * into o from public.orders where id=target_order for update;
 -- Lock assignment facts too; recheck scope after waiting for the locks.
 if private.current_app_role()='driver' then
  perform 1 from public.delivery_runs r where r.id in(select run_id from public.delivery_stops where order_id=target_order and closed_at is null) order by r.id for share;
  perform 1 from public.delivery_stops where order_id=target_order and closed_at is null order by id for share;
 end if;
 if not private.finance_scope(target_order) then raise exception using errcode='42501',message='Payment scope denied'; end if;
 if result is not null then return result; end if;
 if amount_kurus is null or amount_kurus<=0 or payment_method is null or payment_method not in ('cash','pos') then
  raise exception using errcode='22023',message='Positive amount and cash or POS required'; end if;
 balance:=private.order_balance(target_order);
 if balance is null then raise exception using errcode='23514',message='Finalized delivery and unambiguous balance required'; end if;
 if amount_kurus>balance then raise exception using errcode='23514',message='Overpayment denied'; end if;
 insert into public.payments(order_id,payment_amount_kurus,method,collector_user_id,collected_at,verification_status,note,operation_key)
 values(target_order,amount_kurus,payment_method,auth.uid(),now(),'recorded',payment_note,request_key) returning id into payment;
 -- Collection changes the payment cache only; due snapshots and delivery facts remain historical.
 update public.orders set payment_status=case when balance=amount_kurus then 'paid' else 'partial' end where id=target_order;
 insert into public.audit_logs(actor_id,action,entity_type,entity_id,new_data,operation_key)
 values(auth.uid(),'payment_recorded','payment',payment,jsonb_build_object('order_id',target_order,'amount_kurus',amount_kurus::text,'method',payment_method),request_key);
 result:=jsonb_build_object('payment_id',payment,'status','recorded','balance_kurus',(balance-amount_kurus)::text);
 insert into private.finance_receipts values(request_key,auth.uid(),payload,result);
 return result;
end; $$;

create function public.verify_payment(target_payment uuid,request_key uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare payload jsonb:=jsonb_build_object('action','verify','payment',target_payment); result jsonb; p public.payments; customer uuid; target uuid;
begin
 result:=private.finance_actor(request_key,payload,array['accounting']::public.app_role[]);
 select o.customer_id,o.id into customer,target from public.payments pay join public.orders o on o.id=pay.order_id where pay.id=target_payment;
 perform 1 from public.customers where id=customer for update;
 perform 1 from public.orders where id=target for update;
 select * into p from public.payments where id=target_payment for update;
 if not private.finance_scope(target) then raise exception using errcode='42501',message='Verification scope denied'; end if;
 if result is not null then return result; end if;
 if p.verification_status<>'recorded' or private.order_balance(target) is null then
  raise exception using errcode='23514',message='Only unambiguous recorded payments can be verified'; end if;
 update public.payments set verification_status='verified',verified_by=auth.uid(),verified_at=now() where id=target_payment;
 insert into public.audit_logs(actor_id,action,entity_type,entity_id,new_data,operation_key)
 values(auth.uid(),'payment_verified','payment',target_payment,jsonb_build_object('order_id',target),request_key);
 result:=jsonb_build_object('payment_id',target_payment,'status','verified');
 insert into private.finance_receipts values(request_key,auth.uid(),payload,result);
 return result;
end; $$;

create function public.set_customer_credit_limit(target_customer uuid,limit_kurus bigint,reason text,request_key uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare payload jsonb:=jsonb_build_object('action','limit','customer',target_customer,'limit',limit_kurus,'reason',reason); result jsonb; c public.customers;
begin
 result:=private.finance_actor(request_key,payload,array['manager','owner']::public.app_role[]);
 select * into c from public.customers where id=target_customer for update;
 if not found then raise exception using errcode='23514',message='Customer not found'; end if;
 if result is not null then return result; end if;
 if limit_kurus is null or limit_kurus<0 or nullif(btrim(reason),'') is null then
  raise exception using errcode='22023',message='Nonnegative limit and reason required'; end if;
 update public.customers set credit_limit_kurus=limit_kurus where id=target_customer;
 insert into public.audit_logs(actor_id,action,entity_type,entity_id,old_data,new_data,operation_key)
 values(auth.uid(),'credit_limit_changed','customer',target_customer,jsonb_build_object('limit_kurus',c.credit_limit_kurus::text),
 jsonb_build_object('limit_kurus',limit_kurus::text,'reason',btrim(reason)),request_key);
 result:=jsonb_build_object('customer_id',target_customer,'limit_kurus',limit_kurus::text);
 insert into private.finance_receipts values(request_key,auth.uid(),payload,result);
 return result;
end; $$;

create function public.decide_credit_approval(target_approval uuid,approve boolean,reason text,request_key uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare payload jsonb:=jsonb_build_object('action','credit','approval',target_approval,'approve',approve,'reason',reason);
 result jsonb; a public.order_approvals; o public.orders; customer uuid; target uuid; i public.order_items; stock public.inventory;
 movement uuid; movement_key uuid; amount numeric; next_status public.order_state;
begin
 result:=private.finance_actor(request_key,payload,array['manager','owner']::public.app_role[]);
 select x.customer_id,x.id into customer,target from public.order_approvals p join public.orders x on x.id=p.order_id where p.id=target_approval;
 perform 1 from public.customers where id=customer for update;
 select * into o from public.orders where id=target for update;
 select * into a from public.order_approvals where id=target_approval for update;
 if not found then raise exception using errcode='23514',message='Approval not found'; end if;
 if result is not null then return result; end if;
 if approve is null or nullif(btrim(decide_credit_approval.reason),'') is null then raise exception using errcode='22023',message='Decision and reason required'; end if;
 if a.approval_kind<>'credit' or a.status<>'pending' or o.status<>'pending_approval' or o.credit_check_state<>'exceeded' then
  raise exception using errcode='23514',message='Only pending credit approvals may be decided'; end if;
 if not exists(select 1 from public.customers where id=customer and active) then raise exception using errcode='23514',message='Inactive customer'; end if;
 if approve then
  perform 1 from public.order_items where order_id=target order by id for update;
  perform 1 from public.inventory where product_id in(select product_id from public.order_items where order_id=target) order by product_id for update;
  if not exists(select 1 from public.order_items where order_id=target) or exists(select 1 from public.order_items where order_id=target and picked_qty<>0)
   or exists(select 1 from public.inventory_movements m join public.order_items oi on oi.id=m.order_item_id where oi.order_id=target)
   or exists(select 1 from (select product_id,sum(quantity*conversion_to_base_snapshot) qty from public.order_items where order_id=target group by product_id) x
    left join public.inventory v on v.product_id=x.product_id where v.product_id is null or v.available_qty<x.qty) then
   raise exception using errcode='23514',message='Snapshot stock unavailable or order already affected'; end if;
  for i in select * from public.order_items where order_id=target order by id loop
   amount:=i.quantity*i.conversion_to_base_snapshot; movement_key:=gen_random_uuid();
   update public.inventory set reserved_qty=reserved_qty+amount where product_id=i.product_id returning * into stock;
   insert into public.inventory_movements(warehouse_id,product_id,type,quantity,physical_delta,reserved_delta,order_item_id,reference_type,reference_id,unit,conversion_to_base_snapshot,created_by,operation_key)
   values(stock.warehouse_id,i.product_id,'reserved',amount,0,amount,i.id,'order',target,i.unit,i.conversion_to_base_snapshot,auth.uid(),movement_key) returning id into movement;
   insert into public.audit_logs(actor_id,action,entity_type,entity_id,new_data,operation_key)
   values(auth.uid(),'stock_movement','inventory_movement',movement,jsonb_build_object('order_id',target,'base_quantity',amount::text),movement_key);
  end loop;
 end if;
 next_status:=case when approve then 'submitted'::public.order_state else 'rejected'::public.order_state end;
 update public.order_approvals set status=case when approve then 'approved' else 'rejected' end,
  decided_by=auth.uid(),decided_at=now(),decision_reason=btrim(decide_credit_approval.reason),operation_key=request_key where id=target_approval;
 update public.orders set status=next_status,credit_check_state=case when approve then 'approved' else 'rejected' end,credit_warning=not approve where id=target;
 insert into public.order_status_history(order_id,from_status,to_status,changed_by,reason,operation_key)
 values(target,o.status,next_status,auth.uid(),btrim(decide_credit_approval.reason),request_key);
 insert into public.audit_logs(actor_id,action,entity_type,entity_id,new_data,operation_key)
 values(auth.uid(),case when approve then 'credit_approved' else 'credit_rejected' end,'order',target,jsonb_build_object('approval_id',target_approval,'reason',btrim(decide_credit_approval.reason),'status',next_status),request_key);
 result:=jsonb_build_object('order_id',target,'status',next_status);
 insert into private.finance_receipts values(request_key,auth.uid(),payload,result);
 return result;
end; $$;

-- Small allowlisted projections; Accounting never receives item prices or audit records.
create function public.finance_workspace(section text) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare role public.app_role:=private.current_app_role(); result jsonb;
begin
 if role is null or role not in ('sales_operator','driver','accounting','manager','owner') then
  raise exception using errcode='42501',message='Finance workspace denied'; end if;
 if section='customers' then
  if role not in ('manager','owner') then raise exception using errcode='42501',message='Credit management denied'; end if;
  select coalesce(jsonb_agg(jsonb_build_object('id',c.id,'name',c.company_name,'limit_kurus',c.credit_limit_kurus::text,
   'exposure_kurus',private.customer_exposure(c.id)::text) order by c.company_name,c.id),'[]') into result from public.customers c;
 elsif section='approvals' then
  if role not in ('manager','owner') then raise exception using errcode='42501',message='Credit decisions denied'; end if;
  select coalesce(jsonb_agg(jsonb_build_object('id',a.id,'order_id',o.id,'name',c.company_name,'amount_kurus',o.total_kurus::text,
   'exposure_kurus',a.projected_exposure_kurus::text,'limit_kurus',a.credit_limit_kurus::text) order by o.created_at,o.id),'[]') into result
  from public.order_approvals a join public.orders o on o.id=a.order_id join public.customers c on c.id=o.customer_id
  where a.approval_kind='credit' and a.status='pending' and o.status='pending_approval';
 elsif section='orders' then
  select coalesce(jsonb_agg(jsonb_build_object('id',o.id,'name',c.company_name,'amount_kurus',o.total_kurus::text,
   'balance_kurus',private.order_balance(o.id)::text,'due_date',coalesce(o.due_date, o.delivered_at +
      coalesce(o.payment_due_days_snapshot,c.payment_due_days,(select (value #>> '{}')::int from public.app_settings where key='default_payment_due_days')) * interval '1 day'),
   'payments',coalesce((select jsonb_agg(jsonb_build_object('id',p.id,'amount_kurus',p.payment_amount_kurus::text,'method',p.method,
     'status',p.verification_status,'collector_id',p.collector_user_id,'collected_at',p.collected_at,'verified_at',p.verified_at) order by p.collected_at,p.id)
     from public.payments p where p.order_id=o.id),'[]'::jsonb)) order by o.created_at,o.id),'[]') into result
   from public.orders o join public.customers c on c.id=o.customer_id where o.status='delivered' and private.finance_scope(o.id);
 else raise exception using errcode='22023',message='Unknown finance section'; end if;
 return result;
end; $$;
revoke all on function private.delivery_finalized(uuid),private.order_balance(uuid),private.customer_exposure(uuid),private.finance_scope(uuid),private.finance_actor(uuid,jsonb,public.app_role[]) from public,anon,authenticated;
revoke all on function public.record_payment(uuid,bigint,text,text,uuid),public.verify_payment(uuid,uuid),public.set_customer_credit_limit(uuid,bigint,text,uuid),public.decide_credit_approval(uuid,boolean,text,uuid),public.finance_workspace(text) from public,anon,authenticated;
grant execute on function public.record_payment(uuid,bigint,text,text,uuid),public.verify_payment(uuid,uuid),public.set_customer_credit_limit(uuid,bigint,text,uuid),public.decide_credit_approval(uuid,boolean,text,uuid),public.finance_workspace(text) to authenticated;

-- Checkout replacement follows: existing quote, snapshot and retry contract is retained.

create or replace function public.checkout_cart(target_customer uuid,items jsonb,accepted_quote jsonb,request_key uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare normalized jsonb; request jsonb; previous private.checkout_receipts; q jsonb; result jsonb;
 new_order uuid; new_item uuid; movement_id uuid; movement_key uuid; line jsonb; next_status public.order_state; stock public.inventory;
 credit_state text:='not_evaluated'; credit_limit bigint; exposure numeric; cause text;
begin
 if request_key is null or accepted_quote is null or jsonb_typeof(accepted_quote)<>'object' then
  raise exception using errcode='22023',message='Quote confirmation and request key required'; end if;
 perform 1 from auth.users where id=auth.uid() for share;
 perform 1 from public.profiles where id=auth.uid() for share;
 perform pg_advisory_xact_lock(hashtextextended(request_key::text,73006));
 perform 1 from public.customers where id=target_customer for update;
 if not private.can_shop(target_customer) then raise exception using errcode='42501',message='Checkout access denied'; end if;
 normalized:=private.normalized_cart(items);
 request:=jsonb_build_object('items',normalized,'accepted_quote',accepted_quote);
 select * into previous from private.checkout_receipts where operation_key=request_key;
 if found then
  if previous.actor_id<>auth.uid() or previous.customer_id<>target_customer or previous.request<>request then
   raise exception using errcode='22023',message='Request key already used with different payload'; end if;
  return previous.response;
 end if;
 -- Stable lock order; all price/quantity reads are repeated after these locks.
 perform 1 from public.categories c where c.id in (select p.category_id from public.products p
  join public.product_units u on u.product_id=p.id where u.id in(select (value->>'unit_id')::uuid from jsonb_array_elements(normalized))) order by c.id for share;
 perform 1 from public.products p where p.id in(select u.product_id from public.product_units u
  where u.id in(select (value->>'unit_id')::uuid from jsonb_array_elements(normalized))) order by p.id for share;
 perform 1 from public.product_units u where u.id in(select (value->>'unit_id')::uuid from jsonb_array_elements(normalized)) order by u.id for share;
 -- Protect missing discount rows too; customer lock is not required of legacy writers.
 lock table public.customer_pricing in share mode;
 perform 1 from public.inventory i where i.product_id in(select u.product_id from public.product_units u
  where u.id in(select (value->>'unit_id')::uuid from jsonb_array_elements(normalized))) order by i.product_id for update;
 q:=public.quote_cart(target_customer,normalized);
 if accepted_quote<>q then
  return jsonb_build_object('outcome','changed','previous_quote',accepted_quote,'quote',q,
    'message','Fiyat, birim veya stok değişti. Güncel kalemleri yeniden onaylayın.');
 end if;
 select credit_limit_kurus into credit_limit from public.customers where id=target_customer;
 if credit_limit is not null then
  exposure:=private.customer_exposure(target_customer);
  if exposure is null then raise exception using errcode='23514',message='Credit balance requires review'; end if;
  exposure:=exposure+(q->>'total_kurus')::numeric;
  if exposure>9223372036854775807::numeric then raise exception using errcode='22003',message='Exposure exceeds storage range'; end if;
  credit_state:=case when exposure>credit_limit then 'exceeded' else 'within_limit' end;
 end if;
 cause:=case when not (q->>'stock_sufficient')::boolean then 'stock' when credit_state='exceeded' then 'credit' end;
 next_status:=case when cause is null then 'submitted'::public.order_state else 'pending_approval'::public.order_state end;
 insert into public.orders(customer_id,created_by,source,status,payment_status,subtotal_kurus,discount_total_kurus,total_kurus,
  credit_warning,credit_check_state,operation_key)
 values(target_customer,auth.uid(),case when private.current_app_role()='customer' then 'customer_app' else 'sales_operator' end,
  next_status,'not_due',(q->>'subtotal_kurus')::bigint,(q->>'discount_total_kurus')::bigint,(q->>'total_kurus')::bigint,credit_state<>'within_limit',credit_state,request_key)
 returning id into new_order;
 for line in select value from jsonb_array_elements(q->'lines') loop
  insert into public.order_items(order_id,product_id,product_unit_id,unit,conversion_to_base_snapshot,quantity,
   unit_price_kurus,discount_rate_snapshot,final_unit_price_kurus,line_total_kurus,exact_list_price_kurus_snapshot,exact_final_price_kurus_snapshot)
  values(new_order,(line->>'product_id')::uuid,(line->>'product_unit_id')::uuid,line->>'unit',
   (line->>'conversion_to_base_snapshot')::numeric,(line->>'quantity')::integer,(line->>'unit_price_kurus')::bigint,
   (line->>'discount_rate_snapshot')::numeric,(line->>'final_unit_price_kurus')::bigint,(line->>'line_total_kurus')::bigint,
   (line->>'exact_list_price_kurus_snapshot')::numeric,(line->>'exact_final_price_kurus_snapshot')::numeric) returning id into new_item;
  if next_status='submitted' then
   movement_key:=gen_random_uuid();
   update public.inventory set reserved_qty=reserved_qty+(line->>'base_quantity')::numeric
    where product_id=(line->>'product_id')::uuid returning * into stock;
   insert into public.inventory_movements(warehouse_id,product_id,type,quantity,physical_delta,reserved_delta,order_item_id,
    reference_type,reference_id,unit,conversion_to_base_snapshot,created_by,operation_key)
   values(stock.warehouse_id,stock.product_id,'reserved',(line->>'base_quantity')::numeric,0,(line->>'base_quantity')::numeric,new_item,
    'order',new_order,line->>'unit',(line->>'conversion_to_base_snapshot')::numeric,auth.uid(),movement_key) returning id into movement_id;
   insert into public.audit_logs(actor_id,action,entity_type,entity_id,new_data,operation_key)
    values(auth.uid(),'stock_movement','inventory_movement',movement_id,
     jsonb_build_object('type','reserved','order_id',new_order,'base_quantity',line->>'base_quantity'),movement_key);
  end if;
 end loop;
 if next_status='pending_approval' then
  insert into public.order_approvals(order_id,reason,requested_by,status,approval_kind,projected_exposure_kurus,credit_limit_kurus)
   values(new_order,case when cause='stock' then 'Stok yetersiz; yönetici kararı gerekli.' else 'Cari limit aşımı; yönetici kararı gerekli.' end,
    auth.uid(),'pending',cause,exposure::bigint,credit_limit);
 end if;
 insert into public.order_status_history(order_id,to_status,changed_by,reason,operation_key)
 values(new_order,next_status,auth.uid(),'Müşteri fiyat onayı; cari kontrol: '||credit_state,request_key);
 insert into public.audit_logs(actor_id,action,entity_type,entity_id,new_data,operation_key)
 values(auth.uid(),'order_status_changed','order',new_order,jsonb_build_object('status',next_status,'credit_check_state',credit_state,'approval_cause',cause),request_key);
 result:=jsonb_build_object('outcome','created','order_id',new_order,'status',next_status,'quote',q,'credit_check_state',credit_state,'approval_cause',cause);
 insert into private.checkout_receipts values(request_key,auth.uid(),target_customer,request,new_order,result);
 -- Do not erase a newer draft saved from another device.
 delete from private.cart_drafts d where d.actor_id=auth.uid() and d.customer_id=target_customer and d.items=normalized;
 return result;
end;
$$;

commit;
