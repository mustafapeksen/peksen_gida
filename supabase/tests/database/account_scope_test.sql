-- F4-04: real anon/authenticated roles; all fixtures roll back.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select no_plan();

update customers set assigned_sales_operator_id='30000000-0000-4000-8000-000000000002',
  contact_name='Finance contact',phone='synthetic',email='contact@peksen.invalid',
  address='Synthetic address',tax_no='TEST-TAX',tax_office='Test office',notes='Never projected'
  where id='31000000-0000-4000-8000-000000000002';
update customers set created_by='30000000-0000-4000-8000-000000000002'
  where id='31000000-0000-4000-8000-000000000001';
insert into payment_adjustments(payment_id,adjustment_amount_kurus,reason,created_by,operation_key)
  select id,-100,'Synthetic correction','30000000-0000-4000-8000-000000000007',gen_random_uuid() from payments;
insert into customers(id,company_name) values
 ('61000000-0000-4000-8000-000000000001','Empty conversion destination'),
 ('61000000-0000-4000-8000-000000000002','Second empty destination');

set local role anon;
select throws_ok($$select * from accounting_customers()$$,'42501',null::text,'Anon cannot call finance projection');
select throws_ok($$select * from warehouse_products()$$,'42501',null::text,'Anon cannot call warehouse projection');
select throws_ok($$select convert_account_role('30000000-0000-4000-8000-000000000001','driver')$$,
  '42501',null::text,'Anon cannot convert an account');
reset role;

select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000004',true);
set local role authenticated;
select is((select count(*) from accounting_customers()),1::bigint,'Accounting sees only explicitly assigned customer');
select is((select tax_no from accounting_customers()),'TEST-TAX','Accounting gets approved tax information');
select is((select contact_name from accounting_customers()),'Finance contact','Accounting gets approved contact information');
select results_eq($$select jsonb_object_keys(to_jsonb(c)) from accounting_customers() c order by 1$$,
 $$values ('address'),('company_name'),('contact_name'),('credit_limit_kurus'),('email'),('id'),('payment_due_days'),('phone'),('tax_no'),('tax_office')$$,
 'Accounting customer projection has an exact field allowlist');
select is((select count(*) from customers),0::bigint,'Accounting raw customer rows remain closed');
select is((select count(*) from orders),0::bigint,'Accounting raw order rows remain closed');
select is((select count(*) from payments),0::bigint,'Accounting raw payments and notes remain closed');
select is((select count(*) from accounting_payments()),1::bigint,'Accounting reads assigned customer collection');
select is((select payment_amount_kurus from accounting_payments()),5000::bigint,'Collection amount is preserved without recalculation');
select is((select count(*) from accounting_payment_adjustments()),1::bigint,'Assigned customer collection corrections visible');
select results_eq($$select jsonb_object_keys(to_jsonb(p)) from accounting_payments() p order by 1$$,
 $$values ('collected_at'),('collector_user_id'),('customer_id'),('id'),('method'),('order_id'),('payment_amount_kurus'),('verification_status'),('verified_at'),('verified_by')$$,
 'Collection projection does not expose operation keys or free-form notes');
select is((select count(*) from audit_logs),0::bigint,'Accounting audit closed');
select is((select count(*) from employee_salary_records),0::bigint,'Accounting salary closed');
select throws_ok($$update payments set verification_status='verified'$$,'42501',null::text,'Accounting writes stay closed');
select throws_ok($$select update_customer_contact('31000000-0000-4000-8000-000000000002','Denied',null,null,null,null)$$,
 '42501',null::text,'Accounting cannot manage even assigned customer');
select is((select count(*) from warehouse_products()),0::bigint,'Accounting cannot use Warehouse projection');
reset role;
update customers set assigned_sales_operator_id=null where id='31000000-0000-4000-8000-000000000002';
set local role authenticated;
select is((select count(*) from accounting_customers()),0::bigint,'Removing assignment hides customer immediately');
select is((select count(*) from accounting_payments()),0::bigint,'Removing assignment hides collections immediately');
select is((select count(*) from accounting_payment_adjustments()),0::bigint,'Removing assignment hides corrections immediately');
reset role;
update customers set assigned_sales_operator_id='30000000-0000-4000-8000-000000000002'
  where id='31000000-0000-4000-8000-000000000002';
update profiles set active=false where id='30000000-0000-4000-8000-000000000004';
set local role authenticated;
select is((select count(*) from accounting_customers()),0::bigint,'Inactive Accounting sees no customer data');
select is((select count(*) from accounting_payments()),0::bigint,'Inactive Accounting sees no collection data');
reset role;
update profiles set active=true where id='30000000-0000-4000-8000-000000000004';

select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000003',true);
set local role authenticated;
select is((select count(*) from warehouse_products()),2::bigint,'Warehouse reads products without prices');
select results_eq($$select jsonb_object_keys(to_jsonb(p)) from warehouse_products() p group by 1 order by 1$$,
 $$values ('active'),('base_unit'),('id'),('name'),('package_label'),('sku')$$,'Product projection exact safe fields');
select is((select count(*) from products),0::bigint,'Warehouse cannot read raw priced products');
select is((select count(*) from product_units),3::bigint,'Warehouse reads units');
select is((select count(*) from inventory),2::bigint,'Warehouse reads inventory');
select is((select count(*) from warehouse_movements()),5::bigint,'Warehouse reads stock movements');
select is((select count(*) from warehouse_stock_counts()),1::bigint,'Warehouse reads stock counts');
select is((select count(*) from stock_count_items),1::bigint,'Warehouse reads counted quantities');
select is((select count(*) from warehouse_preparation_items()),1::bigint,'Only picking seed order is visible');
select is((select picked_qty from warehouse_preparation_items()),1,'Picked quantity is projected unchanged');
select results_eq($$select jsonb_object_keys(to_jsonb(i)) from warehouse_preparation_items() i order by 1$$,
 $$values ('conversion_to_base_snapshot'),('item_id'),('order_id'),('picked_qty'),('product_id'),('product_unit_id'),('quantity'),('status'),('unit')$$,
 'Preparation has no customer, price, discount or financial fields');
select is((select count(*) from orders),0::bigint,'Warehouse raw order rows closed');
select is((select count(*) from order_items),0::bigint,'Warehouse raw priced item rows closed');
select is((select count(*) from customers),0::bigint,'Warehouse customer contact/tax closed');
select is((select count(*) from payments),0::bigint,'Warehouse payments closed');
select is((select count(*) from employee_salary_records),0::bigint,'Warehouse salary closed');
select is((select count(*) from accounting_customers()),0::bigint,'Warehouse cannot bypass through finance RPC');
select throws_ok($$update inventory set physical_qty=999$$,'42501',null::text,'Warehouse inventory writes remain closed');
reset role;
-- Exercise every allowed state and all disallowed domain states on the same item.
create function pg_temp.preparation_states() returns setof text language plpgsql as $$
declare state_name text; actual bigint;
begin
  foreach state_name in array array['draft','pending_approval','submitted','picking','picked','assigned','loaded',
    'out_for_delivery','delivery_pending_confirmation','delivered','delivery_disputed','cancelled','rejected'] loop
    update public.orders set status=state_name where id='35000000-0000-4000-8000-000000000001';
    set local role authenticated;
    select count(*) into actual from public.warehouse_preparation_items();
    reset role;
    return next extensions.is(actual,case when state_name in ('submitted','picking','picked') then 1 else 0 end::bigint,
      'Warehouse preparation state boundary: ' || state_name);
  end loop;
end;
$$;
select * from pg_temp.preparation_states();
update profiles set active=false where id='30000000-0000-4000-8000-000000000003';
set local role authenticated;
select is((select count(*) from warehouse_products()),0::bigint,'Inactive Warehouse projection closed');
select is((select count(*) from inventory),0::bigint,'Inactive Warehouse RLS closed');
reset role;
update profiles set active=true where id='30000000-0000-4000-8000-000000000003';

-- Preserve full financial/order/membership history across both conversions.
create temporary table history_before as select
 (select jsonb_agg(to_jsonb(o) order by id) from orders o) orders,
 (select jsonb_agg(to_jsonb(p) order by id) from payments p) payments,
 (select jsonb_agg(to_jsonb(c) order by id) from customers c) customers;
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000006',true);
set local role authenticated;
select throws_ok($$select convert_account_role('30000000-0000-4000-8000-000000000008','driver')$$,
 '42501',null::text,'Manager cannot convert customer to employee');
select throws_ok($$select convert_account_role('30000000-0000-4000-8000-000000000005','customer','61000000-0000-4000-8000-000000000001')$$,
 '42501',null::text,'Manager cannot convert employee to customer');
reset role;
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000008',true);
set local role authenticated;
select throws_ok($$select convert_account_role(auth.uid(),'owner')$$,'42501',null::text,'Customer cannot self-escalate through conversion');
reset role;
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000007',true);
set local role authenticated;
select throws_ok($$select convert_account_role('30000000-0000-4000-8000-000000000008','driver','61000000-0000-4000-8000-000000000001')$$,
 '22023',null::text,'Employee conversion rejects accidental organization argument');
select lives_ok($$select convert_account_role('30000000-0000-4000-8000-000000000008','driver')$$,'Owner converts customer to employee');
select is((select role::text from profiles where id='30000000-0000-4000-8000-000000000008'),'driver','Target role changed');
select is((select active from customer_users where user_id='30000000-0000-4000-8000-000000000008'),false,'Old membership retained but disabled');
select throws_ok($$select convert_account_role('30000000-0000-4000-8000-000000000008','warehouse')$$,
 '22023',null::text,'Conversion endpoint cannot replace ordinary employee role delegation');
select throws_ok($$select convert_account_role('30000000-0000-4000-8000-000000000008','customer')$$,
 '22023',null::text,'Employee conversion requires explicit destination');
select throws_ok($$select convert_account_role('30000000-0000-4000-8000-000000000008','customer','31000000-0000-4000-8000-000000000001')$$,
 '22023',null::text,'Occupied destination rejected');
select throws_ok($$select convert_account_role('30000000-0000-4000-8000-000000000008','customer','31000000-0000-4000-8000-000000000002')$$,
 '22023',null::text,'Inactive historical membership is not silently reactivated');
select lives_ok($$select convert_account_role('30000000-0000-4000-8000-000000000008','customer','61000000-0000-4000-8000-000000000001')$$,
 'Owner explicitly links converted employee to empty organization');
select is((select count(*) from customer_users where user_id='30000000-0000-4000-8000-000000000008'),2::bigint,'Both historical and new membership retained');
select is((select count(*) from audit_logs where action='role_changed' and entity_id='30000000-0000-4000-8000-000000000008'),2::bigint,'Exactly two successful conversions audited');
reset role;
select is((select jsonb_agg(to_jsonb(o) order by id) from orders o),(select orders from history_before),'Order history unchanged');
select is((select jsonb_agg(to_jsonb(p) order by id) from payments p),(select payments from history_before),'Payment history unchanged');
select is((select jsonb_agg(to_jsonb(c) order by id) from customers c),(select customers from history_before),'Customer organizations unchanged');
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000008',true);
set local role authenticated;
select is((select count(*) from customers),1::bigint,'Converted customer sees only new organization');
select is((select count(*) from payments),0::bigint,'Old organization financial access revoked');
select is((select count(*) from orders),0::bigint,'Old order access revoked');
reset role;

-- An unfinished run OR an open stop on a nominally ended run blocks conversion.
insert into delivery_runs(id,vehicle_id,primary_driver_id,assistant_driver_id,status)
 select '62000000-0000-4000-8000-000000000001',id,'30000000-0000-4000-8000-000000000005',
 '30000000-0000-4000-8000-000000000003','assigned' from vehicles limit 1;
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000007',true);
set local role authenticated;
select throws_ok($$select convert_account_role('30000000-0000-4000-8000-000000000005','customer','61000000-0000-4000-8000-000000000002')$$,
 '55000',null::text,'Primary driver open run blocks conversion');
select throws_ok($$select convert_account_role('30000000-0000-4000-8000-000000000003','customer','61000000-0000-4000-8000-000000000002')$$,
 '55000',null::text,'Assistant assignment blocks conversion even for a different current role');
select throws_ok($$select convert_account_role('30000000-0000-4000-8000-000000000002','customer','61000000-0000-4000-8000-000000000002')$$,
 '55000',null::text,'Sales customer assignment blocks conversion');
select is((select role::text from profiles where id='30000000-0000-4000-8000-000000000005'),'driver','Failed conversion preserves role');
select is((select count(*) from customer_users where customer_id='61000000-0000-4000-8000-000000000002'),0::bigint,'Failed conversion does not consume destination');
reset role;
update delivery_runs set started_at=now(),ended_at=now() where id='62000000-0000-4000-8000-000000000001';
insert into delivery_stops(id,run_id,order_id,sequence,status,assigned_by)
 values('62000000-0000-4000-8000-000000000002','62000000-0000-4000-8000-000000000001',
 '35000000-0000-4000-8000-000000000001',1,'assigned','30000000-0000-4000-8000-000000000006');
set local role authenticated;
select throws_ok($$select convert_account_role('30000000-0000-4000-8000-000000000005','customer','61000000-0000-4000-8000-000000000002')$$,
 '55000',null::text,'Open stop blocks conversion even if its run has ended');
reset role;
update delivery_stops set closed_at=now(),closed_by='30000000-0000-4000-8000-000000000006'
 where id='62000000-0000-4000-8000-000000000002';
set local role authenticated;
select lives_ok($$select convert_account_role('30000000-0000-4000-8000-000000000005','customer','61000000-0000-4000-8000-000000000002')$$,
 'Completed run history does not prevent explicit employee conversion');
reset role;
-- F4-05 keeps a last active Owner; retain this inactive-role test with a second Owner.
insert into auth.users(id,email) values('63000000-0000-4000-8000-000000000001','spare.owner@peksen.invalid');
insert into profiles(id,role,name) values('63000000-0000-4000-8000-000000000001','owner','Spare Owner');
update profiles set active=false where id='30000000-0000-4000-8000-000000000007';
set local role authenticated;
select throws_ok($$select convert_account_role('30000000-0000-4000-8000-000000000001','owner')$$,
 '42501',null::text,'Inactive Owner cannot convert accounts');
reset role;
select * from finish();
rollback;
