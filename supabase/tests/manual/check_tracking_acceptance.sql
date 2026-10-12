-- Local physical acceptance only, after Driver publishes a real point.
-- No coordinates, credentials or publisher keys in output. All reads rolled back.
\set ON_ERROR_STOP on
begin;
set local role authenticated;
set local request.jwt.claim.sub='30000000-0000-4000-8000-000000000006';
do $manager$
begin
 if not exists(select 1 from jsonb_array_elements(public.tracking_workspace()) e
   where e->>'plate'='TEST-ARAC-01' and e->>'status'='live'
   and e->>'latitude' is not null and e->>'longitude' is not null
   and (e->>'stale')::boolean=false and (e->>'can_publish')::boolean=false) then
  raise exception 'Manager cannot read current physical point';
 end if;
end $manager$;
select 'PASS Manager reads fresh point without publish permission';
set local request.jwt.claim.sub='30000000-0000-4000-8000-000000000001';
do $customer_a$
begin
 if not exists(select 1 from jsonb_array_elements(public.tracking_workspace()) e
   where e->>'plate'='TEST-ARAC-01' and e->>'latitude' is not null
   and (e->>'can_publish')::boolean=false) then
  raise exception 'Customer A cannot read own active delivery';
 end if;
end $customer_a$;
select 'PASS Customer A reads own active delivery without publish permission';
set local request.jwt.claim.sub='30000000-0000-4000-8000-000000000008';
do $customer_b$
begin
 if public.tracking_workspace()<>'[]'::jsonb then
  raise exception 'Customer B unexpectedly reads another customer delivery';
 end if;
end $customer_b$;
select 'PASS Customer B cannot read Customer A delivery';
set local request.jwt.claim.sub='30000000-0000-4000-8000-000000000003';
do $warehouse$
begin
 begin
  perform public.tracking_workspace();
  raise exception 'Warehouse unexpectedly reads tracking';
 exception when insufficient_privilege then null;
 end;
end $warehouse$;
select 'PASS Warehouse tracking read denied';
rollback;
