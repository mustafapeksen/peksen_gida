-- Phase 4 authorization tests run as actual database roles and JWT subjects.
-- Fixtures are transaction-local; the Phase 3 seed remains unchanged.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select no_plan();

insert into auth.users(id,aud,role,email,raw_app_meta_data,raw_user_meta_data)
values
 ('50000000-0000-4000-8000-000000000009','authenticated','authenticated','sales.second@peksen.invalid','{}','{}'),
 ('50000000-0000-4000-8000-000000000010','authenticated','authenticated','assistant@peksen.invalid','{}','{}'),
 ('50000000-0000-4000-8000-000000000011','authenticated','authenticated','outside.driver@peksen.invalid','{}','{}'),
 ('50000000-0000-4000-8000-000000000012','authenticated','authenticated','new.employee@peksen.invalid','{}','{}');
insert into profiles(id,role,name) values
 ('50000000-0000-4000-8000-000000000009','sales_operator','Second sales'),
 ('50000000-0000-4000-8000-000000000010','driver','Assistant'),
 ('50000000-0000-4000-8000-000000000011','driver','Outside driver');
update customers set assigned_sales_operator_id='30000000-0000-4000-8000-000000000002'
 where id='31000000-0000-4000-8000-000000000001';
insert into vehicles(id,plate) values ('51000000-0000-4000-8000-000000000001','AUTH-TEST-VEHICLE');
insert into delivery_runs(id,vehicle_id,primary_driver_id,assistant_driver_id,status)
 values('51000000-0000-4000-8000-000000000002','51000000-0000-4000-8000-000000000001',
 '30000000-0000-4000-8000-000000000005','50000000-0000-4000-8000-000000000010','assigned');
insert into delivery_stops(run_id,order_id,sequence,status,assigned_by)
 values('51000000-0000-4000-8000-000000000002','35000000-0000-4000-8000-000000000001',1,'assigned',
 '30000000-0000-4000-8000-000000000006');

select ok(not exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
 where n.nspname='private' and (not p.prosecdef or not (p.proconfig @> array['search_path=""']))),
 'Private helpers use SECURITY DEFINER with fixed empty search path');
set local role anon;
select throws_ok($$select * from customers$$,'42501',null::text,'Anon cannot read customers');
select throws_ok($$select private.current_app_role()$$,'42501',null::text,'Anon cannot execute helpers');
select throws_ok($$select public.create_customer_record('Forbidden')$$,'42501',null::text,'Anon cannot execute mutations');
reset role;
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000001',true);
set local role authenticated;
select is(private.current_app_role()::text,'customer','customer: role comes from active DB profile');
select ok(exists(select 1 from profiles where id=auth.uid()),'customer: own profile is readable');
select is((select count(*) from employee_salary_records),0::bigint,'customer: salary is Owner only');
select throws_ok($$update profiles set role='owner' where id=auth.uid()$$,'42501',null::text,'customer: direct role mutation denied');
select throws_ok($$update orders set status='delivered'$$,'42501',null::text,'customer: direct workflow mutation denied');
reset role;
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000002',true);
set local role authenticated;
select is(private.current_app_role()::text,'sales_operator','sales_operator: role comes from active DB profile');
select ok(exists(select 1 from profiles where id=auth.uid()),'sales_operator: own profile is readable');
select is((select count(*) from employee_salary_records),0::bigint,'sales_operator: salary is Owner only');
select throws_ok($$update profiles set role='owner' where id=auth.uid()$$,'42501',null::text,'sales_operator: direct role mutation denied');
select throws_ok($$update orders set status='delivered'$$,'42501',null::text,'sales_operator: direct workflow mutation denied');
reset role;
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000003',true);
set local role authenticated;
select is(private.current_app_role()::text,'warehouse','warehouse: role comes from active DB profile');
select ok(exists(select 1 from profiles where id=auth.uid()),'warehouse: own profile is readable');
select is((select count(*) from employee_salary_records),0::bigint,'warehouse: salary is Owner only');
select throws_ok($$update profiles set role='owner' where id=auth.uid()$$,'42501',null::text,'warehouse: direct role mutation denied');
select throws_ok($$update orders set status='delivered'$$,'42501',null::text,'warehouse: direct workflow mutation denied');
reset role;
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000004',true);
set local role authenticated;
select is(private.current_app_role()::text,'accounting','accounting: role comes from active DB profile');
select ok(exists(select 1 from profiles where id=auth.uid()),'accounting: own profile is readable');
select is((select count(*) from employee_salary_records),0::bigint,'accounting: salary is Owner only');
select throws_ok($$update profiles set role='owner' where id=auth.uid()$$,'42501',null::text,'accounting: direct role mutation denied');
select throws_ok($$update orders set status='delivered'$$,'42501',null::text,'accounting: direct workflow mutation denied');
reset role;
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000005',true);
set local role authenticated;
select is(private.current_app_role()::text,'driver','driver: role comes from active DB profile');
select ok(exists(select 1 from profiles where id=auth.uid()),'driver: own profile is readable');
select is((select count(*) from employee_salary_records),0::bigint,'driver: salary is Owner only');
select throws_ok($$update profiles set role='owner' where id=auth.uid()$$,'42501',null::text,'driver: direct role mutation denied');
select throws_ok($$update orders set status='delivered'$$,'42501',null::text,'driver: direct workflow mutation denied');
reset role;
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000006',true);
set local role authenticated;
select is(private.current_app_role()::text,'manager','manager: role comes from active DB profile');
select ok(exists(select 1 from profiles where id=auth.uid()),'manager: own profile is readable');
select is((select count(*) from employee_salary_records),0::bigint,'manager: salary is Owner only');
select throws_ok($$update profiles set role='owner' where id=auth.uid()$$,'42501',null::text,'manager: direct role mutation denied');
select throws_ok($$update orders set status='delivered'$$,'42501',null::text,'manager: direct workflow mutation denied');
reset role;
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000007',true);
set local role authenticated;
select is(private.current_app_role()::text,'owner','owner: role comes from active DB profile');
select ok(exists(select 1 from profiles where id=auth.uid()),'owner: own profile is readable');
select is((select count(*) from employee_salary_records),1::bigint,'owner: salary is Owner only');
select throws_ok($$update profiles set role='owner' where id=auth.uid()$$,'42501',null::text,'owner: direct role mutation denied');
select throws_ok($$update orders set status='delivered'$$,'42501',null::text,'owner: direct workflow mutation denied');
reset role;
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000001',true);
set local role authenticated;
select is((select count(*) from customers),1::bigint,'Customer sees exactly own organization');
select is((select count(*) from customer_users),1::bigint,'Customer sees exactly own membership');
select is((select count(*) from orders),2::bigint,'Customer sees own two orders');
select is((select count(*) from order_items),1::bigint,'Customer cannot join to another order item');
select is((select count(*) from customers where id='31000000-0000-4000-8000-000000000002'),0::bigint,'Explicit other customer id is hidden');
select is((select count(*) from payments),0::bigint,'Other customer payments hidden');
select is((select count(*) from notifications),0::bigint,'Other user inbox hidden');
select is((select count(*) from driver_locations),0::bigint,'Customer raw GPS history remains closed');
select throws_ok($$select assign_account_role(auth.uid(),'owner','Escalate')$$,'42501',null::text,'Customer cannot delegate role');
select throws_ok($$select assign_customer_sales('31000000-0000-4000-8000-000000000002',auth.uid())$$,'42501',null::text,'Customer cannot self-assign');
select throws_ok($$select update_customer_contact('31000000-0000-4000-8000-000000000002','Stolen',null,null,null,null)$$,'42501',null::text,'Customer cannot modify another customer');
select set_config('request.jwt.claims','{"user_metadata":{"role":"owner"}}',true);
select is(private.current_app_role()::text,'customer','Forged metadata does not grant Owner');
reset role;
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000008',true);
set local role authenticated;
select is((select count(*) from payments),1::bigint,'Customer B sees own payment');
select is((select count(*) from customer_pricing),0::bigint,'Customer B cannot read customer A pricing');
reset role;
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000002',true);
set local role authenticated;
select is((select count(*) from customers),1::bigint,'Sales sees assigned customer only');
select is((select count(*) from orders),2::bigint,'Sales sees assigned customer orders only');
select throws_ok($$select update_customer_contact('31000000-0000-4000-8000-000000000002','Denied',null,null,null,null)$$,'42501',null::text,'Sales cannot manage unassigned customer');
select throws_ok($$select assign_customer_sales('31000000-0000-4000-8000-000000000002',auth.uid())$$,'42501',null::text,'Sales cannot claim unassigned customer');
select lives_ok($$select update_customer_contact('31000000-0000-4000-8000-000000000001','Assigned test',null,null,null,null)$$,'Sales manages assigned contact details');
select lives_ok($$select create_customer_record('Sales created fixture')$$,'Sales can create customer with server provenance');
select is((select count(*) from customers),2::bigint,'Sales also sees its own created customer');
select throws_ok($$update customers set credit_limit_kurus=999999$$,'42501',null::text,'Sales cannot change credit fields directly');
reset role;
select set_config('request.jwt.claim.sub','50000000-0000-4000-8000-000000000009',true);
set local role authenticated;
select is((select count(*) from customers),0::bigint,'Other sales cannot see assigned or created customer');
select is((select count(*) from orders),0::bigint,'Other sales cannot read order by guessed id');
reset role;
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000004',true);
set local role authenticated;
select is((select count(*) from customers),0::bigint,'Accounting cannot read full customer records');
select is((select count(*) from accounting_customers()),1::bigint,'Accounting sees assigned customers only; Sales creator alone is insufficient (F4-04)');
select ok(not exists(select 1 from accounting_customers() where id='31000000-0000-4000-8000-000000000002'),'Unassigned finance exception stays closed');
select throws_ok($$select create_customer_record('Denied')$$,'42501',null::text,'Accounting cannot create customer');
select throws_ok($$select update_customer_contact('31000000-0000-4000-8000-000000000001','Denied',null,null,null,null)$$,'42501',null::text,'Accounting cannot manage customer');
reset role;
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000006',true);
set local role authenticated;
select is((select count(*) from customers),3::bigint,'Manager sees all assigned/unassigned customers');
select is((select count(*) from audit_logs),0::bigint,'Manager cannot read Owner audit log');
select lives_ok($$select assign_customer_sales('31000000-0000-4000-8000-000000000001','50000000-0000-4000-8000-000000000009')$$,'Manager can reassign customer');
select lives_ok($$select assign_account_role('50000000-0000-4000-8000-000000000012','driver','New employee')$$,'Manager can provision operational profile on existing Auth identity');
select throws_ok($$select assign_account_role('50000000-0000-4000-8000-000000000012','owner','Denied')$$,'42501',null::text,'Manager cannot assign owner');
select throws_ok($$select assign_account_role('50000000-0000-4000-8000-000000000012','manager','Denied')$$,'42501',null::text,'Manager cannot assign manager');
select throws_ok($$select assign_account_role('50000000-0000-4000-8000-000000000012','accounting','Denied')$$,'42501',null::text,'Manager cannot assign accounting');
select throws_ok($$select assign_account_role('30000000-0000-4000-8000-000000000004','driver','Takeover')$$,'42501',null::text,'Manager cannot demote privileged account 4');
select throws_ok($$select assign_account_role('30000000-0000-4000-8000-000000000006','driver','Takeover')$$,'42501',null::text,'Manager cannot demote privileged account 6');
select throws_ok($$select assign_account_role('30000000-0000-4000-8000-000000000007','driver','Takeover')$$,'42501',null::text,'Manager cannot demote privileged account 7');
select throws_ok($$select assign_customer_sales('31000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000004')$$,'22023',null::text,'Assignment requires a Sales Operator');
reset role;
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000002',true);
set local role authenticated;
select is((select count(*) from customers),1::bigint,'Reassigned customer removed; created customer remains');
select is((select count(*) from orders),0::bigint,'Reassignment revokes previous Sales order access immediately');
reset role;
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000007',true);
set local role authenticated;
select lives_ok($$select assign_account_role('50000000-0000-4000-8000-000000000012','accounting','Accountant')$$,'Owner can assign Accounting');
select lives_ok($$select assign_account_role('50000000-0000-4000-8000-000000000012','manager','Manager')$$,'Owner can assign Manager');
select lives_ok($$select assign_account_role('50000000-0000-4000-8000-000000000012','owner','Owner')$$,'Owner can assign Owner');
select ok(exists(select 1 from audit_logs where action='role_changed' and entity_id='50000000-0000-4000-8000-000000000012'),'Role changes leave audit evidence');
select ok(exists(select 1 from audit_logs where action='permission_changed' and entity_id='31000000-0000-4000-8000-000000000001'),'Assignment change leaves audit evidence');
reset role;
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000005',true);
set local role authenticated;
select is((select count(*) from orders),1::bigint,'Primary driver sees only active assigned order');
select is((select count(*) from delivery_runs where id='51000000-0000-4000-8000-000000000002'),1::bigint,'Primary driver run scope');
select is((select count(*) from vehicles where id='51000000-0000-4000-8000-000000000001'),1::bigint,'Primary driver vehicle scope');
select is((select count(*) from customers),0::bigint,'Primary driver cannot list customer records');
reset role;
select set_config('request.jwt.claim.sub','50000000-0000-4000-8000-000000000010',true);
set local role authenticated;
select is((select count(*) from orders),1::bigint,'Assistant driver sees only active assigned order');
select is((select count(*) from delivery_runs where id='51000000-0000-4000-8000-000000000002'),1::bigint,'Assistant driver run scope');
select is((select count(*) from vehicles where id='51000000-0000-4000-8000-000000000001'),1::bigint,'Assistant driver vehicle scope');
select is((select count(*) from customers),0::bigint,'Assistant driver cannot list customer records');
reset role;
select set_config('request.jwt.claim.sub','50000000-0000-4000-8000-000000000011',true);
set local role authenticated;
select is((select count(*) from orders),0::bigint,'Unassigned driver sees only active assigned order');
select is((select count(*) from delivery_runs where id='51000000-0000-4000-8000-000000000002'),0::bigint,'Unassigned driver run scope');
select is((select count(*) from vehicles where id='51000000-0000-4000-8000-000000000001'),0::bigint,'Unassigned driver vehicle scope');
select is((select count(*) from customers),0::bigint,'Unassigned driver cannot list customer records');
reset role;
update profiles set active=false where id='30000000-0000-4000-8000-000000000007';
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000007',true);
set local role authenticated;
select is(private.current_app_role(),null::public.app_role,'Inactive Owner has no effective role');
select is((select count(*) from employee_salary_records),0::bigint,'Inactive Owner cannot read salary');
select throws_ok($$select assign_account_role('50000000-0000-4000-8000-000000000012','driver','Denied')$$,'42501',null::text,'Inactive Owner cannot delegate');
reset role;
update customer_users set active=false where user_id='30000000-0000-4000-8000-000000000001';
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000001',true);
set local role authenticated;
select is((select count(*) from customers),0::bigint,'Inactive membership cannot read customer');
select is((select count(*) from orders),0::bigint,'Inactive membership cannot read orders');
reset role;
update customer_users set active=true where user_id='30000000-0000-4000-8000-000000000001';
update customers set active=false where id='31000000-0000-4000-8000-000000000001';
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000001',true);
set local role authenticated;
select is((select count(*) from profiles),0::bigint,'Inactive organization denies customer application session profile');
reset role;
-- Additional provisioning and relationship regressions; original seeds survive rollback.
insert into auth.users(id,aud,role,email) values
 ('50000000-0000-4000-8000-000000000013','authenticated','authenticated','new.customer@peksen.invalid'),
 ('50000000-0000-4000-8000-000000000014','authenticated','authenticated','new.operator@peksen.invalid');
insert into customers(id,company_name) values ('52000000-0000-4000-8000-000000000001','New organization');
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000006',true);
set local role authenticated;
select lives_ok($$select assign_account_role('50000000-0000-4000-8000-000000000014','sales_operator','Sales')$$,'Manager can assign Sales Operator');
select lives_ok($$select assign_account_role('50000000-0000-4000-8000-000000000014','warehouse','Warehouse')$$,'Manager can assign Warehouse');
select lives_ok($$select assign_account_role('50000000-0000-4000-8000-000000000014','driver','Driver')$$,'Manager can assign Driver/assistant Driver without adding a role');
select throws_ok($$select link_customer_account('50000000-0000-4000-8000-000000000013','31000000-0000-4000-8000-000000000001','Duplicate')$$,
 '23505',null::text,'Cannot attach a second customer user to an occupied organization');
select ok(not exists(select 1 from profiles where id='50000000-0000-4000-8000-000000000013'),'Failed membership provisioning rolls back profile creation');
select lives_ok($$select link_customer_account('50000000-0000-4000-8000-000000000013','52000000-0000-4000-8000-000000000001','Customer')$$,'Manager provisions customer profile and membership together');
select throws_ok($$select assign_account_role('50000000-0000-4000-8000-000000000013','driver','Convert')$$,'42501',null::text,'Membership conversion does not leave orphaned customer privileges');
reset role;
select set_config('request.jwt.claim.sub','50000000-0000-4000-8000-000000000013',true);
set local role authenticated;
select is(private.current_app_role()::text,'customer','Newly provisioned customer is immediately active');
select is((select count(*) from customers),1::bigint,'New customer only sees linked organization');
select throws_ok($$select link_customer_account(auth.uid(),'31000000-0000-4000-8000-000000000002','Steal')$$,'42501',null::text,'Customer cannot attach itself to another organization');
reset role;
insert into driver_locations(run_id,driver_id,latitude,longitude,recorded_at)
 select id,primary_driver_id,0,0,now() from delivery_runs;
select set_config('request.jwt.claim.sub','50000000-0000-4000-8000-000000000010',true);
set local role authenticated;
select is((select count(*) from driver_locations),1::bigint,'Assistant reads only assigned run GPS records');
select is((select count(*) from vehicles),1::bigint,'Assistant cannot infer unrelated vehicle through an unqualified id');
reset role;
select set_config('request.jwt.claim.sub','50000000-0000-4000-8000-000000000011',true);
set local role authenticated;
select is((select count(*) from driver_locations),0::bigint,'Unassigned driver cannot read GPS');
reset role;
select * from finish();
rollback;
