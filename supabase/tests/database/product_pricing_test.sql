begin;
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select no_plan();

create function pg_temp.product_id() returns uuid language sql as $$select '99000000-0000-4000-8000-000000000001'::uuid$$;
create function pg_temp.unit_id() returns uuid language sql security definer set search_path='' as $$select id from public.product_units where product_id=pg_temp.product_id() and unit_name='paket'$$;
create function pg_temp.customer_id() returns uuid language sql as $$select '31000000-0000-4000-8000-000000000001'::uuid$$;

select has_function('public','quote_product',array['uuid','uuid','integer']);
select has_column('public','order_items','exact_final_price_kurus_snapshot','Exact final price snapshot column exists');
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000003',true);
set local role authenticated;
select lives_ok($$select create_product_draft('99000000-0000-4000-8000-000000000001','F5-TEST','Faz 5 test',
 (select id from product_categories() limit 1),'kg',1,'Sentetik',
 '[{"name":"paket","conversion":"0.25"},{"name":"kg","conversion":"1"}]')$$,'Warehouse creates unpriced draft and exact units');
select ok(not exists(select 1 from product_reference_list() p where p ? 'price_kurus'),'Warehouse projection omits prices entirely');
select ok(not exists(select 1 from product_reference_list() p where p ? 'minimum'),'Warehouse retains previous restricted product fields');
select is((select count(*) from products),0::bigint,'Warehouse cannot bypass projection');
select throws_ok($$select change_product_price('99000000-0000-4000-8000-000000000001',null,3,'test',gen_random_uuid())$$,'42501',null::text,'Warehouse cannot set first price');
select throws_ok($$select activate_product('99000000-0000-4000-8000-000000000001',3)$$,'42501',null::text,'Warehouse cannot activate');
select throws_ok($$select * from product_price_events('99000000-0000-4000-8000-000000000001')$$,'42501',null::text,'Warehouse cannot read price history');
select throws_ok($$update products set unit_price_kurus=1$$,'42501',null::text,'Raw price writes stay closed');
select throws_ok($$select create_product_draft(gen_random_uuid(),'BAD','Bad',(select id from product_categories() limit 1),'kg',1,null,
 '[{"name":"kg","conversion":"0.25"}]')$$,'22023',null::text,'Base unit conversion cannot disagree with its name');
select throws_ok($$select create_product_draft(gen_random_uuid(),'BAD','Bad',(select id from product_categories() limit 1),'kg',1,null,
 '[{"name":"paket","conversion":"0"}]')$$,'22023',null::text,'Zero conversion rejected');
select throws_ok($$select create_product_draft(gen_random_uuid(),'BAD','Bad',(select id from product_categories() limit 1),'kg',1,null,
 '[{"name":"paket","conversion":"NaN"}]')$$,'22023',null::text,'NaN conversion rejected');
select throws_ok($$select create_product_draft(gen_random_uuid(),'BAD','Bad',(select id from product_categories() limit 1),'kg',1,null,
 '[{"name":"paket","conversion":0.1}]')$$,'22023',null::text,'API requires exact decimal strings');
select throws_ok($$select create_product_draft(gen_random_uuid(),'BAD','Bad',(select id from product_categories() limit 1),'kg',0,null,
 '[{"name":"kg","conversion":"1"}]')$$,'22023',null::text,'Zero minimum rejected');
select throws_ok($$select create_product_draft(gen_random_uuid(),'BAD','Bad',(select id from product_categories() limit 1),'kg',1,null,'[]')$$,'22023',null::text,'At least one sales unit required');
reset role;
select ok((select unit_price_kurus is null and not active from products where sku='F5-TEST'),'Draft has NULL price and is not for sale');
select is((select count(*) from products where sku='BAD'),0::bigint,'Invalid units roll back product creation');
select is((select conversion_to_base::numeric from product_units where id=pg_temp.unit_id()),0.25::numeric,'Conversion preserved exactly');
select throws_ok($$update products set active=true where sku='F5-TEST'$$,'23514',null::text,'Active product requires a price at DB level');

select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000006',true);
set local role authenticated;
select throws_ok($$select activate_product('99000000-0000-4000-8000-000000000001',null)$$,'22023',null::text,'Manager cannot activate unpriced product');
select lives_ok($$select change_product_price('99000000-0000-4000-8000-000000000001',null,3,'İlk fiyat','99100000-0000-4000-8000-000000000001')$$,'Manager sets first price');
select lives_ok($$select change_product_price('99000000-0000-4000-8000-000000000001',null,3,'İlk fiyat','99100000-0000-4000-8000-000000000001')$$,'Same request replays successfully');
select is((select count(*) from product_price_history where operation_key='99100000-0000-4000-8000-000000000001'),1::bigint,'Replay produces one history row');
select throws_ok($$select change_product_price('99000000-0000-4000-8000-000000000001',null,4,'İlk fiyat','99100000-0000-4000-8000-000000000001')$$,'22023',null::text,'Changed replay payload rejected');
select throws_ok($$select change_product_price('99000000-0000-4000-8000-000000000001',null,4,'Diğer',gen_random_uuid())$$,'40001',null::text,'Stale expected price rejected');
select throws_ok($$select change_product_price('99000000-0000-4000-8000-000000000001',3,-1,'Diğer',gen_random_uuid())$$,'22023',null::text,'Negative price rejected');
select throws_ok($$select change_product_price('99000000-0000-4000-8000-000000000001',3,4,' ',gen_random_uuid())$$,'22023',null::text,'Empty reason rejected');
select throws_ok($$select quote_product(pg_temp.customer_id(),pg_temp.unit_id(),4)$$,'22023',null::text,'Priced but closed product cannot be quoted');
select throws_ok($$select activate_product(pg_temp.product_id(),4)$$,'40001',null::text,'Activation checks current price');
select lives_ok($$select activate_product(pg_temp.product_id(),3)$$,'Manager explicitly opens sale');
select lives_ok($$select activate_product(pg_temp.product_id(),3)$$,'Activation replay is harmless');
select is((select p->>'price_kurus' from product_reference_list() p where p->>'sku'='F5-TEST'),'3','Manager sees exact price text');
select throws_ok($$select quote_product(pg_temp.customer_id(),pg_temp.unit_id(),3)$$,'22023',null::text,'Minimum uses base quantity, not sales quantity');
select throws_ok($$select quote_product(pg_temp.customer_id(),pg_temp.unit_id(),0)$$,'22023',null::text,'Zero sales quantity rejected');
select throws_ok($$select quote_product(pg_temp.customer_id(),pg_temp.unit_id(),-1)$$,'22023',null::text,'Negative sales quantity rejected');
select is((quote_product(pg_temp.customer_id(),pg_temp.unit_id(),4)->>'base_quantity')::numeric,1::numeric,'Four quarter units equal minimum one');
select is((quote_product(pg_temp.customer_id(),pg_temp.unit_id(),6)->>'base_quantity')::numeric,1.5::numeric,'Conversion never rounded');
reset role;
select is((select count(*) from audit_logs where operation_key='99100000-0000-4000-8000-000000000001'),1::bigint,'Exactly one price audit');
select ok((select old_price_kurus is null and new_price_kurus=3 from product_price_history where operation_key='99100000-0000-4000-8000-000000000001'),'First price history represents absence without zero sentinel');
update customer_pricing set discount_rate=0.5,effective_from=(statement_timestamp() at time zone 'Europe/Istanbul')::date where customer_id=pg_temp.customer_id();
update customers set assigned_sales_operator_id='30000000-0000-4000-8000-000000000002' where id=pg_temp.customer_id();
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000001',true);
set local role authenticated;
select is((quote_product(pg_temp.customer_id(),pg_temp.unit_id(),4)->>'exact_final_price_kurus_snapshot')::numeric,0.375::numeric,'Exact final sale-unit snapshot retains fractional kurus');
select is(quote_product(pg_temp.customer_id(),pg_temp.unit_id(),4)->>'line_total_kurus','2','1.5 kurus line rounds half upward');
select is(quote_product(pg_temp.customer_id(),pg_temp.unit_id(),6)->>'line_total_kurus','2','2.25 kurus rounds once at line level');
select is(quote_product(pg_temp.customer_id(),pg_temp.unit_id(),4)->>'final_unit_price_kurus','0','Compatibility display is not used as calculation input');
select throws_ok($$select quote_product('31000000-0000-4000-8000-000000000002',pg_temp.unit_id(),4)$$,'42501',null::text,'Customer cannot quote another customer');
select throws_ok($$select * from product_reference_list()$$,'42501',null::text,'Customer cannot enter operational product management');
select throws_ok($$select change_product_price(pg_temp.product_id(),3,4,'Denied',gen_random_uuid())$$,'42501',null::text,'Customer cannot change price');
reset role;
create temp table expected_quote as select quote_product(pg_temp.customer_id(),pg_temp.unit_id(),4) q with no data;
-- Quotes must be obtained through an authorized JWT, not the SQL superuser role.
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000001',true);
insert into expected_quote select quote_product(pg_temp.customer_id(),pg_temp.unit_id(),4);
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000002',true);
select is(quote_product(pg_temp.customer_id(),pg_temp.unit_id(),4),(select q from expected_quote),'Assigned Sales and Customer receive identical quote');
set local role authenticated;
select throws_ok($$select quote_product('31000000-0000-4000-8000-000000000002',pg_temp.unit_id(),4)$$,'42501',null::text,'Sales cannot quote unassigned customer');
reset role;
update customer_pricing set effective_from=(statement_timestamp() at time zone 'Europe/Istanbul')::date+1 where customer_id=pg_temp.customer_id();
select is((quote_product(pg_temp.customer_id(),pg_temp.unit_id(),4)->>'discount_rate_snapshot')::numeric,0::numeric,'Future Istanbul date does not apply discount');
update customer_pricing set effective_from=(statement_timestamp() at time zone 'Europe/Istanbul')::date where customer_id=pg_temp.customer_id();
select is((quote_product(pg_temp.customer_id(),pg_temp.unit_id(),4)->>'discount_rate_snapshot')::numeric,0.5::numeric,'Current Istanbul date applies discount');

insert into order_items select (jsonb_populate_record(null::public.order_items,q || jsonb_build_object(
 'id','99200000-0000-4000-8000-000000000001','order_id','35000000-0000-4000-8000-000000000003','picked_qty',0))).* from expected_quote;
select is((select line_total_kurus from order_items where id='99200000-0000-4000-8000-000000000001'),2::bigint,'Quote can be persisted as a consistent order snapshot');
select throws_ok($$update order_items set exact_final_price_kurus_snapshot=1 where id='99200000-0000-4000-8000-000000000001'$$,'23514',null::text,'Exact snapshot cannot be rewritten');
select throws_ok($$update order_items set exact_list_price_kurus_snapshot=null,exact_final_price_kurus_snapshot=null where id='99200000-0000-4000-8000-000000000001'$$,'23514',null::text,'Exact snapshot cannot be removed');
select throws_ok($$insert into order_items select (jsonb_populate_record(null::public.order_items,q || jsonb_build_object(
 'id',gen_random_uuid(),'order_id','35000000-0000-4000-8000-000000000003','picked_qty',0,'line_total_kurus','0'))).* from expected_quote$$,'23514',null::text,'Rounded unit multiplied by quantity cannot replace exact line total');
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000007',true);
set local role authenticated;
select lives_ok($$select change_product_price(pg_temp.product_id(),3,5,'Yeni fiyat','99100000-0000-4000-8000-000000000002')$$,'Owner changes price');
select throws_ok($$select change_product_price(pg_temp.product_id(),null,3,'İlk fiyat','99100000-0000-4000-8000-000000000001')$$,'22023',null::text,'Another actor cannot replay original key');
reset role;
select is((select exact_final_price_kurus_snapshot from order_items where id='99200000-0000-4000-8000-000000000001'),0.375::numeric,'Catalog price change leaves historical exact snapshot untouched');
select is((select line_total_kurus from order_items where id='99200000-0000-4000-8000-000000000001'),2::bigint,'Catalog price change leaves historical total untouched');
update customer_pricing set discount_rate=0 where customer_id=pg_temp.customer_id();
select is((select exact_final_price_kurus_snapshot from order_items where id='99200000-0000-4000-8000-000000000001'),0.375::numeric,'Discount change leaves historical exact snapshot untouched');
update product_units set orderable=false where id=pg_temp.unit_id();
select throws_ok($$select quote_product(pg_temp.customer_id(),pg_temp.unit_id(),4)$$,'22023',null::text,'Closed sales unit rejected');
update product_units set orderable=true where id=pg_temp.unit_id();
update products set unit_price_kurus=9223372036854775807 where id=pg_temp.product_id();
select throws_ok($$select quote_product(pg_temp.customer_id(),pg_temp.unit_id(),8)$$,'22003',null::text,'Financial bigint overflow rejected');
update products set unit_price_kurus=5 where id=pg_temp.product_id();
update profiles set role='owner' where id='30000000-0000-4000-8000-000000000006';
update profiles set active=false where id='30000000-0000-4000-8000-000000000007';
set local role authenticated;
select throws_ok($$select * from product_reference_list()$$,'42501',null::text,'Inactive Owner loses product read');
select throws_ok($$select change_product_price(pg_temp.product_id(),5,6,'Denied',gen_random_uuid())$$,'42501',null::text,'Inactive Owner loses price mutation');
reset role;
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000004',true);
set local role authenticated;
select throws_ok($$select * from product_reference_list()$$,'42501',null::text,'Accounting product prices stay closed');
select throws_ok($$select change_product_price(pg_temp.product_id(),5,6,'Denied',gen_random_uuid())$$,'42501',null::text,'Accounting price mutation stays closed');
select throws_ok($$select quote_product(pg_temp.customer_id(),pg_temp.unit_id(),4)$$,'42501',null::text,'Accounting cannot obtain prices through quote');
select throws_ok($$select create_product_draft(gen_random_uuid(),'BAD','Bad',gen_random_uuid(),'kg',1,null,'[]')$$,'42501',null::text,'Accounting cannot create products');
reset role;
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000005',true);
set local role authenticated;
select throws_ok($$select * from product_reference_list()$$,'42501',null::text,'Driver cannot access product management');
select throws_ok($$select quote_product(pg_temp.customer_id(),pg_temp.unit_id(),4)$$,'42501',null::text,'Driver cannot obtain product quote');
reset role;
set local role anon;
select throws_ok($$select * from product_reference_list()$$,'42501',null::text,'Anonymous product access denied');
select throws_ok($$select quote_product(null,null,1)$$,'42501',null::text,'Anonymous quote denied');
select throws_ok($$select change_product_price(null,null,1,'x',gen_random_uuid())$$,'42501',null::text,'Anonymous mutation denied');
reset role;
select * from finish();
rollback;
