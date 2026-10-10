-- Schema/integrity tests, not Phase 4 authorization or later workflow acceptance.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select no_plan();

select tables_are('public', array['profiles','customers','customer_users','categories','warehouses','vehicles',
 'products','product_units','product_price_history','pricing_rules','pricing_proposals','customer_pricing',
 'orders','order_items','order_status_history','order_approvals','order_change_requests','alternative_offers',
 'inventory','stock_counts','stock_count_items','inventory_movements','delivery_runs','delivery_stops',
 'driver_locations','delivery_confirmations','order_returns','order_return_items','payments','payment_adjustments',
 'ratings','employee_salary_records','notifications','app_settings','audit_logs'],
 'All 25 source tables plus 10 named helper tables exist');
select is((select count(*) from pg_class c join pg_namespace n on n.oid=c.relnamespace
 where n.nspname='public' and c.relkind='r' and c.relrowsecurity),35::bigint,'All tables enable RLS');
select is((select count(*) from pg_policies where schemaname='public'
 and (cmd <> 'SELECT' or roles <> array['authenticated']::name[])),0::bigint,'Policies permit only authenticated reads');
select ok(not exists(select 1 from information_schema.role_table_grants
 where table_schema='public' and (grantee in ('anon','PUBLIC')
 or (grantee='authenticated' and privilege_type <> 'SELECT'))),'No anonymous access or direct client writes');
select is((select count(*) from profiles),8::bigint,'Original identities unchanged');
select is((select count(*) from warehouses),1::bigint,'One warehouse seeded');
select is((select count(*) from products),2::bigint,'Two products seeded');
select is((select count(*) from orders),3::bigint,'Draft, picking and delivered fixtures');
select is((select count(*) from driver_locations),0::bigint,'No location history seeded');
select is((select count(*) from app_settings),0::bigint,'No invented commercial default');
select ok(not exists(select 1 from pricing_rules where active),'Synthetic rule cannot activate a discount');
select ok(not exists(select 1 from information_schema.columns where table_schema='public'
 and column_name like '%token%'),'No device token storage');
select ok(not exists(select 1 from information_schema.columns where table_schema='public'
 and column_name like '%\_kurus' escape '\' and data_type <> 'bigint'),'All money columns use bigint kurus');
select ok(not exists(select 1 from information_schema.columns where table_schema='public'
 and data_type in ('real','double precision','money')),'No float or locale money columns');

select throws_ok($$insert into warehouses(name) values ('Second')$$,'23505',null::text,'Second warehouse rejected');
select throws_ok($$insert into warehouses(name,singleton) values ('Bypass',false)$$,'23514',null::text,'Singleton cannot be bypassed');
select throws_ok($$insert into products(sku,name,category_id,base_unit,min_quantity,unit_price_kurus)
 values ('BAD','Missing category',gen_random_uuid(),'adet',1,1)$$,'23503',null::text,'Product requires real category');
select throws_ok($$update products set unit_price_kurus=-1 where sku='TEST-A'$$,'23514',null::text,'Negative price rejected');
select throws_ok($$update products set min_quantity=0 where sku='TEST-A'$$,'23514',null::text,'Minimum quantity positive');
select is((select conversion_to_base::numeric from product_units where unit_name='paket'),0.25::numeric,'Fractional conversion exact');
select throws_ok($$update product_units set conversion_to_base=0 where unit_name='paket'$$,'23514',null::text,'Zero conversion rejected');
select throws_ok($$update product_units set conversion_to_base='NaN' where unit_name='paket'$$,'23514',null::text,'NaN conversion rejected');
select throws_ok($$update product_units set conversion_to_base='Infinity' where unit_name='paket'$$,'23514',null::text,'Infinite conversion rejected');
select throws_ok($$update order_items set product_unit_id=(select id from product_units where unit_name='paket')
 where order_id='35000000-0000-4000-8000-000000000001'$$,'23514',null::text,'Existing item unit snapshot immutable');
select throws_ok($$insert into order_items(order_id,product_id,product_unit_id,unit,conversion_to_base_snapshot,
 quantity,unit_price_kurus,discount_rate_snapshot,final_unit_price_kurus,line_total_kurus)
 select '35000000-0000-4000-8000-000000000003',p.id,u.id,'paket',0.25,1,100,0,100,100
 from products p cross join product_units u where p.sku='TEST-A' and u.unit_name='paket'$$,
 '23503',null::text,'Unit belonging to another product rejected');
select throws_ok($$update customer_pricing set discount_rate=1.01$$,'23514',null::text,'Discount above one rejected');
select throws_ok($$update pricing_proposals set quarter_start='2026-02-01'$$,'23514',null::text,'Only calendar quarter boundaries');
select throws_ok($$update pricing_proposals set status='approved'$$,'23514',null::text,'Approval requires actor/time/key');
select throws_ok($$update customers set payment_due_days=-1$$,'23514',null::text,'Negative customer due days rejected');
select throws_ok($$update customers set credit_limit_kurus=-1$$,'23514',null::text,'Negative credit limit rejected');

select is((select available_qty from inventory i join products p on p.id=i.product_id where p.sku='TEST-A'),94::numeric,'Available equals physical minus reserved');
select ok(not exists(select 1 from inventory i where physical_qty <>
 (select coalesce(sum(physical_delta),0) from inventory_movements m where m.product_id=i.product_id and m.warehouse_id=i.warehouse_id)
 or reserved_qty <> (select coalesce(sum(reserved_delta),0) from inventory_movements m where m.product_id=i.product_id and m.warehouse_id=i.warehouse_id)),
 'Seed stock reconciles with movement ledger');
select throws_ok($$update inventory set reserved_qty=physical_qty+1$$,'23514',null::text,'Over reservation rejected');
select throws_ok($$update inventory set physical_qty=-1$$,'23514',null::text,'Negative physical rejected');
select throws_ok($$update inventory set available_qty=123$$,'428C9',null::text,'Available cannot be independently edited');
select is((select picked_qty from order_items where order_id='35000000-0000-4000-8000-000000000001'),1,'Partial picking represented');
select throws_ok($$update order_items set picked_qty=quantity+1$$,'23514',null::text,'Cannot overpick');
select throws_ok($$update order_items set picked_qty=-1$$,'23514',null::text,'Cannot pick negative quantity');
select throws_ok($$update order_items set quantity=0$$,'23514',null::text,'Zero order quantity rejected');
select throws_ok($$update order_items set unit_price_kurus=99$$,'23514',null::text,'Historical price cannot be changed');
select throws_ok($$update order_items set discount_rate_snapshot=0.5$$,'23514',null::text,'Historical discount cannot be changed');
select throws_ok($$update order_items set line_total_kurus=1$$,'23514',null::text,'Unchanged quantity preserves line snapshot');
select lives_ok($$update products set unit_price_kurus=11000 where sku='TEST-A'$$,'Catalog can change independently');
select is((select unit_price_kurus from order_items where order_id='35000000-0000-4000-8000-000000000001'),10000::bigint,'Catalog change does not reprice snapshot');
select is((select difference from stock_count_items),(-1)::numeric,'Count difference is generated');
select throws_ok($$update stock_counts set status='approved'$$,'23514',null::text,'Count approval requires evidence');
select throws_ok($$insert into inventory_movements(warehouse_id,product_id,type,quantity,physical_delta,reserved_delta,created_by,operation_key)
 select warehouse_id,product_id,'picked',1,0,-1,'30000000-0000-4000-8000-000000000003',gen_random_uuid() from inventory limit 1$$,
 '23514',null::text,'Picked movement must reduce physical and reserved together');
select throws_ok($$update inventory_movements set quantity=1$$,'23514',null::text,'Movements cannot be rewritten');
select throws_ok($$delete from inventory_movements$$,'23514',null::text,'Movements cannot be deleted');
select throws_ok($$delete from product_price_history$$,'23514',null::text,'Price history cannot be deleted');
select throws_ok($$update order_status_history set reason='overwrite'$$,'23514',null::text,'Status history immutable');
select throws_ok($$delete from audit_logs$$,'23514',null::text,'Audit immutable');
select throws_ok($$update orders set status='payment_pending'$$,'23514',null::text,'Payment status not a logistics state');
select throws_ok($$update orders set total_kurus=1 where total_kurus=0$$,'23514',null::text,'Header amounts internally consistent');
select is((select product_id from order_items where order_id='35000000-0000-4000-8000-000000000001'),
 (select id from products where sku='TEST-A'),'Pending alternative does not modify original item');
select throws_ok($$update alternative_offers set status='accepted'$$,'23514',null::text,'Alternative acceptance needs recorded response');
select throws_ok($$update order_approvals set status='approved'$$,'23514',null::text,'Credit/risk approval needs actor/time/key');

-- Critical duplicate inserts, each with a new row id but the old operation key.
select throws_ok($$insert into payments(order_id,payment_amount_kurus,method,collector_user_id,collected_at,verification_status,operation_key)
 select order_id,payment_amount_kurus,method,collector_user_id,collected_at,verification_status,operation_key from payments$$,
 '23505',null::text,'Duplicate payment operation rejected');
select throws_ok($$insert into inventory_movements(warehouse_id,product_id,type,quantity,physical_delta,reserved_delta,created_by,operation_key)
 select warehouse_id,product_id,type,quantity,physical_delta,reserved_delta,created_by,operation_key from inventory_movements where type='received'$$,
 '23505',null::text,'Duplicate stock operation rejected');
select throws_ok($$insert into product_price_history(product_id,old_price_kurus,new_price_kurus,changed_by,reason,operation_key)
 select product_id,old_price_kurus,new_price_kurus,changed_by,reason,operation_key from product_price_history$$,
 '23505',null::text,'Duplicate price operation rejected');
select throws_ok($$insert into order_status_history(order_id,from_status,to_status,changed_by,reason,operation_key)
 select order_id,from_status,to_status,changed_by,reason,operation_key from order_status_history limit 1$$,
 '23505',null::text,'Duplicate status operation rejected');
select throws_ok($$insert into delivery_confirmations(order_id,event_type,performed_by,operation_key)
 select order_id,'dispute',performed_by,operation_key from delivery_confirmations limit 1$$,
 '23505',null::text,'Duplicate delivery operation rejected');
select lives_ok($$update order_approvals set status='approved',decided_by='30000000-0000-4000-8000-000000000006',
 decided_at=now(),operation_key='39000000-0000-4000-8000-000000000001'$$,'Decision evidence can be stored');
select throws_ok($$insert into order_approvals(order_id,reason,requested_by,status,decided_by,decided_at,operation_key)
 select order_id,reason,requested_by,status,decided_by,decided_at,operation_key from order_approvals$$,
 '23505',null::text,'Duplicate approval operation rejected');
select throws_ok($$update order_approvals set operation_key=gen_random_uuid()$$,'23514',null::text,'Completed approval key cannot be recycled');
select throws_ok($$delete from order_approvals$$,'23514',null::text,'Completed approval evidence cannot be removed');
select throws_ok($$update payments set payment_amount_kurus=1$$,'23514',null::text,'Payment principal cannot be overwritten');
select throws_ok($$delete from payments$$,'23514',null::text,'Wrong payment is not deleted');
select lives_ok($$insert into payment_adjustments(payment_id,adjustment_amount_kurus,reason,created_by,operation_key)
 select id,-100,'Synthetic correction','30000000-0000-4000-8000-000000000004',gen_random_uuid() from payments$$,'Correction represented separately');
select throws_ok($$update payment_adjustments set adjustment_amount_kurus=-200$$,'23514',null::text,'Correction evidence immutable');
select throws_ok($$insert into payments(order_id,payment_amount_kurus,method,collector_user_id,collected_at,verification_status,operation_key)
 select order_id,0,method,collector_user_id,collected_at,verification_status,gen_random_uuid() from payments$$,
 '23514',null::text,'Zero payment rejected');
select throws_ok($$insert into payments(order_id,payment_amount_kurus,method,collector_user_id,collected_at,verification_status,operation_key)
 select order_id,1,method,collector_user_id,collected_at,verification_status,null from payments$$,
 '23502',null::text,'Payment operation key required');
select throws_ok($$update payments set verification_status='verified'$$,'23514',null::text,'Verification needs accountant/time metadata');
select throws_ok($$insert into delivery_confirmations(order_id,event_type,performed_by,finalizes_delivery,operation_key)
 values ('35000000-0000-4000-8000-000000000001','driver','30000000-0000-4000-8000-000000000005',true,gen_random_uuid())$$,
 '23514',null::text,'Driver alone cannot finalize delivery');
select throws_ok($$insert into delivery_runs(vehicle_id,primary_driver_id,assistant_driver_id,status)
 select vehicle_id,primary_driver_id,primary_driver_id,'planned' from delivery_runs$$,
 '23514',null::text,'Primary and assistant must be distinct');
select lives_ok($$insert into delivery_stops(run_id,order_id,sequence,status,assigned_by)
 select id,'35000000-0000-4000-8000-000000000001',2,'assigned','30000000-0000-4000-8000-000000000006' from delivery_runs$$,'First active assignment accepted');
select throws_ok($$insert into delivery_stops(run_id,order_id,sequence,status,assigned_by)
 select id,'35000000-0000-4000-8000-000000000001',3,'assigned','30000000-0000-4000-8000-000000000006' from delivery_runs$$,
 '23505',null::text,'Second active assignment rejected');
select lives_ok($$update delivery_stops set closed_at=now(),closed_by=assigned_by,close_reason='Reassignment'
 where order_id='35000000-0000-4000-8000-000000000001'$$,'Old assignment can close');
select lives_ok($$insert into delivery_stops(run_id,order_id,sequence,status,assigned_by,previous_stop_id)
 select run_id,order_id,3,'assigned',assigned_by,id from delivery_stops where order_id='35000000-0000-4000-8000-000000000001'$$,
 'New assignment can reference old assignment');
select is((select count(*) from delivery_stops where order_id='35000000-0000-4000-8000-000000000001'),2::bigint,'Old assignment retained');
select throws_ok($$update delivery_stops set status='rewritten' where closed_at is not null$$,'23514',null::text,'Closed assignment cannot be rewritten');
select throws_ok($$delete from delivery_stops$$,'23514',null::text,'Assignment history cannot be deleted');
select throws_ok($$insert into ratings(order_id,customer_id,driver_id,score)
 select order_id,customer_id,driver_id,score from ratings$$,'23505',null::text,'One rating per order');
select throws_ok($$update ratings set customer_id='31000000-0000-4000-8000-000000000001'$$,'23503',null::text,'Rating cannot reference another customer');
select throws_ok($$update ratings set score=6$$,'23514',null::text,'Rating limited to 1..5');
select throws_ok($$update order_return_items set order_id='35000000-0000-4000-8000-000000000001'$$,'23503',null::text,'Return items belong to their order');

select lives_ok($$insert into app_settings(key,value,updated_by) values ('default_payment_due_days','14',
 '30000000-0000-4000-8000-000000000007')$$,'Documented integer setting accepted only as test data');
select throws_ok($$update app_settings set key='hidden_threshold'$$,'23514',null::text,'Unknown setting rejected');
select throws_ok($$update app_settings set value='"14"'$$,'23514',null::text,'String instead of JSON number rejected');
select throws_ok($$update app_settings set value='-1'$$,'23514',null::text,'Negative due days rejected');
select throws_ok($$update app_settings set value='1.5'$$,'23514',null::text,'Fractional due days rejected');
select throws_ok($$update app_settings set value='2147483648'$$,'23514',null::text,'Integer storage overflow rejected');
select throws_ok($$insert into audit_logs(actor_id,action,entity_type,entity_id)
 values ('30000000-0000-4000-8000-000000000007','screen_view','screen',gen_random_uuid())$$,
 '23514',null::text,'Non-commercial audit noise rejected');
set local role anon;
select throws_ok($$select * from products$$,'42501',null::text,'Anonymous business reads remain closed');
reset role;
set local role authenticated;
select is((select count(*) from employee_salary_records),0::bigint,'No salary access without an identified Owner');
select throws_ok($$update orders set status='delivered'$$,'42501',null::text,'Direct client order status update denied');
select throws_ok($$insert into payments(order_id,payment_amount_kurus,method,collector_user_id,collected_at,verification_status,operation_key)
 values ('35000000-0000-4000-8000-000000000002',1,'cash','30000000-0000-4000-8000-000000000002',now(),'recorded',gen_random_uuid())$$,
 '42501',null::text,'Direct client payment write denied');
reset role;
-- Closing review regressions. Phase 4 updates only three obsolete access
-- expectations above; all original business constraints remain exercised.
-- All fixtures below are rolled back; the application seed remains unchanged.
insert into stock_counts(id,warehouse_id,created_by,status)
select '43000000-0000-4000-8000-000000000001',id,'30000000-0000-4000-8000-000000000003','pending' from warehouses;
insert into stock_count_items(stock_count_id,product_id,system_qty,counted_qty)
select '43000000-0000-4000-8000-000000000001',id,0,0 from products where sku='TEST-B';

-- P2-1: Editing remains possible before approval; both old and new parents
-- must be checked on a detail move. Approval is metadata, not a stock workflow.
select lives_ok($$update stock_count_items set counted_qty=1
 where stock_count_id='43000000-0000-4000-8000-000000000001'$$,'P2-1: pending count detail remains editable');
select lives_ok($$update stock_counts set status='approved',approved_by='30000000-0000-4000-8000-000000000006',
 approved_at=now(),operation_key=gen_random_uuid() where id <> '43000000-0000-4000-8000-000000000001'$$,
 'P2-1: original count can be approved with evidence');
select throws_ok($$insert into stock_count_items(stock_count_id,product_id,system_qty,counted_qty)
 select c.id,p.id,0,0 from stock_counts c cross join products p where c.status='approved' and p.sku='TEST-B'$$,
 '23514',null::text,'P2-1: cannot add an item to approved count');
select throws_ok($$update stock_count_items set counted_qty=counted_qty+1
 where stock_count_id in (select id from stock_counts where status='approved')$$,
 '23514',null::text,'P2-1: cannot alter approved count quantity');
select throws_ok($$delete from stock_count_items
 where stock_count_id in (select id from stock_counts where status='approved')$$,
 '23514',null::text,'P2-1: cannot delete approved count detail');
select throws_ok($$update stock_count_items set stock_count_id='43000000-0000-4000-8000-000000000001'
 where stock_count_id in (select id from stock_counts where status='approved')$$,
 '23514',null::text,'P2-1: cannot move detail out of approved count');
select throws_ok($$update stock_count_items set stock_count_id=(select id from stock_counts where status='approved')
 where stock_count_id='43000000-0000-4000-8000-000000000001'$$,
 '23514',null::text,'P2-1: cannot move detail into approved count');

-- P2-2: A genuinely unused run can change vehicle. Recorded end/assignment
-- makes that binding permanent even if ended_at or the technical flag is reset.
insert into vehicles(id,plate,description)
values ('42000000-0000-4000-8000-000000000001','TEST-ARAC-02','Rollback-only fixture');
insert into delivery_runs(id,vehicle_id,primary_driver_id,status)
select '41000000-0000-4000-8000-000000000001',id,'30000000-0000-4000-8000-000000000005','planned'
from vehicles where plate='TEST-ARAC-01';
insert into delivery_runs(id,vehicle_id,primary_driver_id,status,started_at,ended_at)
select '41000000-0000-4000-8000-000000000002',id,'30000000-0000-4000-8000-000000000005','completed',now(),now()
from vehicles where plate='TEST-ARAC-01';
select lives_ok($$update delivery_runs set vehicle_id='42000000-0000-4000-8000-000000000001'
 where id='41000000-0000-4000-8000-000000000001'$$,'P2-2: unused open run can change vehicle');
select throws_ok($$update delivery_runs set vehicle_id='42000000-0000-4000-8000-000000000001'
 where id='41000000-0000-4000-8000-000000000002'$$,
 '23514',null::text,'P2-2: closed run without stops cannot change vehicle');
select throws_ok($$update delivery_runs set vehicle_id='42000000-0000-4000-8000-000000000001'
 where id in (select run_id from delivery_stops where closed_at is not null)$$,
 '23514',null::text,'P2-2: historical run cannot rewrite old stops vehicle');
update delivery_runs set ended_at=null,vehicle_assignment_locked=false
where id='41000000-0000-4000-8000-000000000002';
select ok((select vehicle_assignment_locked from delivery_runs where id='41000000-0000-4000-8000-000000000002'),
 'P2-2: clearing end date or flag does not unlock vehicle');
select throws_ok($$update delivery_runs set vehicle_id='42000000-0000-4000-8000-000000000001'
 where id='41000000-0000-4000-8000-000000000002'$$,
 '23514',null::text,'P2-2: reopened run retains its historical vehicle');
select lives_ok($$insert into delivery_stops(run_id,order_id,sequence,status,assigned_by)
 values ('41000000-0000-4000-8000-000000000001','35000000-0000-4000-8000-000000000003',1,'assigned',
 '30000000-0000-4000-8000-000000000006')$$,'P2-2: first assignment on new run allowed');
select ok((select vehicle_assignment_locked from delivery_runs where id='41000000-0000-4000-8000-000000000001'),
 'P2-2: first stop locks its run vehicle');
select throws_ok($$update delivery_runs set vehicle_id=(select id from vehicles where plate='TEST-ARAC-01')
 where id='41000000-0000-4000-8000-000000000001'$$,
 '23514',null::text,'P2-2: assigned open run cannot change vehicle');
select lives_ok($$update delivery_runs set vehicle_id=vehicle_id
 where id='41000000-0000-4000-8000-000000000001'$$,'P2-2: same vehicle update is harmless');

-- P2-3: Invalid events never occupy the one-party confirmation slot/key.
select throws_ok($$insert into delivery_confirmations(order_id,event_type,performed_by,operation_key)
 values ('35000000-0000-4000-8000-000000000003','customer','30000000-0000-4000-8000-000000000001',
 '44000000-0000-4000-8000-000000000001')$$,
 '23514',null::text,'P2-3: false customer event rejected');
select throws_ok($$insert into delivery_confirmations(order_id,event_type,performed_by,finalizes_delivery,operation_key)
 values ('35000000-0000-4000-8000-000000000003','customer','30000000-0000-4000-8000-000000000001',true,gen_random_uuid())$$,
 '23514',null::text,'P2-3: no finalization with false customer confirmation');
select lives_ok($$insert into delivery_confirmations(order_id,event_type,customer_confirmed,performed_by,operation_key)
 values ('35000000-0000-4000-8000-000000000003','customer',true,'30000000-0000-4000-8000-000000000001',
 '44000000-0000-4000-8000-000000000001')$$,
 'P2-3: real confirmation can reuse slot and key after rejected false event');
select throws_ok($$insert into delivery_confirmations(order_id,event_type,performed_by,operation_key)
 values ('35000000-0000-4000-8000-000000000003','driver','30000000-0000-4000-8000-000000000005',gen_random_uuid())$$,
 '23514',null::text,'P2-3: false driver event rejected');
select throws_ok($$insert into delivery_confirmations(order_id,event_type,driver_confirmed,finalizes_delivery,performed_by,operation_key)
 values ('35000000-0000-4000-8000-000000000003','driver',true,true,'30000000-0000-4000-8000-000000000005',gen_random_uuid())$$,
 '23514',null::text,'P2-3: even a true driver confirmation cannot finalize alone');
select lives_ok($$insert into delivery_confirmations(order_id,event_type,driver_confirmed,performed_by,operation_key)
 values ('35000000-0000-4000-8000-000000000003','driver',true,'30000000-0000-4000-8000-000000000005',gen_random_uuid())$$,
 'P2-3: true driver event accepted');
select throws_ok($$insert into delivery_confirmations(order_id,event_type,customer_confirmed,performed_by,operation_key)
 values ('35000000-0000-4000-8000-000000000003','dispute',true,'30000000-0000-4000-8000-000000000001',gen_random_uuid())$$,
 '23514',null::text,'P2-3: dispute cannot masquerade as customer confirmation');
select throws_ok($$insert into delivery_confirmations(order_id,event_type,finalizes_delivery,performed_by,operation_key)
 values ('35000000-0000-4000-8000-000000000003','dispute',true,'30000000-0000-4000-8000-000000000006',gen_random_uuid())$$,
 '23514',null::text,'P2-3: dispute cannot finalize delivery');
select throws_ok($$insert into delivery_confirmations(order_id,event_type,driver_confirmed,resolution_reason,performed_by,operation_key)
 values ('35000000-0000-4000-8000-000000000003','resolution',true,'Test resolution',
 '30000000-0000-4000-8000-000000000006',gen_random_uuid())$$,
 '23514',null::text,'P2-3: resolution is not a driver confirmation');
select lives_ok($$insert into delivery_confirmations(order_id,event_type,finalizes_delivery,resolution_reason,performed_by,operation_key)
 values ('35000000-0000-4000-8000-000000000003','resolution',true,'Test resolution',
 '30000000-0000-4000-8000-000000000006',gen_random_uuid())$$,
 'P2-3: resolution with reason remains representable');

-- P2-4: The seeded open item has no return composite FK; the new trigger,
-- not an unrelated FK, must reject the move to the other customer's order.
select throws_ok($$update order_items set order_id='35000000-0000-4000-8000-000000000002'
 where order_id='35000000-0000-4000-8000-000000000001'$$,
 '23514',null::text,'P2-4: item cannot move to a different customer order');
select throws_ok($$update order_items set order_id='35000000-0000-4000-8000-000000000003'
 where order_id='35000000-0000-4000-8000-000000000001'$$,
 '23514',null::text,'P2-4: item cannot move even within same customer');
select lives_ok($$update order_items set order_id=order_id$$,'P2-4: same order update remains allowed');

-- P2-5: Each failed decision leaves the original request pending. A complete
-- decision is accepted, then protected by the existing immutable trigger.
select throws_ok($$update order_change_requests set status='approved',decision_note='Sentetik test kararı'$$,
 '23514',null::text,'P2-5: approval without decision metadata rejected');
select throws_ok($$update order_change_requests set status='rejected',decision_note='Sentetik test kararı'$$,
 '23514',null::text,'P2-5: rejection without decision metadata rejected');
select throws_ok($$update order_change_requests set status='approved',decided_by='30000000-0000-4000-8000-000000000006',decision_note='Sentetik test kararı'$$,
 '23514',null::text,'P2-5: approval requires decision time');
select throws_ok($$update order_change_requests set status='rejected',decided_at=now(),decision_note='Sentetik test kararı'$$,
 '23514',null::text,'P2-5: rejection requires decision actor');
select throws_ok($$insert into order_change_requests(order_id,type,requested_by,reason,status,decision_note)
 values ('35000000-0000-4000-8000-000000000003','cancel','30000000-0000-4000-8000-000000000002','Test','approved','Sentetik test kararı')$$,
 '23514',null::text,'P2-5: direct completed request INSERT also requires evidence');
select lives_ok($$update order_change_requests set status='approved',decided_by='30000000-0000-4000-8000-000000000006',decided_at=now(),decision_note='Sentetik bütünlük testi kararı'$$,
 'P2-5: complete decision accepted');
select throws_ok($$update order_change_requests set decided_by=null$$,
 '23514',null::text,'P2-5: completed decision evidence cannot be erased');

-- P2-6: Closed candidates avoid the unrelated one-active-order constraint,
-- ensuring each failure exercises the predecessor relation itself.
select throws_ok($$insert into delivery_stops(run_id,order_id,sequence,status,assigned_by,assigned_at,closed_by,closed_at,previous_stop_id)
 select run_id,'35000000-0000-4000-8000-000000000003',80,'closed',assigned_by,now(),assigned_by,now(),id
 from delivery_stops where order_id='35000000-0000-4000-8000-000000000002'$$,
 '23503',null::text,'P2-6: previous stop cannot belong to another order');
select throws_ok($$insert into delivery_stops(id,run_id,order_id,sequence,status,assigned_by,assigned_at,closed_by,closed_at,previous_stop_id)
 values ('45000000-0000-4000-8000-000000000001','41000000-0000-4000-8000-000000000001',
 '35000000-0000-4000-8000-000000000003',81,'closed','30000000-0000-4000-8000-000000000006',now(),
 '30000000-0000-4000-8000-000000000006',now(),'45000000-0000-4000-8000-000000000001')$$,
 '23514',null::text,'P2-6: stop cannot be its own predecessor');
select lives_ok($$insert into delivery_stops(run_id,order_id,sequence,status,assigned_by,assigned_at,closed_by,closed_at,previous_stop_id)
 select run_id,order_id,82,'closed',assigned_by,now(),assigned_by,now(),id
 from delivery_stops where order_id='35000000-0000-4000-8000-000000000002'$$,
 'P2-6: same-order predecessor remains valid');

-- P2-7: FK checks bind evidence to product without adding approval workflows
-- or compensation formulas. These inserts are isolated rollback fixtures.
select throws_ok($$insert into inventory_movements(warehouse_id,product_id,type,quantity,physical_delta,reserved_delta,
 stock_count_id,created_by,operation_key)
 select c.warehouse_id,p.id,'count_adjustment',1,-1,0,c.id,c.created_by,gen_random_uuid()
 from stock_counts c cross join products p where c.status='approved' and p.sku='TEST-B'$$,
 '23503',null::text,'P2-7: count adjustment cannot reference an uncounted product');
select lives_ok($$insert into inventory_movements(warehouse_id,product_id,type,quantity,physical_delta,reserved_delta,
 stock_count_id,created_by,operation_key)
 select c.warehouse_id,i.product_id,'count_adjustment',1,-1,0,c.id,c.created_by,gen_random_uuid()
 from stock_counts c join stock_count_items i on i.stock_count_id=c.id where c.status='approved'$$,
 'P2-7: same-product count reference accepted');
select throws_ok($$insert into inventory_movements(warehouse_id,product_id,type,quantity,physical_delta,reserved_delta,
 compensates_movement_id,created_by,operation_key)
 select m.warehouse_id,p.id,'compensation',1,-1,0,m.id,m.created_by,gen_random_uuid()
 from inventory_movements m cross join products p where m.type='received' and p.sku='TEST-B'$$,
 '23503',null::text,'P2-7: compensation cannot refer to another product movement');
select lives_ok($$insert into inventory_movements(warehouse_id,product_id,type,quantity,physical_delta,reserved_delta,
 compensates_movement_id,created_by,operation_key)
 select warehouse_id,product_id,'compensation',1,-1,0,id,created_by,gen_random_uuid()
 from inventory_movements where type='received'$$,
 'P2-7: same-product compensation accepted');

select * from finish();
rollback;
