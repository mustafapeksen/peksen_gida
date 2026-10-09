begin;
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select no_plan();
insert into auth.users(id,aud,role,email,raw_app_meta_data,raw_user_meta_data)
 values('70000000-0000-4000-8000-000000000009','authenticated','authenticated','phase7.sales@peksen.invalid','{}','{}');
insert into profiles(id,role,name) values('70000000-0000-4000-8000-000000000009','sales_operator','Other sales');
update customers set assigned_sales_operator_id='30000000-0000-4000-8000-000000000002'
 where id='31000000-0000-4000-8000-000000000001';
insert into customers(id,company_name,created_by,assigned_sales_operator_id,active) values
 ('71000000-0000-4000-8000-000000000001','Creator only','30000000-0000-4000-8000-000000000002',null,true),
 ('71000000-0000-4000-8000-000000000002','Inactive assigned',null,'30000000-0000-4000-8000-000000000002',false),
 ('71000000-0000-4000-8000-000000000003','Other assigned','30000000-0000-4000-8000-000000000002','70000000-0000-4000-8000-000000000009',true);
create function pg_temp.customer_id() returns uuid language sql as $$select '31000000-0000-4000-8000-000000000001'::uuid$$;
create function pg_temp.cart(q integer default 1) returns jsonb language sql security definer set search_path='' as $$
 select jsonb_build_array(jsonb_build_object('unit_id',u.id,'quantity',q)) from public.product_units u
 join public.products p on p.id=u.product_id where p.sku='TEST-A' and u.unit_name='adet'
$$;
create temp table phase7_state(q jsonb,result jsonb,key uuid);
grant all on phase7_state to authenticated;
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000001',true);
insert into phase7_state values(quote_cart(pg_temp.customer_id(),pg_temp.cart()),null,'72000000-0000-4000-8000-000000000001');
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000002',true);
set local role authenticated;
select is((select count(*) from sales_checkout_customers()),1::bigint,'Only active assigned customer in picker');
select is((select id from sales_checkout_customers()),pg_temp.customer_id(),'Picker returns correct customer');
select is((select count(*) from customers),1::bigint,'RLS also excludes creator-only, inactive and other assigned customers');
select is(quote_cart(pg_temp.customer_id(),pg_temp.cart()),(select q from phase7_state),'Sales and Customer receive exactly the same quote');
select throws_ok($$select quote_cart('31000000-0000-4000-8000-000000000002',pg_temp.cart())$$,'42501',null::text,'Unassigned quote denied');
select throws_ok($$select quote_cart('71000000-0000-4000-8000-000000000001',pg_temp.cart())$$,'42501',null::text,'Creator-only quote denied');
select throws_ok($$select checkout_cart('71000000-0000-4000-8000-000000000001',pg_temp.cart(),'{}',gen_random_uuid())$$,'42501',null::text,'Creator-only checkout denied');
select throws_ok($$select checkout_cart('71000000-0000-4000-8000-000000000002',pg_temp.cart(),'{}',gen_random_uuid())$$,'42501',null::text,'Inactive customer checkout denied');
select throws_ok($$select checkout_cart('71000000-0000-4000-8000-000000000003',pg_temp.cart(),'{}',gen_random_uuid())$$,'42501',null::text,'Other Sales assignment checkout denied even for creator');
select throws_ok($$select checkout_cart('31000000-0000-4000-8000-000000000002',pg_temp.cart(),'{}',gen_random_uuid())$$,'42501',null::text,'Unassigned checkout denied');
select throws_ok($$select save_cart_draft('71000000-0000-4000-8000-000000000001',pg_temp.cart())$$,'42501',null::text,'Creator-only draft write denied');
select throws_ok($$select load_cart_draft('71000000-0000-4000-8000-000000000001')$$,'42501',null::text,'Creator-only draft read denied');
select throws_ok($$select update_customer_contact('71000000-0000-4000-8000-000000000001','Denied',null,null,null,null)$$,'42501',null::text,'Creator does not retain contact management');
select throws_ok($$update customers set assigned_sales_operator_id=auth.uid()$$,'42501',null::text,'Cannot self assign through raw write');
select throws_ok($$insert into orders(customer_id) values(pg_temp.customer_id())$$,'42501',null::text,'Raw order insert denied');
select lives_ok($$select save_cart_draft(pg_temp.customer_id(),pg_temp.cart())$$,'Assigned Sales uses shared draft');
select is(load_cart_draft(pg_temp.customer_id()),pg_temp.cart(),'Sales draft can be restored');
reset role;
-- Stale prices are blocked on the very same Phase 6 endpoint.
update products set unit_price_kurus=11000 where sku='TEST-A';
set local role authenticated;
update phase7_state set result=checkout_cart(pg_temp.customer_id(),pg_temp.cart(),q,key);
select is((select result->>'outcome' from phase7_state),'changed','Sales must explicitly reapprove changed price');
reset role;
select is((select count(*) from orders where operation_key=(select key from phase7_state)),0::bigint,'Price mismatch wrote no order');
select is((select reserved_qty::numeric from inventory i join products p on p.id=i.product_id where p.sku='TEST-A'),3::numeric,'Price mismatch reserved nothing');
set local role authenticated;
update phase7_state set q=result->'quote';
update phase7_state set result=checkout_cart(pg_temp.customer_id(),pg_temp.cart(),q,key);
select is((select result->>'status' from phase7_state),'submitted','Sales order submitted with current quote');
select is(checkout_cart(pg_temp.customer_id(),pg_temp.cart(),(select q from phase7_state),(select key from phase7_state)),(select result from phase7_state),'Sales retry returns same receipt');
select is((select source from orders where operation_key=(select key from phase7_state)),'sales_operator','Server derives source');
select is((select created_by from orders where operation_key=(select key from phase7_state)),auth.uid(),'Server derives Sales actor');
select is((select customer_id from orders where operation_key=(select key from phase7_state)),pg_temp.customer_id(),'Selected customer is stored');
select is((select exact_final_price_kurus_snapshot from order_items where order_id=((select result->>'order_id' from phase7_state)::uuid)),11000::numeric,'Exact snapshot preserved');
select lives_ok($$select save_cart_draft(pg_temp.customer_id(),pg_temp.cart(2))$$,'Save another Sales draft before reassignment');
reset role;
select is((select reserved_qty::numeric from inventory i join products p on p.id=i.product_id where p.sku='TEST-A'),4::numeric,'Sales reserves exactly once');
select is((select count(*) from order_status_history where operation_key=(select key from phase7_state)),1::bigint,'Sales history once');
select is((select actor_id from audit_logs where action='order_status_changed' and operation_key=(select key from phase7_state)),auth.uid(),'Audit actor is Sales');
select is((select credit_check_state from orders where operation_key=(select key from phase7_state)),'not_evaluated','No credit formula added');
select is((select count(*) from payments where order_id=((select result->>'order_id' from phase7_state)::uuid)),0::bigint,'Sales submit posts no payment');
-- Revocation applies to raw reads, drafts, catalog and even idempotent replay.
update customers set created_by=auth.uid(),assigned_sales_operator_id=null where id=pg_temp.customer_id();
set local role authenticated;
select is((select count(*) from orders),0::bigint,'Revoked creator cannot read orders through RLS');
select is((select count(*) from customer_pricing),0::bigint,'Revoked creator cannot read pricing through RLS');
select is((select count(*) from sales_checkout_customers()),0::bigint,'Revocation removes picker entry');
select throws_ok($$select * from customer_catalog(pg_temp.customer_id())$$,'42501',null::text,'Revocation closes catalog');
select throws_ok($$select checkout_cart(pg_temp.customer_id(),pg_temp.cart(),(select q from phase7_state),(select key from phase7_state))$$,'42501',null::text,'Revocation closes successful replay');
select throws_ok($$select load_cart_draft(pg_temp.customer_id())$$,'42501',null::text,'Revocation closes draft');
reset role;
update customers set assigned_sales_operator_id='70000000-0000-4000-8000-000000000009' where id=pg_temp.customer_id();
select set_config('request.jwt.claim.sub','70000000-0000-4000-8000-000000000009',true);
set local role authenticated;
select ok(exists(select 1 from sales_checkout_customers() where id=pg_temp.customer_id()),'New assignee can select customer');
select is(load_cart_draft(pg_temp.customer_id()),null::jsonb,'New assignee does not inherit another actor draft');
select throws_ok($$select checkout_cart(pg_temp.customer_id(),pg_temp.cart(),(select q from phase7_state),(select key from phase7_state))$$,'22023',null::text,'New assignee cannot reuse old actor request key');
reset role;
update customers set active=false where id=pg_temp.customer_id();
set local role authenticated;
select is((select count(*) from orders),0::bigint,'Passive customer hides its orders from Sales');
select throws_ok($$select quote_cart(pg_temp.customer_id(),pg_temp.cart())$$,'42501',null::text,'Passive customer denies shared quote');
reset role;
update profiles set active=false where id=auth.uid();
update customers set active=true where id=pg_temp.customer_id();
set local role authenticated;
select throws_ok($$select * from sales_checkout_customers()$$,'42501',null::text,'Inactive Sales cannot list');
select throws_ok($$select checkout_cart(pg_temp.customer_id(),pg_temp.cart(),'{}',gen_random_uuid())$$,'42501',null::text,'Inactive Sales cannot submit even for active assigned customer');
reset role;
-- Customer remains independent of Sales assignment; existing owner membership works.
update customers set active=true where id=pg_temp.customer_id();
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000001',true);
set local role authenticated;
select lives_ok($$select quote_cart(pg_temp.customer_id(),pg_temp.cart())$$,'Customer still shops regardless of Sales assignment');
select is(load_cart_draft(pg_temp.customer_id()),null::jsonb,'Customer does not inherit Sales draft');
select throws_ok($$select * from sales_checkout_customers()$$,'42501',null::text,'Customer cannot list Sales customers');
reset role;
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000003',true);
set local role authenticated;
select throws_ok($$select * from sales_checkout_customers()$$,'42501',null::text,'Warehouse cannot list Sales customers');
reset role;
set local role anon;
select throws_ok($$select * from sales_checkout_customers()$$,'42501',null::text,'Anonymous selection denied');
reset role;
select * from finish();
rollback;
