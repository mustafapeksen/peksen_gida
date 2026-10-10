-- Phase 8 approved slice: submitted cancellation and request intake only.
-- No alternative application, post-picking compensation or approval transition.
begin;
create table private.order_workflow_receipts (
 operation_key uuid primary key,
 actor_id uuid not null references public.profiles(id),
 order_id uuid not null references public.orders(id),
 action text not null,
 reason text not null,
 response jsonb not null
);
alter table private.order_workflow_receipts enable row level security;
revoke all on private.order_workflow_receipts from public,anon,authenticated;

create function public.order_workflow_state(target_order uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare o public.orders;
begin
 select * into o from public.orders where id=target_order;
 if not found or not private.can_shop(o.customer_id) then
  raise exception using errcode='42501',message='Order workflow access denied';
 end if;
 return jsonb_build_object('status',o.status,
  'history',coalesce((select jsonb_agg(jsonb_build_object('from_status',h.from_status,
   'to_status',h.to_status,'reason',h.reason,'created_at',h.created_at) order by h.created_at,h.id)
   from public.order_status_history h where h.order_id=o.id),'[]'::jsonb),
  'requests',coalesce((select jsonb_agg(jsonb_build_object('id',r.id,'type',r.type,
   'reason',r.reason,'status',r.status,'created_at',r.created_at,'decided_at',r.decided_at)
   order by r.created_at,r.id) from public.order_change_requests r where r.order_id=o.id),'[]'::jsonb));
end;
$$;

create function public.request_order_action(target_order uuid, requested_action text,
 request_reason text, request_key uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare o public.orders; customer uuid; previous private.order_workflow_receipts;
 result jsonb; item public.order_items; stock public.inventory; reserved numeric;
 movement uuid; movement_key uuid; request_id uuid; request_type text;
begin
 if request_key is null or requested_action is null or
   requested_action not in ('cancel_submitted','request_cancel','request_change') or
   nullif(btrim(request_reason),'') is null then
  raise exception using errcode='22023',message='Action, reason and key required';
 end if;
 -- Compatible with checkout lock ordering; access is rechecked after locks.
 perform 1 from auth.users where id=auth.uid() for share;
 perform 1 from public.profiles where id=auth.uid() for share;
 perform pg_advisory_xact_lock(hashtextextended(request_key::text,73008));
 select customer_id into customer from public.orders where id=target_order;
 perform 1 from public.customers where id=customer for update;
 if customer is null or not private.can_shop(customer) then
  raise exception using errcode='42501',message='Order workflow access denied';
 end if;
 select * into o from public.orders where id=target_order for update;
 if o.customer_id is distinct from customer then
  raise exception using errcode='40001',message='Order changed; reload';
 end if;
 select * into previous from private.order_workflow_receipts where operation_key=request_key;
 if found then
  if row(previous.actor_id,previous.order_id,previous.action,previous.reason)
    is distinct from row(auth.uid(),target_order,requested_action,btrim(request_reason)) then
   raise exception using errcode='22023',message='Key already used with different payload';
  end if;
  return previous.response;
 end if;
 if requested_action='cancel_submitted' then
  if o.status<>'submitted' then
   raise exception using errcode='23514',message='Only submitted orders can be cancelled directly';
  end if;
  perform 1 from public.order_items where order_id=o.id order by id for update;
  if not exists(select 1 from public.order_items where order_id=o.id) or
    exists(select 1 from public.order_items where order_id=o.id and picked_qty<>0) or
    exists(select 1 from public.delivery_stops where order_id=o.id and closed_at is null) then
   raise exception using errcode='23514',message='Order requires operational review';
  end if;
  perform 1 from public.inventory where product_id in
   (select product_id from public.order_items where order_id=o.id) order by product_id for update;
  for item in select * from public.order_items where order_id=o.id order by product_id,id loop
   -- Release recorded reservation, never reconstruct from today's unit/price.
   select coalesce(sum(reserved_delta),0) into reserved
    from public.inventory_movements where order_item_id=item.id;
   if reserved<>item.quantity*item.conversion_to_base_snapshot or exists(
    select 1 from public.inventory_movements where order_item_id=item.id and physical_delta<>0) then
    raise exception using errcode='23514',message='Reservation history requires review';
   end if;
   select * into stock from public.inventory where product_id=item.product_id;
   if not found or stock.reserved_qty<reserved then
    raise exception using errcode='23514',message='Reservation balance requires review';
   end if;
   update public.inventory set reserved_qty=reserved_qty-reserved
    where product_id=item.product_id and warehouse_id=stock.warehouse_id;
   movement_key:=gen_random_uuid();
   insert into public.inventory_movements(warehouse_id,product_id,type,quantity,physical_delta,
    reserved_delta,order_item_id,reference_type,reference_id,unit,conversion_to_base_snapshot,
    reason,created_by,operation_key)
   values(stock.warehouse_id,item.product_id,'released',reserved,0,-reserved,item.id,'order',o.id,
    item.unit,item.conversion_to_base_snapshot,btrim(request_reason),auth.uid(),movement_key)
   returning id into movement;
   insert into public.audit_logs(actor_id,action,entity_type,entity_id,new_data,operation_key)
   values(auth.uid(),'stock_movement','inventory_movement',movement,
    jsonb_build_object('type','released','order_id',o.id,'base_quantity',reserved::text),movement_key);
  end loop;
  update public.orders set status='cancelled' where id=o.id;
  insert into public.order_status_history(order_id,from_status,to_status,changed_by,reason,operation_key)
   values(o.id,o.status,'cancelled',auth.uid(),btrim(request_reason),request_key);
  insert into public.audit_logs(actor_id,action,entity_type,entity_id,old_data,new_data,operation_key)
   values(auth.uid(),'order_status_changed','order',o.id,jsonb_build_object('status',o.status),
    jsonb_build_object('status','cancelled','reason',btrim(request_reason)),request_key);
  result:=jsonb_build_object('outcome','cancelled','order_id',o.id);
 else
  -- These requests record intent only. No automatic status/item/stock change.
  if o.status not in ('submitted','picking','picked','assigned','loaded','out_for_delivery') or
    (requested_action='request_cancel' and o.status='submitted') then
   raise exception using errcode='23514',message='Request not supported in this state';
  end if;
  request_type:=case when requested_action='request_cancel' then 'cancel' else 'change' end;
  -- A retry after losing local state does not create a second pending request.
  select id into request_id from public.order_change_requests where order_id=o.id
   and requested_by=auth.uid() and type=request_type and status='pending'
   and reason=btrim(request_reason) order by created_at,id limit 1;
  if request_id is null then
   insert into public.order_change_requests(order_id,type,requested_by,reason,status)
    values(o.id,request_type,auth.uid(),btrim(request_reason),'pending') returning id into request_id;
  end if;
  result:=jsonb_build_object('outcome','requested','order_id',o.id,'request_id',request_id);
 end if;
 insert into private.order_workflow_receipts values(request_key,auth.uid(),o.id,
   requested_action,btrim(request_reason),result);
 return result;
end;
$$;
revoke all on function public.order_workflow_state(uuid),public.request_order_action(uuid,text,text,uuid)
 from public,anon,authenticated;
grant execute on function public.order_workflow_state(uuid),public.request_order_action(uuid,text,text,uuid)
 to authenticated;
-- Manager/Owner retain existing RLS reads of requests. No decision RPC until
-- revision/compensation contracts are approved. Raw writes remain closed.
commit;
