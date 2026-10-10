-- Phase 8: alternative intent only. No item, price or inventory mutation.
begin;
alter table public.order_change_requests add column decision_note text;
-- Do not fabricate notes on historical immutable decisions. NOT VALID skips
-- only old rows; every new INSERT/UPDATE must satisfy the complete evidence.
alter table public.order_change_requests add constraint request_decision_note_required check (
 status='pending' or (decided_by is not null and decided_at is not null and nullif(btrim(decision_note),'') is not null)
) not valid;
alter table public.order_change_requests add constraint request_id_order_unique unique(id,order_id);
alter table public.order_status_history
 add column event_type text not null default 'status_changed',
 add column request_id uuid,
 add column request_decision text;
alter table public.order_status_history drop constraint order_status_history_check;
alter table public.order_status_history add constraint order_history_event_contract check (
 (event_type='status_changed' and request_id is null and request_decision is null and from_status is distinct from to_status)
 or (event_type='request_decided' and request_id is not null and request_decision is not null and request_decision in ('approved','rejected')
   and from_status is not null and from_status=to_status and to_status='submitted' and nullif(btrim(reason),'') is not null)
), add constraint history_request_same_order foreign key(request_id,order_id) references public.order_change_requests(id,order_id);
create unique index one_history_per_request_decision on public.order_status_history(request_id) where request_id is not null;
create function private.check_request_history() returns trigger
language plpgsql security definer set search_path='' as $$
declare r public.order_change_requests;
begin
 if new.event_type='request_decided' then
  select * into r from public.order_change_requests where id=new.request_id;
  if not found or row(new.order_id,new.request_decision,new.changed_by,new.reason)
   is distinct from row(r.order_id,r.status,r.decided_by,r.decision_note) then
   raise exception using errcode='23514',message='History must match request decision'; end if;
 end if;
 return new;
end;
$$;
revoke all on function private.check_request_history() from public,anon,authenticated;
create trigger request_history_evidence before insert on public.order_status_history
 for each row execute function private.check_request_history();
alter table public.audit_logs drop constraint audit_logs_action_check;
alter table public.audit_logs add constraint audit_logs_action_check check(action in (
 'price_changed','stock_movement','stock_count_approved','order_status_changed','alternative_accepted','alternative_rejected',
 'payment_recorded','payment_corrected','payment_cancelled','credit_approved','credit_rejected','delivery_disputed',
 'delivery_resolved','role_changed','permission_changed','order_request_decided'));
create table private.order_review_receipts (
 operation_key uuid primary key, actor_id uuid not null references public.profiles(id),
 payload jsonb not null, response jsonb not null
);
alter table private.order_review_receipts enable row level security;
revoke all on private.order_review_receipts from public,anon,authenticated;

create function private.lock_review_order(target_order uuid,request_key uuid) returns public.orders
language plpgsql security definer set search_path='' as $$
declare customer uuid; o public.orders;
begin
 if request_key is null then raise exception using errcode='22023',message='Request key required'; end if;
 perform 1 from auth.users where id=auth.uid() for share;
 perform 1 from public.profiles where id=auth.uid() for share;
 if private.current_app_role() is null then raise exception using errcode='42501',message='Active account required'; end if;
 perform pg_advisory_xact_lock(hashtextextended(request_key::text,73008));
 select customer_id into customer from public.orders where id=target_order;
 perform 1 from public.customers where id=customer for update;
 select * into o from public.orders where id=target_order for update;
 if not found or o.customer_id is distinct from customer then
  raise exception using errcode='42501',message='Order unavailable';
 end if;
 return o;
end;
$$;
revoke all on function private.lock_review_order(uuid,uuid) from public,anon,authenticated;

create function public.propose_order_alternative(target_item uuid,target_unit uuid,quantity integer,request_key uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare o public.orders; oid uuid; offered_product uuid; result jsonb; payload jsonb;
 prior private.order_review_receipts; offer_id uuid;
begin
 select order_id into oid from public.order_items where id=target_item;
 o:=private.lock_review_order(oid,request_key);
 if not private.sales_customer(o.customer_id) then
  raise exception using errcode='42501',message='Assigned active Sales required'; end if;
 if o.status<>'submitted' then raise exception using errcode='23514',message='Submitted order required'; end if;
 payload:=jsonb_build_object('action','propose','item',target_item,'unit',target_unit,'quantity',quantity);
 select * into prior from private.order_review_receipts where operation_key=request_key;
 if found then
  if prior.actor_id<>auth.uid() or prior.payload<>payload then raise exception using errcode='22023',message='Key payload mismatch'; end if;
  return prior.response;
 end if;
 -- Existing exact minimum/unit validation; quote is not a price commitment.
 perform public.quote_product(o.customer_id,target_unit,quantity);
 select product_id into offered_product from public.product_units where id=target_unit;
 insert into public.alternative_offers(order_item_id,offered_product_id,offered_unit_id,offered_qty,status,created_by)
 values(target_item,offered_product,target_unit,quantity,'pending',auth.uid()) returning id into offer_id;
 result:=jsonb_build_object('offer_id',offer_id,'status','pending');
 insert into private.order_review_receipts values(request_key,auth.uid(),payload,result);
 return result;
end;
$$;

create function public.respond_order_alternative(target_offer uuid,accept_offer boolean,request_key uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare o public.orders; oid uuid; offer public.alternative_offers; payload jsonb; result jsonb;
 prior private.order_review_receipts; request_id uuid; new_status text;
begin
 if accept_offer is null then raise exception using errcode='22023',message='Response required'; end if;
 select i.order_id into oid from public.alternative_offers a join public.order_items i on i.id=a.order_item_id where a.id=target_offer;
 o:=private.lock_review_order(oid,request_key);
 if not private.owns_customer(o.customer_id) or not private.can_shop(o.customer_id) then
  raise exception using errcode='42501',message='Active customer owner required'; end if;
 if o.status<>'submitted' then raise exception using errcode='23514',message='Submitted order required'; end if;
 payload:=jsonb_build_object('action','respond','offer',target_offer,'accept',accept_offer);
 select * into prior from private.order_review_receipts where operation_key=request_key;
 if found then
  if prior.actor_id<>auth.uid() or prior.payload<>payload then raise exception using errcode='22023',message='Key payload mismatch'; end if;
  return prior.response;
 end if;
 select * into offer from public.alternative_offers where id=target_offer for update;
 if offer.status<>'pending' then raise exception using errcode='23514',message='Offer already decided'; end if;
 new_status:=case when accept_offer then 'accepted' else 'rejected' end;
 update public.alternative_offers set status=new_status,responded_by=auth.uid(),responded_at=now(),operation_key=request_key where id=target_offer;
 if accept_offer then
  insert into public.order_change_requests(order_id,type,requested_by,reason,status,proposed_changes)
  values(o.id,'change',auth.uid(),'Müşteri alternatif teklifini kabul etti; yalnız değişiklik niyeti.','pending',
    jsonb_build_object('alternative_offer_id',target_offer,'intent_only',true)) returning id into request_id;
 end if;
 insert into public.audit_logs(actor_id,action,entity_type,entity_id,old_data,new_data,operation_key)
 values(auth.uid(),case when accept_offer then 'alternative_accepted' else 'alternative_rejected' end,
 'alternative_offer',target_offer,jsonb_build_object('status','pending'),
 jsonb_build_object('status',new_status,'intent_only',true,'request_id',request_id),request_key);
 result:=jsonb_build_object('offer_id',target_offer,'status',new_status,'request_id',request_id,'intent_only',true);
 insert into private.order_review_receipts values(request_key,auth.uid(),payload,result);
 return result;
end;
$$;
revoke all on function public.propose_order_alternative(uuid,uuid,integer,uuid),public.respond_order_alternative(uuid,boolean,uuid) from public,anon,authenticated;
grant execute on function public.propose_order_alternative(uuid,uuid,integer,uuid),public.respond_order_alternative(uuid,boolean,uuid) to authenticated;
create function public.order_alternatives(target_order uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare o public.orders;
begin
 select * into o from public.orders where id=target_order;
 if not found or not private.can_shop(o.customer_id) then raise exception using errcode='42501',message='Order access denied'; end if;
 return jsonb_build_object('status',o.status,'items',coalesce((select jsonb_agg(jsonb_build_object(
  'id',i.id,'name',p.name,'quantity',i.quantity,'unit',i.unit) order by i.id)
  from public.order_items i join public.products p on p.id=i.product_id where i.order_id=o.id),'[]'::jsonb),
  'offers',coalesce((select jsonb_agg(jsonb_build_object('id',a.id,'item_id',a.order_item_id,
   'name',p.name,'unit',u.unit_name,'quantity',a.offered_qty,'status',a.status) order by a.created_at,a.id)
   from public.alternative_offers a join public.order_items i on i.id=a.order_item_id
   join public.products p on p.id=a.offered_product_id join public.product_units u on u.id=a.offered_unit_id
   where i.order_id=o.id),'[]'::jsonb));
end;
$$;
revoke all on function public.order_alternatives(uuid) from public,anon,authenticated;
grant execute on function public.order_alternatives(uuid) to authenticated;

create function public.decide_order_request(target_request uuid,approve_request boolean,decision_note text,request_key uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare o public.orders; oid uuid; r public.order_change_requests; payload jsonb; result jsonb;
 prior private.order_review_receipts; verdict text;
begin
 if approve_request is null or nullif(btrim(decision_note),'') is null then
  raise exception using errcode='22023',message='Decision and note required'; end if;
 select order_id into oid from public.order_change_requests where id=target_request;
 o:=private.lock_review_order(oid,request_key);
 if private.current_app_role() not in ('manager','owner') then
  raise exception using errcode='42501',message='Manager or Owner required'; end if;
 if o.status<>'submitted' then raise exception using errcode='23514',message='Submitted order required'; end if;
 payload:=jsonb_build_object('action','decide','request',target_request,'approve',approve_request,'note',btrim(decision_note));
 select * into prior from private.order_review_receipts where operation_key=request_key;
 if found then
  if prior.actor_id<>auth.uid() or prior.payload<>payload then raise exception using errcode='22023',message='Key payload mismatch'; end if;
  return prior.response;
 end if;
 select * into r from public.order_change_requests where id=target_request for update;
 if r.status<>'pending' then raise exception using errcode='23514',message='Request already decided'; end if;
 verdict:=case when approve_request then 'approved' else 'rejected' end;
 update public.order_change_requests set status=verdict,decided_by=auth.uid(),decided_at=now(),
  decision_note=btrim(decide_order_request.decision_note) where id=r.id;
 -- A decision event, NOT a fictitious order status transition or revision.
 insert into public.order_status_history(order_id,from_status,to_status,changed_by,reason,operation_key,event_type,request_id,request_decision)
 values(o.id,o.status,o.status,auth.uid(),btrim(decision_note),request_key,'request_decided',r.id,verdict);
 insert into public.audit_logs(actor_id,action,entity_type,entity_id,old_data,new_data,operation_key)
 values(auth.uid(),'order_request_decided','order_change_request',r.id,jsonb_build_object('status','pending'),
  jsonb_build_object('status',verdict,'decision_note',btrim(decision_note),'order_id',o.id,'order_applied',false),request_key);
 result:=jsonb_build_object('request_id',r.id,'status',verdict,'order_applied',false);
 insert into private.order_review_receipts values(request_key,auth.uid(),payload,result);
 return result;
end;
$$;

create function public.order_review_requests() returns setof jsonb
language plpgsql stable security definer set search_path='' as $$
begin
 if not coalesce(private.current_app_role() in ('manager','owner'),false) then
  raise exception using errcode='42501',message='Manager or Owner required'; end if;
 return query select jsonb_build_object('id',r.id,'order_id',o.id,'order_status',o.status,'customer',c.company_name,
  'type',r.type,'reason',r.reason,'status',r.status,'decision_note',r.decision_note,'decided_by',r.decided_by,'decided_at',r.decided_at,
  'alternative',case when a.id is null then null else jsonb_build_object('name',p.name,'unit',u.unit_name,'quantity',a.offered_qty,'status',a.status) end)
 from public.order_change_requests r join public.orders o on o.id=r.order_id join public.customers c on c.id=o.customer_id
 left join public.alternative_offers a on a.id::text=r.proposed_changes->>'alternative_offer_id'
 left join public.products p on p.id=a.offered_product_id left join public.product_units u on u.id=a.offered_unit_id
 order by r.created_at desc,r.id;
end;
$$;
revoke all on function public.decide_order_request(uuid,boolean,text,uuid),public.order_review_requests() from public,anon,authenticated;
grant execute on function public.decide_order_request(uuid,boolean,text,uuid),public.order_review_requests() to authenticated;

-- Keep the previous projection, adding explicit decision evidence/event type.
create or replace function public.order_workflow_state(target_order uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare o public.orders;
begin
 select * into o from public.orders where id=target_order;
 if not found or not private.can_shop(o.customer_id) then
  raise exception using errcode='42501',message='Order workflow access denied'; end if;
 return jsonb_build_object('status',o.status,
  'history',coalesce((select jsonb_agg(jsonb_build_object('from_status',h.from_status,'to_status',h.to_status,
   'reason',h.reason,'created_at',h.created_at,'event_type',h.event_type,'request_id',h.request_id,'request_decision',h.request_decision)
   order by h.created_at,h.id) from public.order_status_history h where h.order_id=o.id),'[]'::jsonb),
  'requests',coalesce((select jsonb_agg(jsonb_build_object('id',r.id,'type',r.type,'reason',r.reason,'status',r.status,
   'created_at',r.created_at,'decided_at',r.decided_at,'decided_by',r.decided_by,'decision_note',r.decision_note)
   order by r.created_at,r.id) from public.order_change_requests r where r.order_id=o.id),'[]'::jsonb));
end;
$$;
commit;
