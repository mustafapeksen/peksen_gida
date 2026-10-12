"""Opt-in local physical GPS fixture; preserves Auth sessions and never resets DB.

Uses the named local Docker DB and existing authenticated RPCs. No credential
access, direct business-table writes, departure, or synthetic GPS injection.
Leaves seed Customer A's order loaded for the physical Driver to depart.
"""
import json
import subprocess


COMMAND = [
    'docker', 'exec', '-i', 'supabase_db_peksen_gida_phase3_local',
    'psql', '-X', '-qAt', '-v', 'ON_ERROR_STOP=1', '-U', 'postgres', '-d', 'postgres',
]

SQL = r"""
begin;
select pg_advisory_xact_lock(73012,12);
do $guard$
begin
 if (select count(*) from public.profiles where active and
   (id='30000000-0000-4000-8000-000000000005' and email='driver@peksen.invalid' and role='driver'
    or id='30000000-0000-4000-8000-000000000006' and email='manager@peksen.invalid' and role='manager'
    or id='30000000-0000-4000-8000-000000000003' and email='warehouse@peksen.invalid' and role='warehouse'))<>3 then
  raise exception 'Expected local synthetic profiles missing';
 end if;
 if not exists(select 1 from public.orders where id='35000000-0000-4000-8000-000000000001'
   and customer_id='31000000-0000-4000-8000-000000000001' and status in ('picking','picked','loaded','out_for_delivery')) then
  raise exception 'Expected local Customer A acceptance order missing or incompatible';
 end if;
end $guard$;

-- Resolve synthetic fixture identifiers before switching to Warehouse. Its
-- raw order_items read is intentionally closed (price-bearing table).
select count(*)=1 as one_item from public.order_items
 where order_id='35000000-0000-4000-8000-000000000001' \gset
\if :one_item
 select id as item_id,quantity-picked_qty as remaining,quantity>picked_qty as needs_pick
 from public.order_items where order_id='35000000-0000-4000-8000-000000000001' \gset
\else
 do $unexpected$ begin raise exception 'Expected single synthetic seed item'; end $unexpected$;
\endif
-- Role simulation is explicit: local fixture setup, not an Auth login test.
\if :needs_pick
 set local request.jwt.claim.sub='30000000-0000-4000-8000-000000000003';
 set local role authenticated;
 select public.warehouse_order_action('35000000-0000-4000-8000-000000000001',
   'pick', :'item_id', :remaining,gen_random_uuid()) as picked \gset
 reset role;
\endif

select exists(select 1 from public.delivery_stops where order_id='35000000-0000-4000-8000-000000000001'
 and closed_at is null) as has_stop \gset
\if :has_stop
 do $existing$ begin
  if not exists(select 1 from public.delivery_stops s join public.delivery_runs r on r.id=s.run_id
    where s.order_id='35000000-0000-4000-8000-000000000001' and s.closed_at is null
    and r.primary_driver_id='30000000-0000-4000-8000-000000000005' and r.ended_at is null and r.dispatch_managed) then
   raise exception 'Existing assignment is not this Driver acceptance run';
  end if;
 end $existing$;
\else
 select id as vehicle_id from public.vehicles where plate='TEST-ARAC-01' and active \gset
 set local request.jwt.claim.sub='30000000-0000-4000-8000-000000000006';
 set local role authenticated;
 select public.dispatch_action('create_run',jsonb_build_object('vehicle_id', :'vehicle_id',
   'primary_id','30000000-0000-4000-8000-000000000005'),gen_random_uuid())->>'id' as run_id \gset
 select public.dispatch_action('assign',jsonb_build_object('run_id', :'run_id',
   'order_id','35000000-0000-4000-8000-000000000001'),gen_random_uuid()) as assigned \gset
 reset role;
\endif
select status='picked' as needs_load from public.orders
 where id='35000000-0000-4000-8000-000000000001' \gset
\if :needs_load
 set local request.jwt.claim.sub='30000000-0000-4000-8000-000000000003';
 set local role authenticated;
 select public.warehouse_order_action('35000000-0000-4000-8000-000000000001',
  'load',null,null,gen_random_uuid()) as loaded \gset
 reset role;
\endif
select jsonb_build_object('run_id',r.id,'run_status',r.status,'order_status',o.status,
 'primary',p.email,'picked_qty',i.picked_qty,'quantity',i.quantity)
from public.delivery_stops s join public.delivery_runs r on r.id=s.run_id
join public.profiles p on p.id=r.primary_driver_id join public.orders o on o.id=s.order_id
join public.order_items i on i.order_id=o.id
where o.id='35000000-0000-4000-8000-000000000001' and s.closed_at is null;
commit;
"""


if __name__ == '__main__':
    result = subprocess.run(COMMAND, input=SQL, text=True, capture_output=True, timeout=60)
    if result.returncode:
        raise SystemExit('Local fixture failed; transaction rolled back. ' + result.stderr)
    for line in result.stdout.splitlines():
        if line.startswith('{'):
            print(json.dumps(json.loads(line)))
    print('PASS: local fixture ready; use physical Driver Yola cik. No Auth changes.')
