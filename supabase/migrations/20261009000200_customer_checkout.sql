-- Phase 6: scoped catalog and shared Customer/Sales cart pricing.
begin;

create function private.can_shop(target_customer uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select coalesce((private.owns_customer(target_customer) or private.sales_customer(target_customer))
   and exists(select 1 from public.customers where id=target_customer and active),false);
$$;
revoke all on function private.can_shop(uuid) from public,anon,authenticated;

create function public.customer_catalog(target_customer uuid) returns setof jsonb
language plpgsql stable security definer set search_path='' as $$
declare discount numeric;
begin
 if not private.can_shop(target_customer) then
   raise exception using errcode='42501',message='Customer catalog access denied';
 end if;
 select cp.discount_rate into discount from public.customer_pricing cp where cp.customer_id=target_customer
   and cp.effective_from <= (statement_timestamp() at time zone 'Europe/Istanbul')::date;
 discount := coalesce(discount,0);
 return query select jsonb_build_object('id',p.id,'sku',p.sku,'name',p.name,'description',p.description,
   'category_id',c.id,'category',c.name,'package_label',p.package_label,'base_unit',p.base_unit,
   'minimum',p.min_quantity::text,'list_price_kurus',p.unit_price_kurus::text,
   'discount_rate',discount::text,'exact_final_base_price',(p.unit_price_kurus*(1-discount))::text,
   'stock_state',case when i.product_id is null then 'unknown' when i.available_qty<=0 then 'empty' else 'available' end,
   'units',coalesce((select jsonb_agg(jsonb_build_object('id',u.id,'name',u.unit_name,
     'conversion',u.conversion_to_base::text) order by u.unit_name) from public.product_units u
     where u.product_id=p.id and u.orderable),'[]'::jsonb))
 from public.products p join public.categories c on c.id=p.category_id
 left join public.inventory i on i.product_id=p.id
 where p.active and c.active and p.unit_price_kurus is not null order by c.name,p.name,p.id;
end;
$$;

create function private.normalized_cart(items jsonb) returns jsonb
language plpgsql immutable set search_path='' as $$
declare item jsonb; normalized jsonb := '[]';
begin
 if items is null or jsonb_typeof(items)<>'array' then
   raise exception using errcode='22023',message='Cart array required';
 end if;
 if jsonb_array_length(items)=0 then raise exception using errcode='22023',message='Cart is empty'; end if;
 for item in select value from jsonb_array_elements(items) loop
   if jsonb_typeof(item)<>'object' or (item-array['unit_id','quantity'])<>'{}'::jsonb
     or nullif(item->>'unit_id','') is null or jsonb_typeof(item->'quantity') is distinct from 'number'
     or (item->>'quantity') !~ '^[1-9][0-9]*$' then
     raise exception using errcode='22023',message='Only unit and positive integer quantity accepted';
   end if;
   normalized := normalized || jsonb_build_array(jsonb_build_object('unit_id',(item->>'unit_id')::uuid,'quantity',(item->>'quantity')::integer));
 end loop;
 if (select count(*) <> count(distinct value->>'unit_id') from jsonb_array_elements(normalized)) then
   raise exception using errcode='22023',message='Duplicate sales unit';
 end if;
 return (select jsonb_agg(value order by value->>'unit_id') from jsonb_array_elements(normalized));
end;
$$;
revoke all on function private.normalized_cart(jsonb) from public,anon,authenticated;

create function public.quote_cart(target_customer uuid, items jsonb) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare normalized jsonb; item jsonb; q jsonb; lines jsonb := '[]'; result jsonb;
 subtotal numeric:=0; total numeric:=0; shortages boolean;
begin
 if not private.can_shop(target_customer) then raise exception using errcode='42501',message='Cart access denied'; end if;
 normalized := private.normalized_cart(items);
 for item in select value from jsonb_array_elements(normalized) loop
   q := public.quote_product(target_customer,(item->>'unit_id')::uuid,(item->>'quantity')::integer);
   select q || jsonb_build_object('name',p.name,'sku',p.sku,'base_unit',p.base_unit)
     into q from public.products p where p.id=(q->>'product_id')::uuid;
   lines := lines || jsonb_build_array(q);
   subtotal := subtotal + (q->>'subtotal_kurus')::numeric;
   total := total + (q->>'line_total_kurus')::numeric;
 end loop;
 if greatest(subtotal,total)>9223372036854775807::numeric then
   raise exception using errcode='22003',message='Cart exceeds money storage range';
 end if;
 -- Aggregate multiple sale units of the same product before comparing stock.
 select coalesce(bool_or(i.product_id is null or i.available_qty<requested.qty),false) into shortages
 from (select (value->>'product_id')::uuid product_id,sum((value->>'base_quantity')::numeric) qty
   from jsonb_array_elements(lines) group by 1) requested
 left join public.inventory i on i.product_id=requested.product_id;
 result := jsonb_build_object('customer_id',target_customer,'lines',lines,'subtotal_kurus',subtotal::text,
   'discount_total_kurus',(subtotal-total)::text,'total_kurus',total::text,'stock_sufficient',not shortages);
 return result || jsonb_build_object('fingerprint',encode(sha256(convert_to(result::text,'UTF8')),'hex'));
end;
$$;

revoke all on function public.customer_catalog(uuid),public.quote_cart(uuid,jsonb) from public,anon,authenticated;
grant execute on function public.customer_catalog(uuid),public.quote_cart(uuid,jsonb) to authenticated;


-- Draft carts are editable intentions, not orders or immutable price facts.
create table private.cart_drafts (
 actor_id uuid not null references public.profiles(id),
 customer_id uuid not null references public.customers(id), items jsonb not null,
 updated_at timestamptz not null default now(), primary key(actor_id,customer_id)
);
create table private.checkout_receipts (
 operation_key uuid primary key, actor_id uuid not null references public.profiles(id),
 customer_id uuid not null references public.customers(id), request jsonb not null,
 order_id uuid not null references public.orders(id), response jsonb not null
);
alter table private.cart_drafts enable row level security;
alter table private.checkout_receipts enable row level security;
revoke all on private.cart_drafts,private.checkout_receipts from public,anon,authenticated;
alter table public.orders add column credit_check_state text
 check (credit_check_state is null or credit_check_state='not_evaluated');
comment on column public.orders.credit_check_state is 'Phase 6: no exposure formula or debt posting. NULL means legacy, not_evaluated means warning only; never an approved credit check.';

create function public.save_cart_draft(target_customer uuid,items jsonb) returns void
language plpgsql security definer set search_path='' as $$
begin
 perform 1 from auth.users where id=auth.uid() for share;
 perform 1 from public.profiles where id=auth.uid() for share;
 perform 1 from public.customers where id=target_customer for update;
 if not private.can_shop(target_customer) then raise exception using errcode='42501',message='Draft access denied'; end if;
 perform public.quote_cart(target_customer,items);
 insert into private.cart_drafts(actor_id,customer_id,items) values(auth.uid(),target_customer,private.normalized_cart(items))
 on conflict(actor_id,customer_id) do update set items=excluded.items,updated_at=now();
end;
$$;
create function public.load_cart_draft(target_customer uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare result jsonb;
begin
 if not private.can_shop(target_customer) then raise exception using errcode='42501',message='Draft access denied'; end if;
 select items into result from private.cart_drafts where actor_id=auth.uid() and customer_id=target_customer;
 return result;
end;
$$;

create function public.checkout_cart(target_customer uuid,items jsonb,accepted_quote jsonb,request_key uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare normalized jsonb; request jsonb; previous private.checkout_receipts; q jsonb; result jsonb;
 new_order uuid; new_item uuid; movement_id uuid; movement_key uuid; line jsonb; next_status public.order_state; stock public.inventory;
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
 next_status:=case when (q->>'stock_sufficient')::boolean then 'submitted'::public.order_state else 'pending_approval'::public.order_state end;
 insert into public.orders(customer_id,created_by,source,status,payment_status,subtotal_kurus,discount_total_kurus,total_kurus,
  credit_warning,credit_check_state,operation_key)
 values(target_customer,auth.uid(),case when private.current_app_role()='customer' then 'customer_app' else 'sales_operator' end,
  next_status,'not_due',(q->>'subtotal_kurus')::bigint,(q->>'discount_total_kurus')::bigint,(q->>'total_kurus')::bigint,true,'not_evaluated',request_key)
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
  insert into public.order_approvals(order_id,reason,requested_by,status)
   values(new_order,'Stok yetersiz; yönetici kararı gerekli.',auth.uid(),'pending');
 end if;
 insert into public.order_status_history(order_id,to_status,changed_by,reason,operation_key)
 values(new_order,next_status,auth.uid(),'Müşteri fiyat onayı; cari kontrol hesaplanmadı.',request_key);
 insert into public.audit_logs(actor_id,action,entity_type,entity_id,new_data,operation_key)
 values(auth.uid(),'order_status_changed','order',new_order,jsonb_build_object('status',next_status,'credit_check_state','not_evaluated'),request_key);
 result:=jsonb_build_object('outcome','created','order_id',new_order,'status',next_status,'quote',q,'credit_check_state','not_evaluated');
 insert into private.checkout_receipts values(request_key,auth.uid(),target_customer,request,new_order,result);
 -- Do not erase a newer draft saved from another device.
 delete from private.cart_drafts d where d.actor_id=auth.uid() and d.customer_id=target_customer and d.items=normalized;
 return result;
end;
$$;
revoke all on function public.save_cart_draft(uuid,jsonb),public.load_cart_draft(uuid),public.checkout_cart(uuid,jsonb,jsonb,uuid) from public,anon,authenticated;
grant execute on function public.save_cart_draft(uuid,jsonb),public.load_cart_draft(uuid),public.checkout_cart(uuid,jsonb,jsonb,uuid) to authenticated;
commit;
