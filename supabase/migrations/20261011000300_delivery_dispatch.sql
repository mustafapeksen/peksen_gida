-- F11-01: dispatch only; no delivery confirmation, GPS or stock compensation.
begin;
alter table public.delivery_runs add column dispatch_managed boolean not null default false;
comment on column public.delivery_runs.dispatch_managed is 'F11 lifecycle applies to new RPC-created runs. Legacy status text is never inferred.';
alter table public.delivery_runs drop constraint delivery_runs_check1;
alter table public.delivery_runs add constraint delivery_runs_time_check check (
 ended_at is null or (started_at is not null and ended_at>=started_at)
 or (dispatch_managed and status='cancelled' and started_at is null));
alter table public.delivery_runs add constraint delivery_runs_dispatch_state check (not dispatch_managed or (
 (status='planned' and started_at is null and ended_at is null) or
 (status='in_progress' and started_at is not null and ended_at is null) or
 (status='completed' and started_at is not null and ended_at is not null) or
 (status='cancelled' and started_at is null and ended_at is not null)));
alter table public.audit_logs drop constraint audit_logs_action_check;
alter table public.audit_logs add constraint audit_logs_action_check check(action in (
 'price_changed','stock_movement','stock_count_approved','order_status_changed','alternative_accepted','alternative_rejected',
 'payment_recorded','payment_corrected','payment_cancelled','credit_approved','credit_rejected','delivery_disputed',
 'delivery_resolved','role_changed','permission_changed','order_request_decided','payment_verified','credit_limit_changed',
 'dispatch_changed'));
create table private.dispatch_receipts (
 operation_key uuid primary key,actor_id uuid not null references public.profiles(id),payload jsonb not null,response jsonb not null);
alter table private.dispatch_receipts enable row level security;
revoke all on private.dispatch_receipts from public,anon,authenticated;

create function public.dispatch_action(action text, data jsonb, request_key uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor_role public.app_role; prior private.dispatch_receipts; payload jsonb;
 target uuid; v_run_id uuid; v_order_id uuid; vehicle uuid; primary_id uuid; assistant_id uuid;
 r public.delivery_runs; old_stop public.delivery_stops; o public.orders; previous jsonb; result jsonb;
 stop_id uuid; seq integer; offset_seq bigint; slots integer[]; ids uuid[]; i integer; note text;
begin
 if action is null or action not in ('vehicle','create_run','assign','reorder','depart','complete','cancel')
 or data is null or jsonb_typeof(data)<>'object' or request_key is null then
  raise exception using errcode='22023',message='Dispatch action, object and key required'; end if;
 v_run_id:=(data->>'run_id')::uuid; v_order_id:=(data->>'order_id')::uuid;
 primary_id:=(data->>'primary_id')::uuid; assistant_id:=(data->>'assistant_id')::uuid;
 -- Same order as account lifecycle. Lock actors AND both team members before resources.
 select array_agg(distinct id order by id) into ids from (
  select auth.uid() id union select primary_id union select assistant_id union
  select primary_driver_id from public.delivery_runs where id=v_run_id union
  select assistant_driver_id from public.delivery_runs where id=v_run_id) t where id is not null;
 perform 1 from auth.users where id=any(ids) order by id for share;
 perform 1 from public.profiles where id=any(ids) order by id for share;
 actor_role:=private.current_app_role();
 if not coalesce(actor_role in ('manager','owner','driver'),false) or
 (actor_role='driver' and action not in ('reorder','depart')) or
 (action in ('reorder','depart') and actor_role<>'driver') then
  raise exception using errcode='42501',message='Dispatch role denied'; end if;
 if actor_role='driver' and not private.assigned_run(v_run_id) then
  raise exception using errcode='42501',message='Assigned driver required'; end if;
 payload:=jsonb_build_object('action',action,'data',data);
 -- Serializes dispatch resource allocation and run membership, including cross-column driver conflicts.
 -- Existing warehouse/finance never acquire this lock; customer/order locks precede run locks below.
 perform pg_advisory_xact_lock(73011,1);
 select * into prior from private.dispatch_receipts where operation_key=request_key;
 if found then
  if prior.actor_id<>auth.uid() or prior.payload<>payload then
   raise exception using errcode='22023',message='Key already used'; end if;
  return prior.response;
 end if;
 if action='vehicle' then
  target:=(data->>'id')::uuid;
  if nullif(btrim(data->>'plate'),'') is null or jsonb_typeof(data->'active') is distinct from 'boolean' then
   raise exception using errcode='22023',message='Plate and active required'; end if;
  if target is not null then
   select to_jsonb(v) into previous from public.vehicles v where id=target for update;
   if not found then raise exception using errcode='23514',message='Vehicle missing'; end if;
   if not (data->>'active')::boolean and exists(select 1 from public.delivery_runs where vehicle_id=target and ended_at is null) then
    raise exception using errcode='23514',message='Vehicle has open run'; end if;
   update public.vehicles set plate=btrim(data->>'plate'),description=nullif(btrim(data->>'description'),''),active=(data->>'active')::boolean where id=target;
  else
   insert into public.vehicles(plate,description,active) values(btrim(data->>'plate'),nullif(btrim(data->>'description'),''),(data->>'active')::boolean) returning id into target;
  end if;
  result:=jsonb_build_object('id',target);
 elsif action='create_run' then
  vehicle:=(data->>'vehicle_id')::uuid;
  if primary_id is null or primary_id=assistant_id or
   not exists(select 1 from public.profiles where id=primary_id and role='driver' and active) or
   (assistant_id is not null and not exists(select 1 from public.profiles where id=assistant_id and role='driver' and active)) then
   raise exception using errcode='23514',message='Active distinct drivers required'; end if;
  perform 1 from public.vehicles where id=vehicle and active for update;
  if not found then raise exception using errcode='23514',message='Active vehicle required'; end if;
  if exists(select 1 from public.delivery_runs where ended_at is null and
   (vehicle_id=vehicle or primary_driver_id in (primary_id,assistant_id) or assistant_driver_id in (primary_id,assistant_id))) then
   raise exception using errcode='23514',message='Vehicle or driver already in open run'; end if;
  insert into public.delivery_runs(vehicle_id,primary_driver_id,assistant_driver_id,status,dispatch_managed)
   values(vehicle,primary_id,assistant_id,'planned',true) returning id into target;
  result:=jsonb_build_object('id',target,'status','planned');
 else
  -- Stable membership under the dispatch advisory lock; same sorted customer/order locks as checkout, loading and payments.
  perform 1 from public.customers where id in(select customer_id from public.orders where id=v_order_id or id in
   (select s.order_id from public.delivery_stops s where s.run_id=v_run_id)) order by id for update;
  perform 1 from public.orders where id=v_order_id or id in
   (select s.order_id from public.delivery_stops s where s.run_id=v_run_id) order by id for update;
  select * into r from public.delivery_runs where id=v_run_id for update;
  if not found or not r.dispatch_managed or r.ended_at is not null then
   raise exception using errcode='23514',message='Open managed run required'; end if;
  target:=r.id; previous:=to_jsonb(r);
  if action in ('assign','depart') then
   perform 1 from public.vehicles where id=r.vehicle_id and active for share;
   if not found then raise exception using errcode='23514',message='Active vehicle required'; end if;
   if exists(select 1 from public.profiles where id in (r.primary_driver_id,r.assistant_driver_id) and (not active or role<>'driver')) then
    raise exception using errcode='23514',message='Active driver team required'; end if;
  end if;
  perform 1 from public.delivery_stops s where s.run_id=r.id order by id for update;
  if action='assign' then
   if r.status<>'planned' then raise exception using errcode='23514',message='Planned run required'; end if;
   select * into o from public.orders where id=v_order_id;
   if not found or o.status<>'picked' or not exists(select 1 from public.order_items where order_id=o.id) or
    exists(select 1 from public.order_items where order_id=o.id and picked_qty<>quantity) then
    raise exception using errcode='23514',message='Fully picked order required'; end if;
   select * into old_stop from public.delivery_stops where order_id=o.id and closed_at is null for update;
   if found then
    note:=nullif(btrim(data->>'reason'),'');
    if old_stop.run_id=r.id or old_stop.completed_at is not null or note is null then
     raise exception using errcode='23514',message='New run and reassignment reason required'; end if;
    perform 1 from public.delivery_runs where id=old_stop.run_id and ended_at is null and started_at is null for update;
    if not found then raise exception using errcode='23514',message='Previous run already started'; end if;
    update public.delivery_stops set closed_at=now(),closed_by=auth.uid(),close_reason=note where id=old_stop.id;
   end if;
   select coalesce(max(sequence),0)+1 into seq from public.delivery_stops where delivery_stops.run_id=r.id and closed_at is null;
   insert into public.delivery_stops(run_id,order_id,sequence,status,assigned_by,previous_stop_id)
    values(r.id,o.id,seq,'assigned',auth.uid(),old_stop.id) returning id into stop_id;
   result:=jsonb_build_object('id',r.id,'stop_id',stop_id,'order_id',o.id,'previous_stop_id',old_stop.id,'status',o.status);
  elsif action='reorder' then
   if jsonb_typeof(data->'stop_ids') is distinct from 'array' then raise exception using errcode='22023',message='Stop permutation required'; end if;
   select array_agg(value::uuid order by ordinal) into ids from jsonb_array_elements_text(data->'stop_ids') with ordinality t(value,ordinal);
   select array_agg(sequence order by sequence) into slots from public.delivery_stops where delivery_stops.run_id=r.id and closed_at is null and completed_at is null;
   if coalesce(cardinality(ids),0)=0 or cardinality(ids)<>coalesce(cardinality(slots),0) or
    (select count(distinct x) from unnest(ids) x)<>cardinality(ids) or exists(select 1 from unnest(ids) x where not exists
     (select 1 from public.delivery_stops where id=x and delivery_stops.run_id=r.id and closed_at is null and completed_at is null)) then
    raise exception using errcode='23514',message='Exact open uncompleted stop permutation required'; end if;
   select jsonb_agg(jsonb_build_object('id',id,'sequence',sequence) order by sequence),max(sequence)::bigint
    into previous,offset_seq from public.delivery_stops where delivery_stops.run_id=r.id and closed_at is null;
   if offset_seq+cardinality(ids)>2147483647 then raise exception using errcode='22003',message='Sequence range exhausted'; end if;
   for i in 1..cardinality(ids) loop update public.delivery_stops set sequence=(offset_seq+i)::integer where id=ids[i]; end loop;
   for i in 1..cardinality(ids) loop update public.delivery_stops set sequence=slots[i] where id=ids[i]; end loop;
   result:=jsonb_build_object('id',r.id,'stop_ids',ids);
  elsif action='depart' then
   if actor_role<>'driver' or not private.assigned_run(r.id) then raise exception using errcode='42501',message='Assigned driver departs'; end if;
   if r.status<>'planned' or not exists(select 1 from public.delivery_stops where delivery_stops.run_id=r.id and closed_at is null) or
    exists(select 1 from public.delivery_stops s join public.orders x on x.id=s.order_id where s.run_id=r.id and s.closed_at is null
     and (s.completed_at is not null or x.status<>'loaded')) then
    raise exception using errcode='23514',message='Nonempty fully loaded planned run required'; end if;
   update public.delivery_runs set status='in_progress',started_at=now() where id=r.id;
   for o in select x.* from public.orders x join public.delivery_stops s on s.order_id=x.id where s.run_id=r.id and s.closed_at is null order by x.id loop
    update public.orders set status='out_for_delivery' where id=o.id;
    insert into public.order_status_history(order_id,from_status,to_status,changed_by,reason,operation_key)
     values(o.id,'loaded','out_for_delivery',auth.uid(),'Sefer yola çıktı',gen_random_uuid());
    insert into public.audit_logs(actor_id,action,entity_type,entity_id,old_data,new_data,operation_key)
     values(auth.uid(),'order_status_changed','order',o.id,jsonb_build_object('status','loaded'),jsonb_build_object('status','out_for_delivery'),request_key);
   end loop;
   result:=jsonb_build_object('id',r.id,'status','in_progress');
  elsif action in ('complete','cancel') then
   if exists(select 1 from public.delivery_stops where delivery_stops.run_id=r.id and closed_at is null) then
    raise exception using errcode='23514',message='All stops must already be closed'; end if;
   if action='complete' then
    if r.status<>'in_progress' or exists(select 1 from public.delivery_stops s join public.orders x on x.id=s.order_id
      where s.run_id=r.id and x.status not in ('delivered','cancelled','rejected')) then
     raise exception using errcode='23514',message='Started run with terminal orders required'; end if;
   elsif r.status<>'planned' then raise exception using errcode='23514',message='Only never-started run can cancel'; end if;
   update public.delivery_runs set status=case when action='complete' then 'completed' else 'cancelled' end,ended_at=now() where id=r.id;
   result:=jsonb_build_object('id',r.id,'status',case when action='complete' then 'completed' else 'cancelled' end);
  end if;
 end if;
 insert into public.audit_logs(actor_id,action,entity_type,entity_id,old_data,new_data,operation_key)
 values(auth.uid(),'dispatch_changed',case when action='vehicle' then 'vehicle' else 'delivery_run' end,target,
  previous,jsonb_build_object('request',payload,'result',result),request_key);
 insert into private.dispatch_receipts values(request_key,auth.uid(),payload,result);
 return result;
end; $$;
revoke all on function public.dispatch_action(text,jsonb,uuid) from public,anon;
grant execute on function public.dispatch_action(text,jsonb,uuid) to authenticated;

create function public.dispatch_workspace() returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare manager boolean:=coalesce(private.current_app_role() in ('manager','owner'),false); result jsonb;
begin
 if not manager and private.current_app_role() is distinct from 'driver'::public.app_role then
  raise exception using errcode='42501',message='Dispatch scope denied'; end if;
 select jsonb_build_object(
  'vehicles',coalesce((select jsonb_agg(jsonb_build_object('id',id,'plate',plate,'active',active,'description',description) order by plate)
    from public.vehicles v where manager or exists(select 1 from public.delivery_runs r where r.vehicle_id=v.id and private.assigned_run(r.id))),'[]'::jsonb),
  'drivers',coalesce((select jsonb_agg(jsonb_build_object('id',id,'name',name) order by name) from public.profiles where manager and role='driver' and active),'[]'::jsonb),
  'orders',coalesce((select jsonb_agg(jsonb_build_object('id',o.id,'number',o.id,'run_id',s.run_id) order by o.id)
    from public.orders o left join public.delivery_stops s on s.order_id=o.id and s.closed_at is null where manager and o.status='picked'
    and exists(select 1 from public.order_items where order_id=o.id) and not exists(select 1 from public.order_items where order_id=o.id and picked_qty<>quantity)),'[]'::jsonb),
  'runs',coalesce((select jsonb_agg(jsonb_build_object('id',r.id,'vehicle_id',r.vehicle_id,'plate',v.plate,'primary_id',r.primary_driver_id,
    'assistant_id',r.assistant_driver_id,'status',r.status,'managed',r.dispatch_managed,'ended_at',r.ended_at,
    'stops',coalesce((select jsonb_agg(jsonb_build_object('id',s.id,'order_id',s.order_id,'number',o.id,'order_status',o.status,
     'sequence',s.sequence,'closed_at',s.closed_at,'completed_at',s.completed_at,'previous_stop_id',s.previous_stop_id) order by s.sequence,s.assigned_at)
     from public.delivery_stops s join public.orders o on o.id=s.order_id where s.run_id=r.id),'[]'::jsonb)) order by r.ended_at nulls first,r.id)
   from public.delivery_runs r join public.vehicles v on v.id=r.vehicle_id where manager or private.assigned_run(r.id)),'[]'::jsonb)) into result;
 return result;
end; $$;
revoke all on function public.dispatch_workspace() from public,anon;
grant execute on function public.dispatch_workspace() to authenticated;
commit;
