begin;
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select no_plan();
create function pg_temp.uid(n integer) returns uuid language sql as $$select ('30000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid$$;
create function pg_temp.actor(n integer) returns text language sql as $$select set_config('request.jwt.claim.sub',pg_temp.uid(n)::text,true)$$;
create function pg_temp.report() returns jsonb language sql as $$select management_report('2026-10-01','2026-10-01')$$;
create function pg_temp.save(rev integer, key_number integer, amount bigint default 200) returns jsonb language sql as $$
 select save_salary(pg_temp.uid(2),'2026-11-01',amount,10,'Synthetic salary reason',rev,
 ('15000000-0000-4000-8000-'||lpad(key_number::text,12,'0'))::uuid)$$;
-- UTC instants immediately outside and inside the inclusive Istanbul day.
update orders set created_at=case id
 when '35000000-0000-4000-8000-000000000001' then '2026-09-30 21:00:00+00'::timestamptz
 when '35000000-0000-4000-8000-000000000002' then '2026-10-01 20:59:59+00'::timestamptz
 else '2026-10-01 21:00:00+00'::timestamptz end;
set local role anon;
select throws_ok($$select pg_temp.report()$$,'42501',null::text,'Anon report denied');
select throws_ok($$select owner_salary_workspace('2026-10-01')$$,'42501',null::text,'Anon salary denied');
select throws_ok($$select owner_audit_page()$$,'42501',null::text,'Anon audit denied');
select throws_ok($$select pg_temp.save(-1,1)$$,'42501',null::text,'Anon salary write denied');
set local role authenticated;
select pg_temp.actor(6);
select lives_ok($$select pg_temp.report()$$,'Manager reads report');
select is((select sum((x->>'count')::int)::int from jsonb_array_elements(pg_temp.report()->'orders') x),2,'Istanbul day includes both boundaries and excludes next midnight');
select is(pg_temp.report()->'payments'->0->>'total_kurus','5000','Recorded collection total from collected date');
select is(pg_temp.report()->'payments'->0->>'status','recorded','Verification status explicit');
select is((pg_temp.report()->'ratings'->0->>'count')::int,1,'All-time rating count');
select is((pg_temp.report()->'ratings'->0->>'average')::numeric,4::numeric,'Rating mean from records');
select is((pg_temp.report()->'ratings'->0->>'stars_4')::int,1,'Rating distribution');
select is((pg_temp.report()->'inventory'->0->>'available_qty')::numeric,
 (select available_qty::numeric from inventory i join products p on p.id=i.product_id order by p.name,p.id limit 1),'Live stock exact projection');
select ok(not (pg_temp.report() ? 'salary'),'Manager report contains no salary');
select throws_ok($$select management_report('2026-10-02','2026-10-01')$$,'22023',null::text,'Reverse interval rejected');
select throws_ok($$select management_report(null,'2026-10-01')$$,'22023',null::text,'Null interval rejected');
select throws_ok($$select management_report('-infinity','2026-10-01')$$,'22023',null::text,'Infinite interval rejected');
select throws_ok($$select owner_salary_workspace('2026-10-01')$$,'42501',null::text,'Manager salary RPC denied');
select throws_ok($$select owner_audit_page()$$,'42501',null::text,'Manager audit RPC denied');
select throws_ok($$select pg_temp.save(-1,1)$$,'42501',null::text,'Manager salary write denied');
select is((select count(*) from employee_salary_records),0::bigint,'Manager salary RLS denied');
select is((select count(*) from audit_logs),0::bigint,'Manager audit RLS denied');
select pg_temp.actor(7);
select lives_ok($$select pg_temp.report()$$,'Owner reads report');
select is(jsonb_array_length(owner_salary_workspace('2026-10-01')->'records'),1,'Legacy salary preserved');
select is(jsonb_array_length(owner_salary_workspace('2026-10-01')->'history'),0,'No invented legacy history');
select throws_ok($$select owner_salary_workspace('2026-10-02')$$,'22023',null::text,'Month start required');
select lives_ok($$select pg_temp.save(-1,1)$$,'Owner creates manual salary');
select is((select salary_kurus from employee_salary_records where period='2026-11-01'),200::bigint,'Exact integer salary persisted');
select is((select bonus_kurus from employee_salary_records where period='2026-11-01'),10::bigint,'Manual bonus persisted');
select is(pg_temp.save(-1,1),jsonb_build_object('id',(select id from employee_salary_records where period='2026-11-01'),'revision',0),'Same request response replays');
select throws_ok($$select pg_temp.save(-1,1,300)$$,'22023',null::text,'Same key changed payload denied');
select throws_ok($$select pg_temp.save(-1,2)$$,'40001',null::text,'Concurrent create stale revision denied');
select lives_ok($$select pg_temp.save(0,2,300)$$,'Owner corrects with current revision');
select throws_ok($$select pg_temp.save(0,3,400)$$,'40001',null::text,'Stale correction cannot overwrite newer record');
select is((select revision from employee_salary_records where period='2026-11-01'),1,'Revision advanced once');
select is(jsonb_array_length(owner_salary_workspace('2026-11-01')->'history'),2,'Create and correction history retained');
select is((select count(*) from audit_logs where action='salary_changed'),2::bigint,'Replay creates no second audit');
select ok(not exists(select 1 from jsonb_array_elements(owner_audit_page()) x where x ? 'new_data' or x ? 'old_data' or x ? 'reason'),'Audit projection excludes raw payload');
select throws_ok($$select owner_audit_page(now(),null)$$,'22023',null::text,'Partial cursor denied');
select throws_ok($$select save_salary(pg_temp.uid(1),'2026-11-01',1,0,'x',-1,gen_random_uuid())$$,'22023',null::text,'Customer is not employee');
select throws_ok($$select save_salary(pg_temp.uid(2),'2026-11-02',1,0,'x',-1,gen_random_uuid())$$,'22023',null::text,'Non-month date denied');
select throws_ok($$select save_salary(pg_temp.uid(2),'2026-12-01',-1,0,'x',-1,gen_random_uuid())$$,'22023',null::text,'Negative salary denied');
select throws_ok($$select save_salary(pg_temp.uid(2),'2026-12-01',1,-1,'x',-1,gen_random_uuid())$$,'22023',null::text,'Negative bonus denied');
select throws_ok($$select save_salary(pg_temp.uid(2),'2026-12-01',1,0,'  ',-1,gen_random_uuid())$$,'22023',null::text,'Blank reason denied');
select throws_ok($$select save_salary(pg_temp.uid(2),'2026-12-01',1,0,'x',-1,null)$$,'22023',null::text,'Missing key denied');
select throws_ok($$update employee_salary_records set salary_kurus=999$$,'42501',null::text,'Even Owner raw write denied');
select throws_ok($$delete from employee_salary_records$$,'42501',null::text,'Raw delete denied');
select throws_ok($$select * from private.salary_changes$$,'42501',null::text,'Private history has no raw client grant');
-- All lower roles fail even when guessing deep-link/RPC names.
reset role;
create function pg_temp.denied_roles() returns setof text language plpgsql as $$
declare n integer;
begin
 for n in 1..5 loop
  perform pg_temp.actor(n);
  return next throws_ok('select pg_temp.report()','42501',null::text,'Lower role report denied '||n);
  return next throws_ok($q$select owner_salary_workspace('2026-11-01')$q$,'42501',null::text,'Lower role salary denied '||n);
  return next throws_ok('select owner_audit_page()','42501',null::text,'Lower role audit denied '||n);
  return next throws_ok('select pg_temp.save(1,3)','42501',null::text,'Lower role write denied '||n);
  return next is((select count(*) from employee_salary_records),0::bigint,'Lower role salary RLS '||n);
 end loop;
end; $$;
set local role authenticated;
select * from pg_temp.denied_roles();
reset role;
insert into auth.users(id,email) values(pg_temp.uid(15),'phase15-owner@example.invalid');
insert into profiles(id,role,name) values(pg_temp.uid(15),'owner','Second synthetic Owner');
update profiles set active=false where id=pg_temp.uid(7);
select pg_temp.actor(7);
set local role authenticated;
select throws_ok($$select pg_temp.report()$$,'42501',null::text,'Inactive Owner report denied');
select throws_ok($$select pg_temp.save(-1,1)$$,'42501',null::text,'Inactive Owner cannot replay previous write');
reset role;
update profiles set active=true where id=pg_temp.uid(7);
-- Audit failure must roll back record, history and receipt.
create function pg_temp.fail_audit() returns trigger language plpgsql as $$begin raise exception 'synthetic audit failure'; end;$$;
create trigger phase15_audit_failure before insert on audit_logs for each row execute function pg_temp.fail_audit();
set local role authenticated;
select throws_ok($$select pg_temp.save(1,3,400)$$,'P0001','synthetic audit failure','Audit failure rejects transaction');
reset role;
drop trigger phase15_audit_failure on audit_logs;
select is((select salary_kurus from employee_salary_records where period='2026-11-01'),300::bigint,'Audit rollback preserves salary');
select is((select count(*) from private.salary_changes),2::bigint,'Audit rollback preserves history');
select is((select count(*) from private.salary_receipts),2::bigint,'Audit rollback leaves no receipt');
select throws_ok($$update private.salary_changes set reason='x'$$,'23514',null::text,'History immutable');
select throws_ok($$delete from private.salary_changes$$,'23514',null::text,'History cannot be deleted');
select throws_ok($$insert into employee_salary_records(employee_id,period,salary_kurus,bonus_kurus,created_by) values(pg_temp.uid(2),'2026-11-01',1,0,pg_temp.uid(7))$$,'23505',null::text,'Employee month unique constraint');
select is((management_report((now() at time zone 'Europe/Istanbul')::date,(now() at time zone 'Europe/Istanbul')::date)->'deliveries'->>'count')::int,1,'Existing finalization fact counted once');
select is((management_report((now() at time zone 'Europe/Istanbul')::date,(now() at time zone 'Europe/Istanbul')::date)->'deliveries'->>'total_kurus'),'20000','Delivery uses order snapshot total');
select is((select count(*) from payments),1::bigint,'Salary never posts payment');
select is((select count(*) from app_settings),0::bigint,'No invented settings');
insert into payments(order_id,payment_amount_kurus,method,collector_user_id,collected_at,verified_by,verified_at,verification_status,operation_key) values
 ('35000000-0000-4000-8000-000000000002',1000,'pos',pg_temp.uid(2),'2026-10-01 20:59:59+00',pg_temp.uid(4),now(),'verified',gen_random_uuid()),
 ('35000000-0000-4000-8000-000000000002',700,'cash',pg_temp.uid(2),'2026-10-01 21:00:00+00',null,null,'recorded',gen_random_uuid()),
 ('35000000-0000-4000-8000-000000000002',200,'cash',pg_temp.uid(2),'2026-10-01 12:00:00+00',null,null,'cancelled',gen_random_uuid());
select is(jsonb_array_length(pg_temp.report()->'payments'),2,'Recorded and verified are separate groups');
select is((select x->>'total_kurus' from jsonb_array_elements(pg_temp.report()->'payments') x where x->>'status'='verified'),'1000','Verified uses collected day, not verification day');
select is((select x->>'total_kurus' from jsonb_array_elements(pg_temp.report()->'payments') x where x->>'status'='recorded'),'5000','Next day and cancelled payments excluded');
select is(jsonb_array_length(management_report('2001-01-01','2001-01-01')->'orders'),0,'Empty interval order list');
select is(management_report('2001-01-01','2001-01-01')->'deliveries'->>'total_kurus','0','Empty delivery sum is zero');
select is(management_report('2001-01-01','2001-01-01')->'inventory',pg_temp.report()->'inventory','Stock is independent of date interval');
select is(management_report('2001-01-01','2001-01-01')->'ratings',pg_temp.report()->'ratings','Ratings remain all-time');
insert into audit_logs(actor_id,action,entity_type,entity_id,old_data,new_data)
 select pg_temp.uid(7),'role_changed','synthetic',gen_random_uuid(),'{"private":"old"}','{"private":"new"}' from generate_series(1,55);
select is(jsonb_array_length(owner_audit_page()),50,'Audit page bounded');
select ok(jsonb_array_length(owner_audit_page((owner_audit_page()->49->>'created_at')::timestamptz,(owner_audit_page()->49->>'id')::uuid))>0,'Audit cursor exposes older page');
select ok(not exists(select 1 from jsonb_array_elements(owner_audit_page()) a join jsonb_array_elements(owner_audit_page((owner_audit_page()->49->>'created_at')::timestamptz,(owner_audit_page()->49->>'id')::uuid)) b on a->>'id'=b->>'id'),'Audit tie-time cursor does not repeat rows');
select * from finish();
rollback;
