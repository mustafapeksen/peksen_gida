-- F12-01: latest point only, primary Driver publisher, no delivery transitions.
begin;
create table private.run_tracking (
 run_id uuid primary key references public.delivery_runs(id),
 publisher_key uuid not null,
 driver_id uuid not null references public.profiles(id),
 status text not null check(status in ('starting','live','permission_denied','gps_disabled','stopped')),
 latitude double precision check(latitude between -90 and 90),
 longitude double precision check(longitude between -180 and 180),
 accuracy double precision check(accuracy>=0 and accuracy<'Infinity'::float8),
 sampled_at timestamptz, received_at timestamptz,
 check((latitude is null and longitude is null and sampled_at is null and received_at is null)
  or (latitude is not null and longitude is not null and sampled_at is not null and received_at is not null))
);
alter table private.run_tracking enable row level security;
revoke all on private.run_tracking from public,anon,authenticated;
-- Private broadcast channels carry invalidation only, never coordinates or IDs.
create table private.tracking_viewers (viewer_id uuid primary key references public.profiles(id));
alter table private.tracking_viewers enable row level security;
revoke all on private.tracking_viewers from public,anon,authenticated;
-- Supabase owns realtime.messages and already enables RLS; only add our policy.
create policy own_tracking_channel on realtime.messages for select to authenticated using (
 extension='broadcast' and realtime.topic()='tracking:'||auth.uid()::text
 and private.current_app_role() in ('customer','driver','manager','owner'));
create function private.signal_tracking() returns void
language plpgsql security definer set search_path='' as $$
declare viewer uuid;
begin
 for viewer in select viewer_id from private.tracking_viewers loop
  perform realtime.send('{"changed":true}'::jsonb,'changed','tracking:'||viewer::text,true);
 end loop;
exception when others then
 -- Realtime is a best-effort invalidation, not a prerequisite of stock/order commits.
 -- The authorized polling fallback reads current data; never suppress cleanup errors.
 return;
end; $$;

create function private.trackable_run(target uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.delivery_runs r where r.id=target and r.status='in_progress' and r.ended_at is null
  and exists(select 1 from public.delivery_stops s join public.orders o on o.id=s.order_id
   where s.run_id=r.id and s.closed_at is null and s.completed_at is null and o.status='out_for_delivery'));
$$;
create function private.can_track_run(target uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select private.trackable_run(target) and coalesce(
  private.current_app_role() in ('manager','owner') or private.assigned_run(target) or
  exists(select 1 from public.delivery_stops s join public.orders o on o.id=s.order_id
   where s.run_id=target and s.closed_at is null and s.completed_at is null and o.status='out_for_delivery'
   and private.owns_customer(o.customer_id)),false);
$$;
create function private.tracking_cleanup_signal() returns trigger
language plpgsql security definer set search_path='' as $$
declare affected uuid[];
begin
 if tg_table_name='delivery_runs' then
  affected:=array[case when tg_op='DELETE' then old.id else new.id end];
 elsif tg_table_name='delivery_stops' then
  affected:=array[case when tg_op='DELETE' then old.run_id else new.run_id end];
 elsif tg_table_name='orders' then
  select array_agg(run_id) into affected from public.delivery_stops
   where order_id=case when tg_op='DELETE' then old.id else new.id end;
 end if;
 delete from private.run_tracking t where t.run_id=any(affected) and not private.trackable_run(t.run_id);
 -- Broadcasting does not introduce shared signal-row locks into order/stock transactions.
 perform private.signal_tracking();
 return null;
end; $$;
create trigger tracking_order_changed after insert or update or delete on public.orders
 for each row execute function private.tracking_cleanup_signal();
create trigger tracking_stop_changed after insert or update or delete on public.delivery_stops
 for each row execute function private.tracking_cleanup_signal();
create trigger tracking_run_changed after insert or update or delete on public.delivery_runs
 for each row execute function private.tracking_cleanup_signal();
create trigger tracking_customer_changed after update on public.customers
 for each row execute function private.tracking_cleanup_signal();
create trigger tracking_member_changed after insert or update or delete on public.customer_users
 for each row execute function private.tracking_cleanup_signal();
create trigger tracking_profile_changed after update on public.profiles
 for each row execute function private.tracking_cleanup_signal();

create function public.tracking_workspace() returns jsonb
language plpgsql security definer set search_path='' as $$
declare result jsonb;
begin
 if not coalesce(private.current_app_role() in ('customer','driver','manager','owner'),false) then
  raise exception using errcode='42501',message='Tracking access denied'; end if;
 insert into private.tracking_viewers(viewer_id) values(auth.uid()) on conflict do nothing;
 select coalesce(jsonb_agg(jsonb_build_object('id',r.id,'plate',v.plate,
  'can_publish',private.current_app_role()='driver' and r.primary_driver_id=auth.uid(),
  'status',coalesce(t.status,'unavailable'),'latitude',t.latitude,'longitude',t.longitude,'accuracy',t.accuracy,
  'sampled_at',t.sampled_at,'received_at',t.received_at,
  'stale',t.sampled_at is null or t.sampled_at<clock_timestamp()-interval '60 seconds') order by r.id),'[]'::jsonb)
 into result from public.delivery_runs r join public.vehicles v on v.id=r.vehicle_id
 left join private.run_tracking t on t.run_id=r.id where private.can_track_run(r.id);
 return result;
end; $$;

create function public.tracking_control(target_run uuid, publisher uuid, action text) returns boolean
language plpgsql security definer set search_path='' as $$
declare r public.delivery_runs;
begin
 perform 1 from auth.users where id=auth.uid() for share;
 perform 1 from public.profiles where id=auth.uid() for share;
 if private.current_app_role() is distinct from 'driver'::public.app_role then
  raise exception using errcode='42501',message='Driver required'; end if;
 -- Run before point lock agrees with dispatch; does not lock customers/orders in reverse.
 select * into r from public.delivery_runs where id=target_run for share;
 if not found or r.primary_driver_id<>auth.uid() then raise exception using errcode='42501',message='Primary driver required'; end if;
 if publisher is null or action is null or action not in ('start','check','stop') then
  raise exception using errcode='22023',message='Tracking action required'; end if;
 if not private.trackable_run(target_run) then return false; end if;
 if action='start' then
  -- Explicit visible-screen start takes over this primary's publisher session; an old device cannot overwrite it.
  insert into private.run_tracking(run_id,publisher_key,driver_id,status) values(target_run,publisher,auth.uid(),'starting')
  on conflict(run_id) do update set publisher_key=excluded.publisher_key,driver_id=excluded.driver_id,status='starting',
   latitude=null,longitude=null,accuracy=null,sampled_at=null,received_at=null
  where run_tracking.publisher_key<>excluded.publisher_key;
 elsif action='stop' then
  update private.run_tracking set status='stopped',latitude=null,longitude=null,accuracy=null,sampled_at=null,received_at=null
   where run_id=target_run and publisher_key=publisher;
 else
  return exists(select 1 from private.run_tracking where run_id=target_run and publisher_key=publisher and status<>'stopped');
 end if;
 perform private.signal_tracking();
 return true;
end; $$;

create function public.publish_run_location(target_run uuid,publisher uuid,tracking_status text,
 latitude double precision default null,longitude double precision default null,
 accuracy double precision default null,sampled_at timestamptz default null) returns boolean
language plpgsql security definer set search_path='' as $$
declare previous private.run_tracking;
begin
 if not public.tracking_control(target_run,publisher,'check') then return false; end if;
 select * into previous from private.run_tracking where run_id=target_run for update;
 if previous.publisher_key is distinct from publisher then return false; end if;
 if tracking_status is null or tracking_status not in ('live','permission_denied','gps_disabled') then
  raise exception using errcode='22023',message='Tracking status invalid'; end if;
 if tracking_status='live' then
  if latitude is null or not(latitude between -90 and 90) or longitude is null or not(longitude between -180 and 180)
   or accuracy is null or not(accuracy>=0 and accuracy<'Infinity'::float8) or sampled_at is null
   or sampled_at<clock_timestamp()-interval '60 seconds' or sampled_at>clock_timestamp()+interval '15 seconds' then
   raise exception using errcode='22023',message='Fresh finite location required'; end if;
  -- Never let a delayed request move the marker backwards in observation time.
  if previous.sampled_at is not null and sampled_at<=previous.sampled_at then return true; end if;
  update private.run_tracking t set latitude=publish_run_location.latitude,longitude=publish_run_location.longitude,
   accuracy=publish_run_location.accuracy,sampled_at=publish_run_location.sampled_at,received_at=clock_timestamp(),status='live'
   where t.run_id=target_run;
 else
  update private.run_tracking set status=tracking_status,latitude=null,longitude=null,accuracy=null,sampled_at=null,received_at=null where run_id=target_run;
 end if;
 perform private.signal_tracking();
 return true;
end; $$;
revoke all on function private.trackable_run(uuid),private.can_track_run(uuid),private.tracking_cleanup_signal(),private.signal_tracking() from public,anon,authenticated;
revoke all on function public.tracking_workspace(),public.tracking_control(uuid,uuid,text),
 public.publish_run_location(uuid,uuid,text,double precision,double precision,double precision,timestamptz) from public,anon;
grant execute on function public.tracking_workspace(),public.tracking_control(uuid,uuid,text),
 public.publish_run_location(uuid,uuid,text,double precision,double precision,double precision,timestamptz) to authenticated;
commit;
