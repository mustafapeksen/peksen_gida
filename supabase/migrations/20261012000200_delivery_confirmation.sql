-- F13-01: confirmation, dispute resolution, one rating and private evidence.
begin;
create table private.delivery_receipts (
 operation_key uuid primary key, actor_id uuid not null references public.profiles(id),
 payload jsonb not null, response jsonb not null);
create table private.delivery_evidence (
 id uuid primary key, order_id uuid not null references public.orders(id),
 uploaded_by uuid not null references public.profiles(id), object_name text not null unique,
 mime_type text not null check(mime_type in ('image/jpeg','image/png')),
 created_at timestamptz not null default now());
alter table private.delivery_receipts enable row level security;
alter table private.delivery_evidence enable row level security;
revoke all on private.delivery_receipts,private.delivery_evidence from public,anon,authenticated;

create function private.delivery_scope(target uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.orders o where o.id=target and (
 private.current_app_role() in ('manager','owner') or private.owns_customer(o.customer_id) or
 (private.current_app_role()='driver' and exists(select 1 from public.delivery_stops s
 join public.delivery_runs r on r.id=s.run_id where s.order_id=o.id and s.closed_at is null
 and r.ended_at is null and r.status='in_progress' and private.assigned_run(r.id)))));
$$;

create function public.delivery_action(action text, data jsonb, request_key uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor_role public.app_role; prior private.delivery_receipts; payload jsonb;
 o public.orders; s public.delivery_stops; r public.delivery_runs; target uuid; result jsonb;
 next_status public.order_state; event_kind text; note text; driver_id uuid; score integer;
 reasons text[]; evidence_id uuid; mime text;
begin
 if action is null or action not in ('driver_confirm','customer_confirm','dispute','resolve','rate','evidence')
 or data is null or jsonb_typeof(data)<>'object' or request_key is null then
 raise exception using errcode='22023',message='Delivery action, object and key required'; end if;
 target:=(data->>'order_id')::uuid;
 if target is null then raise exception using errcode='22023',message='Order required'; end if;
 perform 1 from auth.users where id=auth.uid() for share;
 perform 1 from public.profiles where id=auth.uid() for share;
 actor_role:=private.current_app_role();
 if not coalesce(actor_role in ('customer','driver','manager','owner'),false) or
 (action in ('driver_confirm','evidence') and actor_role<>'driver') or
 (action in ('customer_confirm','dispute','rate') and actor_role<>'customer') or
 (action='resolve' and actor_role not in ('manager','owner')) then
 raise exception using errcode='42501',message='Delivery role denied'; end if;
 payload:=jsonb_build_object('action',action,'data',data);
 perform pg_advisory_xact_lock(hashtextextended(request_key::text,73013));
 select * into prior from private.delivery_receipts where operation_key=request_key;
 if found then
  if prior.actor_id<>auth.uid() or prior.payload<>payload then
   raise exception using errcode='22023',message='Key already used'; end if;
  -- Receipt contains only this actor's operation result, not current order data.
  return prior.response;
 end if;
 perform 1 from public.customers where id=(select customer_id from public.orders where id=target) for update;
 select * into o from public.orders where id=target for update;
 if not found or not private.delivery_scope(target) then
 raise exception using errcode='42501',message='Delivery scope denied'; end if;
 note:=nullif(btrim(data->>'reason'),'');
 if length(note)>2000 or length(data->>'comment')>2000 then
 raise exception using errcode='22023',message='Text too long'; end if;
 if action='rate' then
  select performed_by into driver_id from public.delivery_confirmations
   where order_id=o.id and event_type='driver' and driver_confirmed;
  if o.status<>'delivered' or not private.delivery_finalized(o.id) or driver_id is null then
   raise exception using errcode='23514',message='Finalized delivery with actual driver required'; end if;
  if jsonb_typeof(data->'score') is distinct from 'number' or (data->>'score')!~'^[1-5]$'
   or (data ? 'reasons' and jsonb_typeof(data->'reasons')<>'array') then
   raise exception using errcode='22023',message='Rating must be 1 to 5'; end if;
  score:=(data->>'score')::integer;
  select coalesce(array_agg(value),array[]::text[]) into reasons from jsonb_array_elements_text(coalesce(data->'reasons','[]'));
  if not reasons <@ array['late','behavior','missing_product','damage','other']::text[]
   or cardinality(reasons)<>(select count(distinct v) from unnest(reasons) v) then
   raise exception using errcode='22023',message='Invalid rating reasons'; end if;
  insert into public.ratings(order_id,customer_id,driver_id,score,reason_codes,comment)
   values(o.id,o.customer_id,driver_id,score,reasons,nullif(btrim(data->>'comment'),''));
  result:=jsonb_build_object('order_id',o.id,'score',score);
 else
  select * into r from public.delivery_runs where id=(select run_id from public.delivery_stops
   where order_id=o.id and closed_at is null) for update;
  select * into s from public.delivery_stops where order_id=o.id and closed_at is null for update;
  if s.id is null or r.id is null or r.status<>'in_progress' or r.ended_at is not null then
   raise exception using errcode='23514',message='Open delivery required'; end if;
  if action='evidence' then
   mime:=data->>'mime_type';
   if o.status<>'delivery_disputed' then raise exception using errcode='23514',message='Disputed delivery required'; end if;
   if mime is null or mime not in ('image/jpeg','image/png') then raise exception using errcode='22023',message='JPEG or PNG required'; end if;
   evidence_id:=gen_random_uuid();
   insert into private.delivery_evidence(id,order_id,uploaded_by,object_name,mime_type)
    values(evidence_id,o.id,auth.uid(),evidence_id::text || case when mime='image/png' then '.png' else '.jpg' end,mime);
   result:=jsonb_build_object('order_id',o.id,'object_name',evidence_id::text || case when mime='image/png' then '.png' else '.jpg' end);
  else
   if action='driver_confirm' then
    if o.status<>'out_for_delivery' then raise exception using errcode='23514',message='Out for delivery required'; end if;
    next_status:='delivery_pending_confirmation'; event_kind:='driver';
   elsif action in ('customer_confirm','dispute') then
    if o.status<>'delivery_pending_confirmation' or not exists(select 1 from public.delivery_confirmations
     where order_id=o.id and event_type='driver' and driver_confirmed) then
     raise exception using errcode='23514',message='Driver confirmation required'; end if;
    if action='dispute' then
     if note is null then raise exception using errcode='22023',message='Dispute reason required'; end if;
     next_status:='delivery_disputed'; event_kind:='dispute';
    else next_status:='delivered'; event_kind:='customer'; end if;
   else
    if o.status not in ('delivery_pending_confirmation','delivery_disputed') or not exists(select 1 from public.delivery_confirmations
     where order_id=o.id and event_type='driver' and driver_confirmed) then
     raise exception using errcode='23514',message='Pending confirmed delivery required'; end if;
    if note is null then raise exception using errcode='22023',message='Resolution reason required'; end if;
    next_status:='delivered'; event_kind:='resolution';
   end if;
   insert into public.delivery_confirmations(order_id,event_type,driver_confirmed,customer_confirmed,finalizes_delivery,
    performed_by,dispute_reason,resolution_reason,operation_key)
    values(o.id,event_kind,event_kind='driver',event_kind='customer',next_status='delivered',auth.uid(),
     case when event_kind='dispute' then note end,case when event_kind='resolution' then note end,request_key);
   update public.orders set status=next_status,delivered_at=case when next_status='delivered' then now() else delivered_at end where id=o.id;
   if next_status='delivered' then
    update public.delivery_stops set status='delivered',completed_at=now(),closed_at=now(),closed_by=auth.uid(),
     close_reason=coalesce(note,'Teslimat kesinleşti') where id=s.id;
   end if;
   insert into public.order_status_history(order_id,from_status,to_status,changed_by,reason,operation_key)
    values(o.id,o.status,next_status,auth.uid(),coalesce(note,'Teslimat onayı'),request_key);
   insert into public.audit_logs(actor_id,action,entity_type,entity_id,old_data,new_data,operation_key)
    values(auth.uid(),case when event_kind='dispute' then 'delivery_disputed' when event_kind='resolution' then 'delivery_resolved'
     else 'order_status_changed' end,'order',o.id,jsonb_build_object('status',o.status),jsonb_build_object('status',next_status,'event',event_kind),request_key);
   result:=jsonb_build_object('order_id',o.id,'status',next_status);
  end if;
 end if;
 insert into private.delivery_receipts values(request_key,auth.uid(),payload,result);
 return result;
end; $$;

-- Private authenticated downloads: no public URLs, update/delete policies or signed-upload bypass.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
 values('delivery-evidence','delivery-evidence',false,5242880,array['image/jpeg','image/png']);
create function private.delivery_evidence_access(path text, writing boolean) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from private.delivery_evidence e join public.orders o on o.id=e.order_id
 where e.object_name=path and case when writing then
 private.current_app_role()='driver' and e.uploaded_by=auth.uid() and o.status='delivery_disputed' and private.delivery_scope(o.id)
 else private.current_app_role() in ('manager','owner') or (private.current_app_role()='driver' and e.uploaded_by=auth.uid()) end);
$$;
create policy delivery_evidence_insert on storage.objects for insert to authenticated with check
 (bucket_id='delivery-evidence' and private.delivery_evidence_access(name,true));
create policy delivery_evidence_read on storage.objects for select to authenticated using
 (bucket_id='delivery-evidence' and private.delivery_evidence_access(name,false));

create function public.delivery_workspace() returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare result jsonb; actor_role public.app_role:=private.current_app_role();
begin
 if not coalesce(actor_role in ('customer','driver','manager','owner'),false) then
 raise exception using errcode='42501',message='Delivery role denied'; end if;
 select coalesce(jsonb_agg(jsonb_build_object('id',o.id,'number',o.id,'status',o.status,
  'dispute_reason',(select dispute_reason from public.delivery_confirmations where order_id=o.id and event_type='dispute' order by created_at desc limit 1),
  'score',(select score from public.ratings where order_id=o.id and actor_role in ('customer','manager','owner')),
  'can_rate',actor_role='customer' and o.status='delivered' and private.delivery_finalized(o.id)
    and exists(select 1 from public.delivery_confirmations where order_id=o.id and event_type='driver')
    and not exists(select 1 from public.ratings where order_id=o.id),
  'evidence',coalesce((select jsonb_agg(jsonb_build_object('object_name',e.object_name)) from private.delivery_evidence e
    join storage.objects x on x.bucket_id='delivery-evidence' and x.name=e.object_name
    where e.order_id=o.id and private.delivery_evidence_access(e.object_name,false)),'[]'::jsonb)) order by o.created_at desc),'[]'::jsonb)
 into result from public.orders o where o.status in ('out_for_delivery','delivery_pending_confirmation','delivery_disputed','delivered')
 and (private.delivery_scope(o.id) or (actor_role='driver' and exists(select 1 from private.delivery_evidence e where e.order_id=o.id and e.uploaded_by=auth.uid())));
 return jsonb_build_object('orders',result);
end; $$;
revoke all on function public.delivery_action(text,jsonb,uuid),public.delivery_workspace(),private.delivery_scope(uuid),private.delivery_evidence_access(text,boolean) from public,anon,authenticated;
grant execute on function public.delivery_action(text,jsonb,uuid),public.delivery_workspace(),private.delivery_evidence_access(text,boolean) to authenticated;
commit;
