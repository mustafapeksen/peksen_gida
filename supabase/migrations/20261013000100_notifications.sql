-- Phase 14: private device/session registration and own inbox.
begin;
-- The Phase 14 inbox contract is own-user-only, including Owner. Other Owner
-- operational policies remain untouched; notifications are not an audit feed.
drop policy owner_read on public.notifications;
create table private.push_devices (
 id uuid primary key, user_id uuid not null references public.profiles(id),
 session_id uuid not null, token text not null unique check(length(token) between 20 and 4096),
 updated_at timestamptz not null default now());
alter table private.push_devices enable row level security;
revoke all on private.push_devices from public,anon,authenticated;

create function public.register_push_device(device_id uuid, device_token text) returns void
language plpgsql security definer set search_path='' as $$
declare session_key uuid:=(auth.jwt()->>'session_id')::uuid;
begin
 if private.current_app_role() is null or session_key is null or not exists(
  select 1 from auth.sessions where id=session_key and user_id=auth.uid()
  and (not_after is null or not_after>now())) then
  raise exception using errcode='42501',message='Active session required'; end if;
 if device_id is null or device_token is null or length(device_token) not between 20 and 4096
  or device_token ~ '[[:space:]]' then
  raise exception using errcode='22023',message='Valid device registration required'; end if;
 perform pg_advisory_xact_lock(73014,1);
 -- A token is the possession proof for re-binding a shared phone after login.
 -- No caller can read another token or change a guessed device id.
 if exists(select 1 from private.push_devices where id=device_id and user_id<>auth.uid() and token<>device_token) then
  raise exception using errcode='42501',message='Device ownership denied'; end if;
 delete from private.push_devices where token=device_token and id<>device_id;
 insert into private.push_devices(id,user_id,session_id,token) values(device_id,auth.uid(),session_key,device_token)
 on conflict(id) do update set user_id=excluded.user_id,session_id=excluded.session_id,token=excluded.token,updated_at=now();
end; $$;
create function public.unregister_push_device(device_id uuid) returns void
language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null then raise exception using errcode='42501',message='Session required'; end if;
 delete from private.push_devices where id=device_id and user_id=auth.uid();
end; $$;
create function public.notification_inbox(before_time timestamptz default null, before_id uuid default null) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare result jsonb;
begin
 if private.current_app_role() is null then raise exception using errcode='42501',message='Active account required'; end if;
 if (before_time is null)<>(before_id is null) then raise exception using errcode='22023',message='Complete cursor required'; end if;
 select coalesce(jsonb_agg(to_jsonb(n) order by n.created_at desc,n.id desc),'[]') into result from (
 select id,type,title,body,created_at,read_at from public.notifications
 where user_id=auth.uid() and (before_time is null or (created_at,id)<(before_time,before_id))
 order by created_at desc,id desc limit 50) n;
 return result;
end; $$;
create function public.read_notification(notification_id uuid) returns void
language plpgsql security definer set search_path='' as $$
begin
 if private.current_app_role() is null then raise exception using errcode='42501',message='Active account required'; end if;
 update public.notifications set read_at=coalesce(read_at,now()) where id=notification_id and user_id=auth.uid();
 if not found then raise exception using errcode='42501',message='Notification denied'; end if;
end; $$;
revoke all on function public.register_push_device(uuid,text),public.unregister_push_device(uuid),public.notification_inbox(timestamptz,uuid),public.read_notification(uuid) from public,anon,authenticated;
grant execute on function public.register_push_device(uuid,text),public.unregister_push_device(uuid),public.notification_inbox(timestamptz,uuid),public.read_notification(uuid) to authenticated;

-- Business facts are collected AFTER commit by the server worker. Neither FCM
-- nor inbox failures run in an order/stock/payment transaction.
alter table public.notifications add column event_key text;
create unique index notifications_event_recipient on public.notifications(event_key,user_id);
create table private.notification_epoch(started_at timestamptz not null);
insert into private.notification_epoch values(now());
create table private.notification_events(event_key text primary key, created_at timestamptz not null default now());
-- No coordinates; persist short-lived tracking failures so recovery before the
-- next worker poll cannot hide them. Notification storage cannot fail tracking.
create table private.notification_tracking_facts(id uuid primary key default gen_random_uuid(), run_id uuid not null,
 created_at timestamptz not null default now());
create function private.capture_tracking_notification() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if new.status in ('permission_denied','gps_disabled') and
  (tg_op='INSERT' or old.status is distinct from new.status or old.publisher_key is distinct from new.publisher_key) then
  insert into private.notification_tracking_facts(run_id) values(new.run_id);
 end if;
 return null;
exception when others then return null;
end; $$;
revoke all on function private.capture_tracking_notification() from public,anon,authenticated;
create trigger capture_tracking_notification after insert or update on private.run_tracking
 for each row execute function private.capture_tracking_notification();
create table private.notification_campaigns (
 id uuid primary key, actor_id uuid not null references public.profiles(id), product_id uuid not null references public.products(id),
 customer_ids uuid[] not null, reason text not null check(length(btrim(reason)) between 1 and 2000),
 created_at timestamptz not null default now());
create table private.push_jobs (
 id uuid primary key default gen_random_uuid(), notification_id uuid not null references public.notifications(id),
 device_id uuid not null references private.push_devices(id) on delete cascade,
 state text not null default 'pending' check(state in ('pending','sending','sent','failed','cancelled')),
 attempts integer not null default 0, available_at timestamptz not null default now(),
 lease_id uuid, leased_until timestamptz, unique(notification_id,device_id));
do $$declare t text; begin
 foreach t in array array['notification_epoch','notification_events','notification_tracking_facts','notification_campaigns','push_jobs'] loop
 execute format('alter table private.%I enable row level security',t);
 execute format('revoke all on private.%I from public,anon,authenticated',t);
 end loop;
end; $$;
create index notification_history_collection on public.order_status_history(created_at);

create function private.notification_recipient(person uuid, kind text, entity text, target uuid) returns boolean
language plpgsql stable security definer set search_path='' as $$
declare p public.profiles; o public.orders; r public.delivery_runs; customer uuid; c public.customers;
begin
 select * into p from public.profiles where id=person and active;
 if not found or not exists(select 1 from auth.users where id=person and deleted_at is null and (banned_until is null or banned_until<now())) then return false; end if;
 if entity='order' then select * into o from public.orders where id=target; customer:=o.customer_id;
 elsif entity='alternative' then
  select x.* into o from public.orders x join public.order_items i on i.order_id=x.id join public.alternative_offers a on a.order_item_id=i.id where a.id=target; customer:=o.customer_id;
 elsif entity='run' then select * into r from public.delivery_runs where id=target;
 elsif entity='campaign' then
  return p.role='customer' and exists(select 1 from private.notification_campaigns x
   join public.customer_users cu on cu.customer_id=any(x.customer_ids) join public.customers company on company.id=cu.customer_id
   join public.products pr on pr.id=x.product_id where x.id=target and cu.user_id=person and cu.active and company.active and pr.active);
 else return false; end if;
 select * into c from public.customers where id=customer;
 if kind in ('approved','alternative','preparing','departed','delivered','credit') and p.role='customer' then
  return coalesce(c.active,false) and exists(select 1 from public.customer_users where user_id=person and customer_id=customer and active);
 end if;
 if kind='new_order' then
  return p.role='warehouse' or coalesce(p.role='sales_operator' and c.active and c.assigned_sales_operator_id=person,false);
 elsif kind in ('ready','assigned_ready') then
  return (kind='ready' and p.role in ('manager','owner')) or (p.role='driver' and exists(select 1 from public.delivery_stops s join public.delivery_runs dr on dr.id=s.run_id
   where s.order_id=o.id and s.closed_at is null and dr.ended_at is null and person in (dr.primary_driver_id,dr.assistant_driver_id)));
 elsif kind='gps_problem' then return p.role in ('manager','owner') and r.ended_at is null;
 elsif kind='disputed' then return p.role in ('manager','owner');
 elsif kind='credit' then return p.role='accounting' and c.active and c.assigned_sales_operator_id is not null;
 end if;
 return false;
end; $$;

create function public.create_notification_campaign(product uuid, customers uuid[], reason text, request_key uuid) returns uuid
language plpgsql security definer set search_path='' as $$
declare previous private.notification_campaigns; normalized uuid[];
begin
 perform 1 from auth.users where id=auth.uid() for share;
 perform 1 from public.profiles where id=auth.uid() for share;
 if not coalesce(private.current_app_role() in ('manager','owner'),false) then raise exception using errcode='42501',message='Campaign role denied'; end if;
 if request_key is null or product is null or customers is null or cardinality(customers)=0 or cardinality(customers)>500
 or reason is null or length(btrim(reason)) not between 1 and 2000 then raise exception using errcode='22023',message='Product, explicit customers, reason and key required'; end if;
 select array_agg(distinct id order by id) into normalized from unnest(customers) id;
 perform pg_advisory_xact_lock(hashtextextended(request_key::text,73014));
 select * into previous from private.notification_campaigns where id=request_key;
 if found then
 if previous.actor_id<>auth.uid() or previous.product_id<>product or previous.customer_ids<>normalized or previous.reason<>btrim(reason) then raise exception using errcode='22023',message='Campaign key conflict'; end if;
 return previous.id; end if;
 if not exists(select 1 from public.products where id=product and active) or exists(select 1 from unnest(normalized) selected(customer_id) where selected.customer_id is null or not exists(select 1 from public.customers c where c.id=selected.customer_id and c.active)) then
 raise exception using errcode='23514',message='Active product and customers required'; end if;
 insert into private.notification_campaigns(id,actor_id,product_id,customer_ids,reason) values(request_key,auth.uid(),product,normalized,btrim(reason));
 return request_key;
end; $$;

create function public.collect_notifications() returns integer
language plpgsql security definer set search_path='' as $$
declare event record; person uuid; added integer:=0;
begin
 -- Executable only by the server role; a client role string is never consulted.
 perform pg_advisory_xact_lock(73014,2);
 for event in
  select * from (
   select 'history:'||h.id as key, case h.to_status when 'submitted' then case when h.from_status='pending_approval' then 'approved' else 'new_order' end
    when 'picking' then 'preparing' when 'picked' then 'ready' when 'out_for_delivery' then 'departed'
    when 'delivery_disputed' then 'disputed' when 'delivered' then 'delivered' when 'pending_approval' then 'credit' end as kind,
    'order' as entity,h.order_id as target,h.created_at as occurred from public.order_status_history h
   join public.orders o on o.id=h.order_id where h.to_status in ('submitted','picking','picked','out_for_delivery','delivery_disputed','delivered','pending_approval')
    and h.from_status is distinct from h.to_status and (h.to_status<>'pending_approval' or exists(
     select 1 from public.order_approvals approval where approval.order_id=o.id and approval.approval_kind='credit'))
   union all select 'history-new:'||h.id,'new_order','order',h.order_id,h.created_at from public.order_status_history h where h.to_status='submitted' and h.from_status='pending_approval'
   union all select 'alternative:'||a.id,'alternative','alternative',a.id,a.created_at from public.alternative_offers a
   union all select 'assignment:'||s.id,'assigned_ready','order',s.order_id,s.assigned_at from public.delivery_stops s where s.closed_at is null
   union all select 'gps:'||t.id,'gps_problem','run',t.run_id,t.created_at from private.notification_tracking_facts t
   union all select 'campaign:'||c.id,'campaign','campaign',c.id,c.created_at from private.notification_campaigns c
  ) e where e.occurred>=(select started_at from private.notification_epoch) and not exists(select 1 from private.notification_events n where n.event_key=e.key)
  order by occurred,key limit 500
 loop
  for person in select id from public.profiles where private.notification_recipient(id,event.kind,event.entity,event.target) loop
   insert into public.notifications(user_id,type,title,body,entity_type,entity_id,event_key)
   values(person,event.kind,'Pekşen Gıda','Yeni bir bildiriminiz var. Ayrıntıları uygulamada görüntüleyin.',event.entity,event.target,event.key)
   on conflict(event_key,user_id) do nothing;
  end loop;
  insert into private.notification_events(event_key) values(event.key);
  added:=added+1;
 end loop;
 -- Only currently registered devices receive a push; inbox survives disabled FCM.
 insert into private.push_jobs(notification_id,device_id)
 select n.id,d.id from public.notifications n join private.push_devices d on d.user_id=n.user_id
 where n.event_key is not null and n.created_at>=d.updated_at on conflict do nothing;
 return added;
end; $$;

create function public.claim_push_jobs(batch_size integer default 25) returns jsonb
language plpgsql security definer set search_path='' as $$
declare j private.push_jobs; n public.notifications; d private.push_devices; lease uuid; result jsonb:='[]';
begin
 if batch_size is null or batch_size not between 1 and 100 then raise exception using errcode='22023',message='Invalid batch size'; end if;
 for j in select * from private.push_jobs where (state='pending' and available_at<=now()) or
  (state='sending' and leased_until<now()) order by available_at,id for update skip locked limit batch_size loop
  select * into n from public.notifications where id=j.notification_id;
  select * into d from private.push_devices where id=j.device_id;
  if d.user_id is distinct from n.user_id or not coalesce(private.notification_recipient(n.user_id,n.type,n.entity_type,n.entity_id),false)
   or not exists(select 1 from auth.sessions where id=d.session_id and user_id=d.user_id and (not_after is null or not_after>now())) then
   update private.push_jobs set state='cancelled' where id=j.id; continue; end if;
  if j.attempts>=6 then update private.push_jobs set state='failed' where id=j.id; continue; end if;
  lease:=gen_random_uuid();
  update private.push_jobs set state='sending',attempts=attempts+1,lease_id=lease,leased_until=now()+interval '2 minutes' where id=j.id;
  result:=result||jsonb_build_array(jsonb_build_object('job_id',j.id,'lease_id',lease,'notification_id',n.id,'user_id',n.user_id,'token',d.token));
 end loop;
 return result;
end; $$;
create function public.finish_push_job(job uuid, lease uuid, outcome text) returns void
language plpgsql security definer set search_path='' as $$
declare j private.push_jobs;
begin
 if outcome is null or outcome not in ('sent','retry','invalid','failed') then raise exception using errcode='22023',message='Invalid outcome'; end if;
 select * into j from private.push_jobs where id=job and lease_id=lease and state='sending' for update;
 if not found then return; end if;
 update private.push_jobs set state=case when outcome='sent' then 'sent' when outcome='retry' and attempts<6 then 'pending' else 'failed' end,
 available_at=now()+make_interval(secs=>least(3600,30*(2^j.attempts)::integer)),leased_until=null where id=job;
 -- Do not delete a token refreshed/rebound while an old request was in flight.
 if outcome='invalid' then delete from private.push_devices d where d.id=j.device_id and d.updated_at<j.leased_until-interval '2 minutes'; end if;
end; $$;

create function public.notification_destination(notification_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare n public.notifications; role public.app_role:=private.current_app_role(); route text; target uuid;
begin
 select * into n from public.notifications where id=notification_id and user_id=auth.uid();
 if not found or role is null or not coalesce(private.notification_recipient(auth.uid(),n.type,n.entity_type,n.entity_id),false) then raise exception using errcode='42501',message='Notification target no longer accessible'; end if;
 target:=n.entity_id;
 if n.entity_type='campaign' then
  select product_id into target from private.notification_campaigns where id=target;
  route:='/account/shop/product/'||target;
 elsif n.type='alternative' then
  select i.order_id into target from public.order_items i join public.alternative_offers a on a.order_item_id=i.id where a.id=target;
  route:='/account/shop/orders/'||target||'/alternatives';
 elsif n.type in ('delivered','disputed') then route:='/account/deliveries';
 elsif n.type in ('gps_problem','departed') then
  if n.type='departed' and not exists(select 1 from public.orders where id=target and status='out_for_delivery') then raise exception using errcode='42501',message='Tracking ended'; end if;
  route:='/account/tracking';
 elsif n.type in ('ready','assigned_ready') then route:='/account/dispatch';
 elsif role='warehouse' then route:='/account/inventory?order='||n.entity_id;
 elsif role='sales_operator' then
  select customer_id into target from public.orders where id=target;
  route:='/account/sales/'||target||'/orders?order='||n.entity_id;
 elsif role='accounting' then route:='/account/finance';
 else route:='/account/shop/orders?order='||n.entity_id; end if;
 update public.notifications set read_at=coalesce(read_at,now()) where id=n.id;
 return jsonb_build_object('route',route,'entity_id',target);
end; $$;

revoke all on function private.notification_recipient(uuid,text,text,uuid),public.collect_notifications(),public.claim_push_jobs(integer),public.finish_push_job(uuid,uuid,text),public.notification_destination(uuid),public.create_notification_campaign(uuid,uuid[],text,uuid) from public,anon,authenticated;
grant execute on function public.collect_notifications(),public.claim_push_jobs(integer),public.finish_push_job(uuid,uuid,text) to service_role;
grant execute on function public.notification_destination(uuid),public.create_notification_campaign(uuid,uuid[],text,uuid) to authenticated;
commit;
