-- Phase 9 / F9-01. No revisions, compensation, credit or run assignment.
begin;
alter table public.inventory add column revision bigint not null default 0;
alter table public.stock_count_items add column inventory_revision bigint;
create function private.bump_inventory_revision() returns trigger
language plpgsql set search_path='' as $$
begin
 if row(new.physical_qty,new.reserved_qty) is distinct from row(old.physical_qty,old.reserved_qty) then
  new.revision:=old.revision+1;
 else new.revision:=old.revision; end if;
 return new;
end; $$;
revoke all on function private.bump_inventory_revision() from public,anon,authenticated;
create trigger inventory_revision before update on public.inventory
 for each row execute function private.bump_inventory_revision();

create table private.warehouse_receipts (
 operation_key uuid primary key, actor_id uuid not null references public.profiles(id),
 payload jsonb not null, response jsonb not null
);
alter table private.warehouse_receipts enable row level security;
revoke all on private.warehouse_receipts from public,anon,authenticated;

create function private.warehouse_actor(request_key uuid, payload jsonb, allowed public.app_role[])
returns jsonb language plpgsql security definer set search_path='' as $$
declare previous private.warehouse_receipts;
begin
 perform 1 from auth.users where id=auth.uid() for share;
 perform 1 from public.profiles where id=auth.uid() for share;
 if request_key is null then raise exception using errcode='22023',message='Key required'; end if;
 if coalesce(private.current_app_role()=any(allowed),false)=false then
  raise exception using errcode='42501',message='Warehouse action denied'; end if;
 perform pg_advisory_xact_lock(hashtextextended(request_key::text,73009));
 select * into previous from private.warehouse_receipts where operation_key=request_key;
 if found then
  if previous.actor_id<>auth.uid() or previous.payload<>payload then
   raise exception using errcode='22023',message='Key already used with different payload'; end if;
  return previous.response;
 end if;
 return null;
end; $$;
revoke all on function private.warehouse_actor(uuid,jsonb,public.app_role[]) from public,anon,authenticated;

create function private.warehouse_status(target_order uuid, old_status public.order_state,
 new_status public.order_state, request_key uuid) returns void
language plpgsql set search_path='' as $$
begin
 update public.orders set status=new_status where id=target_order;
 insert into public.order_status_history(order_id,from_status,to_status,changed_by,reason,operation_key)
 values(target_order,old_status,new_status,auth.uid(),'Depo işlemi',request_key);
 insert into public.audit_logs(actor_id,action,entity_type,entity_id,old_data,new_data,operation_key)
 values(auth.uid(),'order_status_changed','order',target_order,jsonb_build_object('status',old_status),
  jsonb_build_object('status',new_status),request_key);
end; $$;
revoke all on function private.warehouse_status(uuid,public.order_state,public.order_state,uuid) from public,anon,authenticated;

create function public.warehouse_order_action(target_order uuid, action text,
 target_item uuid, pick_quantity integer, request_key uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare payload jsonb:=jsonb_build_object('action',action,'order',target_order,'item',target_item,'quantity',pick_quantity);
 result jsonb; customer uuid; o public.orders; i public.order_items; stock public.inventory;
 remaining numeric; amount numeric; movement uuid; movement_key uuid; run_id uuid; stop_id uuid;
begin
 result:=private.warehouse_actor(request_key,payload,array['warehouse','manager','owner']::public.app_role[]);
 if result is not null then return result; end if;
 if action is null or action not in ('start','pick','load') or target_order is null or
  (action='pick' and (target_item is null or pick_quantity is null or pick_quantity<=0)) or
  (action<>'pick' and (target_item is not null or pick_quantity is not null)) then
  raise exception using errcode='22023',message='Invalid warehouse action'; end if;
 select customer_id into customer from public.orders where id=target_order;
 perform 1 from public.customers where id=customer for update;
 select * into o from public.orders where id=target_order for update;
 if not found then raise exception using errcode='23514',message='Order unavailable'; end if;
 if o.customer_id is distinct from customer then raise exception using errcode='40001',message='Reload order'; end if;
 perform 1 from public.order_items where order_id=o.id order by id for update;
 if not exists(select 1 from public.order_items where order_id=o.id) then
  raise exception using errcode='23514',message='Empty order'; end if;
 -- All stock locks follow checkout/cancellation's product order. Historical
 -- conversion snapshots and movement balances, never today's product units.
 perform 1 from public.inventory where product_id in
  (select product_id from public.order_items where order_id=o.id) order by product_id for update;
 for i in select * from public.order_items where order_id=o.id order by product_id,id loop
  select coalesce(sum(reserved_delta),0) into remaining from public.inventory_movements where order_item_id=i.id;
  select * into stock from public.inventory where product_id=i.product_id;
  if not found or remaining<>(i.quantity-i.picked_qty)*i.conversion_to_base_snapshot or stock.reserved_qty<remaining then
   raise exception using errcode='23514',message='Reservation history requires review'; end if;
 end loop;
 if action='start' then
  if o.status<>'submitted' or exists(select 1 from public.order_items where order_id=o.id and picked_qty<>0) then
   raise exception using errcode='23514',message='Only unpicked submitted order can start'; end if;
  perform private.warehouse_status(o.id,o.status,'picking',request_key);
 elsif action='pick' then
  if o.status<>'picking' then raise exception using errcode='23514',message='Order is not picking'; end if;
  select * into i from public.order_items where id=target_item and order_id=o.id;
  if not found or pick_quantity>i.quantity-i.picked_qty then
   raise exception using errcode='23514',message='Pick exceeds remaining item quantity'; end if;
  amount:=pick_quantity*i.conversion_to_base_snapshot;
  select * into stock from public.inventory where product_id=i.product_id;
  if stock.physical_qty<amount or stock.reserved_qty<amount then
   raise exception using errcode='23514',message='Stock insufficient'; end if;
  update public.inventory set physical_qty=physical_qty-amount,reserved_qty=reserved_qty-amount
   where warehouse_id=stock.warehouse_id and product_id=i.product_id;
  update public.order_items set picked_qty=picked_qty+pick_quantity where id=i.id;
  movement_key:=gen_random_uuid();
  insert into public.inventory_movements(warehouse_id,product_id,type,quantity,physical_delta,reserved_delta,
   order_item_id,unit,conversion_to_base_snapshot,created_by,operation_key)
  values(stock.warehouse_id,i.product_id,'picked',amount,-amount,-amount,i.id,i.unit,
   i.conversion_to_base_snapshot,auth.uid(),movement_key) returning id into movement;
  insert into public.audit_logs(actor_id,action,entity_type,entity_id,new_data,operation_key)
  values(auth.uid(),'stock_movement','inventory_movement',movement,
   jsonb_build_object('type','picked','base_quantity',amount::text,'order_id',o.id),movement_key);
  if not exists(select 1 from public.order_items where order_id=o.id and picked_qty<quantity) then
   perform private.warehouse_status(o.id,o.status,'picked',request_key);
  end if;
 else
  if o.status<>'picked' or exists(select 1 from public.order_items where order_id=o.id and picked_qty<>quantity) then
   raise exception using errcode='23514',message='Only fully picked orders may load'; end if;
  select s.run_id,s.id into run_id,stop_id from public.delivery_stops s where s.order_id=o.id and s.closed_at is null;
  perform 1 from public.delivery_runs r join public.vehicles v on v.id=r.vehicle_id
   where r.id=run_id and r.ended_at is null and v.active for share of r,v;
  if not found then raise exception using errcode='23514',message='Active run assignment required'; end if;
  perform 1 from public.delivery_stops s where s.id=stop_id and s.closed_at is null and s.completed_at is null for update;
  if not found then raise exception using errcode='23514',message='Active stop required'; end if;
  -- Physical deduction already happened at pick. Loading never deducts twice.
  perform private.warehouse_status(o.id,o.status,'loaded',request_key);
 end if;
 select jsonb_build_object('order_id',id,'status',status) into result from public.orders where id=o.id;
 insert into private.warehouse_receipts values(request_key,auth.uid(),payload,result);
 return result;
end; $$;

create function public.receive_inventory(target_unit uuid, quantity numeric, document_note text, request_key uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare payload jsonb:=jsonb_build_object('action','receive','unit',target_unit,'quantity',quantity::text,'note',document_note);
 result jsonb; u public.product_units; product uuid; wh uuid; amount numeric; movement uuid;
begin
 result:=private.warehouse_actor(request_key,payload,array['warehouse','manager','owner']::public.app_role[]);
 if result is not null then return result; end if;
 if quantity is null or quantity<=0 or quantity>='Infinity'::numeric then
  raise exception using errcode='22023',message='Positive finite quantity required'; end if;
 select product_id into product from public.product_units where id=target_unit;
 perform 1 from public.products where id=product for share;
 select * into u from public.product_units where id=target_unit for share;
 if not found or u.product_id is distinct from product then raise exception using errcode='23514',message='Unit unavailable'; end if;
 select id into wh from public.warehouses;
 if wh is null then raise exception using errcode='23514',message='Warehouse unavailable'; end if;
 amount:=quantity*u.conversion_to_base;
 insert into public.inventory(warehouse_id,product_id,physical_qty,reserved_qty) values(wh,product,0,0)
  on conflict do nothing;
 perform 1 from public.inventory where warehouse_id=wh and product_id=product for update;
 update public.inventory set physical_qty=physical_qty+amount where warehouse_id=wh and product_id=product;
 insert into public.inventory_movements(warehouse_id,product_id,type,quantity,physical_delta,reserved_delta,
  unit,conversion_to_base_snapshot,document_note,created_by,operation_key)
 values(wh,product,'received',amount,amount,0,u.unit_name,u.conversion_to_base,document_note,auth.uid(),request_key)
 returning id into movement;
 insert into public.audit_logs(actor_id,action,entity_type,entity_id,new_data,operation_key)
 values(auth.uid(),'stock_movement','inventory_movement',movement,
  jsonb_build_object('type','received','input_quantity',quantity::text,'base_quantity',amount::text,'unit_id',u.id),request_key);
 result:=jsonb_build_object('movement_id',movement,'base_quantity',amount::text);
 insert into private.warehouse_receipts values(request_key,auth.uid(),payload,result);
 return result;
end; $$;

-- Counts are captured and submitted together. No silently editable pending
-- snapshot: a stale count requires a new count, preserving the old evidence.
create function public.submit_stock_count(items jsonb, count_note text, request_key uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare payload jsonb:=jsonb_build_object('action','count','items',items,'note',count_note);
 result jsonb; row_data record; wh uuid; count_id uuid; stock public.inventory; counted numeric;
begin
 result:=private.warehouse_actor(request_key,payload,array['warehouse']::public.app_role[]);
 if result is not null then return result; end if;
 if items is null or jsonb_typeof(items)<>'array' or jsonb_array_length(items)=0 then
  raise exception using errcode='22023',message='Count items required'; end if;
 if exists(select 1 from jsonb_array_elements(items) x where jsonb_typeof(x)<>'object'
  or not(x ? 'product_id' and x ? 'counted_qty')) or
  (select count(distinct (x->>'product_id')::uuid) from jsonb_array_elements(items) x)<>jsonb_array_length(items) then
  raise exception using errcode='22023',message='Unique count products required'; end if;
 select id into wh from public.warehouses;
 if wh is null then raise exception using errcode='23514',message='Warehouse unavailable'; end if;
 perform 1 from public.products where id in(select (x->>'product_id')::uuid from jsonb_array_elements(items) x) order by id for share;
 for row_data in select x from jsonb_array_elements(items) x order by (x->>'product_id')::uuid loop
  counted:=(row_data.x->>'counted_qty')::numeric;
  if counted is null or counted<0 or counted>='Infinity'::numeric then
   raise exception using errcode='22023',message='Finite nonnegative count required'; end if;
  insert into public.inventory(warehouse_id,product_id,physical_qty,reserved_qty)
   values(wh,(row_data.x->>'product_id')::uuid,0,0) on conflict do nothing;
  perform 1 from public.inventory where warehouse_id=wh and product_id=(row_data.x->>'product_id')::uuid for update;
 end loop;
 insert into public.stock_counts(warehouse_id,created_by,status,reason) values(wh,auth.uid(),'pending',count_note) returning id into count_id;
 for row_data in select x from jsonb_array_elements(items) x loop
  select * into stock from public.inventory where warehouse_id=wh and product_id=(row_data.x->>'product_id')::uuid;
  insert into public.stock_count_items(stock_count_id,product_id,system_qty,counted_qty,reason,inventory_revision)
  values(count_id,stock.product_id,stock.physical_qty,(row_data.x->>'counted_qty')::numeric,count_note,stock.revision);
 end loop;
 result:=jsonb_build_object('count_id',count_id,'status','pending');
 insert into private.warehouse_receipts values(request_key,auth.uid(),payload,result);
 return result;
end; $$;

create function public.approve_stock_count(target_count uuid, request_key uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare payload jsonb:=jsonb_build_object('action','approve_count','count',target_count);
 result jsonb; c public.stock_counts; i public.stock_count_items; stock public.inventory;
 delta numeric; movement uuid; movement_key uuid;
begin
 result:=private.warehouse_actor(request_key,payload,array['manager','owner']::public.app_role[]);
 if result is not null then return result; end if;
 select * into c from public.stock_counts where id=target_count for update;
 if not found or c.status<>'pending' then raise exception using errcode='23514',message='Pending count required'; end if;
 if not exists(select 1 from public.stock_count_items where stock_count_id=c.id) then
  raise exception using errcode='23514',message='Empty count'; end if;
 perform 1 from public.inventory where warehouse_id=c.warehouse_id and product_id in
  (select product_id from public.stock_count_items where stock_count_id=c.id) order by product_id for update;
 for i in select * from public.stock_count_items where stock_count_id=c.id order by product_id loop
  select * into stock from public.inventory where warehouse_id=c.warehouse_id and product_id=i.product_id;
  if not found or i.inventory_revision is null or stock.revision<>i.inventory_revision or stock.physical_qty<>i.system_qty then
   raise exception using errcode='40001',message='Stock changed; recount required'; end if;
  if i.counted_qty<stock.reserved_qty then raise exception using errcode='23514',message='Count is below reservations'; end if;
  delta:=i.counted_qty-stock.physical_qty;
  if delta<>0 then
   update public.inventory set physical_qty=i.counted_qty where warehouse_id=c.warehouse_id and product_id=i.product_id;
   movement_key:=gen_random_uuid();
   insert into public.inventory_movements(warehouse_id,product_id,type,quantity,physical_delta,reserved_delta,
    stock_count_id,created_by,operation_key)
   values(c.warehouse_id,i.product_id,'count_adjustment',abs(delta),delta,0,c.id,auth.uid(),movement_key) returning id into movement;
   insert into public.audit_logs(actor_id,action,entity_type,entity_id,old_data,new_data,operation_key)
   values(auth.uid(),'stock_movement','inventory_movement',movement,jsonb_build_object('physical_qty',stock.physical_qty::text),
    jsonb_build_object('physical_qty',i.counted_qty::text,'created_by',c.created_by,'approved_by',auth.uid()),movement_key);
  end if;
 end loop;
 update public.stock_counts set status='approved',approved_by=auth.uid(),approved_at=now(),operation_key=request_key where id=c.id;
 insert into public.audit_logs(actor_id,action,entity_type,entity_id,new_data,operation_key)
 values(auth.uid(),'stock_count_approved','stock_count',c.id,jsonb_build_object('created_by',c.created_by,'approved_by',auth.uid()),request_key);
 result:=jsonb_build_object('count_id',c.id,'status','approved');
 insert into private.warehouse_receipts values(request_key,auth.uid(),payload,result);
 return result;
end; $$;

-- Explicit fields only: no price, customer identity, financial or free notes.
create function public.warehouse_workspace(section text) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare result jsonb;
begin
 if coalesce(private.current_app_role() in ('warehouse','manager','owner'),false)=false then
  raise exception using errcode='42501',message='Warehouse read denied'; end if;
 if section='stock' then
  select coalesce(jsonb_agg(jsonb_build_object('id',p.id,'name',p.name,'unit',p.base_unit,
   'physical',coalesce(i.physical_qty,0)::text,'reserved',coalesce(i.reserved_qty,0)::text,
   'available',coalesce(i.available_qty,0)::text,'units',coalesce((select jsonb_agg(jsonb_build_object(
    'id',u.id,'name',u.unit_name,'conversion',u.conversion_to_base::text) order by u.unit_name,u.id)
    from public.product_units u where u.product_id=p.id),'[]'::jsonb)) order by p.name,p.id),'[]'::jsonb)
   into result from public.products p left join public.inventory i on i.product_id=p.id;
 elsif section='preparation' then
  select coalesce(jsonb_agg(jsonb_build_object('order_id',o.id,'status',o.status,'items',
   (select jsonb_agg(jsonb_build_object('id',i.id,'name',p.name,'unit',i.unit,'quantity',i.quantity,
    'picked',i.picked_qty,'conversion',i.conversion_to_base_snapshot::text) order by i.id)
    from public.order_items i join public.products p on p.id=i.product_id where i.order_id=o.id)) order by o.created_at,o.id),'[]'::jsonb)
   into result from public.orders o where o.status in ('submitted','picking','picked');
 elsif section='counts' then
  select coalesce(jsonb_agg(jsonb_build_object('id',c.id,'status',c.status,'created_at',c.created_at,'items',
   (select jsonb_agg(jsonb_build_object('name',p.name,'unit',p.base_unit,'system',i.system_qty::text,
    'counted',i.counted_qty::text,'difference',i.difference::text) order by p.name,p.id)
    from public.stock_count_items i join public.products p on p.id=i.product_id where i.stock_count_id=c.id)) order by c.created_at desc,c.id),'[]'::jsonb)
   into result from public.stock_counts c;
 elsif section='movements' then
  select coalesce(jsonb_agg(jsonb_build_object('id',m.id,'name',p.name,'type',m.type,'quantity',m.quantity::text,
   'unit',p.base_unit,'physical_delta',m.physical_delta::text,'reserved_delta',m.reserved_delta::text,
   'created_at',m.created_at) order by m.created_at desc,m.id),'[]'::jsonb)
   into result from public.inventory_movements m join public.products p on p.id=m.product_id;
 else raise exception using errcode='22023',message='Unknown warehouse section'; end if;
 return result;
end; $$;
revoke all on function public.warehouse_order_action(uuid,text,uuid,integer,uuid),public.receive_inventory(uuid,numeric,text,uuid),
 public.submit_stock_count(jsonb,text,uuid),public.approve_stock_count(uuid,uuid),public.warehouse_workspace(text) from public,anon,authenticated;
grant execute on function public.warehouse_order_action(uuid,text,uuid,integer,uuid),public.receive_inventory(uuid,numeric,text,uuid),
 public.submit_stock_count(jsonb,text,uuid),public.approve_stock_count(uuid,uuid),public.warehouse_workspace(text) to authenticated;
commit;
