-- Synthetic schema fixtures only. Amounts/periods are NOT business defaults.
-- Original eight identity fixtures remain untouched. No passwords or tokens.
begin;
do $$
declare
  customer_a uuid := '31000000-0000-4000-8000-000000000001';
  customer_b uuid := '31000000-0000-4000-8000-000000000002';
  sales uuid := '30000000-0000-4000-8000-000000000002';
  warehouse_user uuid := '30000000-0000-4000-8000-000000000003';
  driver uuid := '30000000-0000-4000-8000-000000000005';
  manager uuid := '30000000-0000-4000-8000-000000000006';
  owner_user uuid := '30000000-0000-4000-8000-000000000007';
  category uuid := gen_random_uuid(); wh uuid := gen_random_uuid();
  vehicle uuid := gen_random_uuid(); product_a uuid := gen_random_uuid();
  product_b uuid := gen_random_uuid(); unit_a uuid := gen_random_uuid();
  unit_b uuid := gen_random_uuid(); rule uuid := gen_random_uuid();
  open_order uuid := '35000000-0000-4000-8000-000000000001';
  delivered_order uuid := '35000000-0000-4000-8000-000000000002';
  draft_order uuid := '35000000-0000-4000-8000-000000000003';
  open_item uuid := gen_random_uuid(); delivered_item uuid := gen_random_uuid();
  stock_count uuid := gen_random_uuid(); run uuid := gen_random_uuid();
  payment uuid := gen_random_uuid(); returned uuid := gen_random_uuid();
begin
  insert into public.categories values (category,'Sentetik kategori',true);
  insert into public.warehouses(id,name) values (wh,'Tek sentetik depo');
  insert into public.vehicles values (vehicle,'TEST-ARAC-01',true,'Gerçek plaka değildir.');
  insert into public.products(id,sku,name,category_id,package_label,base_unit,min_quantity,unit_price_kurus) values
    (product_a,'TEST-A','Sentetik Ürün A',category,'Test paketi','adet',1,10000),
    (product_b,'TEST-B','Sentetik Ürün B',category,'Test ambalajı','kg',1,20000);
  insert into public.product_units(id,product_id,unit_name,conversion_to_base) values
    (unit_a,product_a,'adet',1), (unit_b,product_b,'paket',0.25),
    (gen_random_uuid(),product_a,'koli',12);
  insert into public.product_price_history(product_id,old_price_kurus,new_price_kurus,changed_by,reason,operation_key)
    values (product_a,9000,10000,manager,'Sentetik geçmiş örneği',gen_random_uuid());
  -- Inactive zero threshold/rate tests structure; no live discount policy.
  insert into public.pricing_rules values (rule,'SENTETİK PASİF KURAL',0,0,false);
  insert into public.pricing_proposals(customer_id,quarter_start,net_order_total_kurus,pricing_rule_id,proposed_discount_rate,status)
    values (customer_a,'2026-07-01',0,rule,0,'pending');
  insert into public.customer_pricing(customer_id,discount_rate,source,effective_from)
    values (customer_a,0,'synthetic_fixture','2026-10-01');
  insert into public.orders(id,customer_id,created_by,source,status,payment_status,
    subtotal_kurus,discount_total_kurus,total_kurus,operation_key) values
    (open_order,customer_a,sales,'sales_operator','picking','not_due',40000,0,40000,gen_random_uuid()),
    (delivered_order,customer_b,sales,'sales_operator','delivered','partial',20000,0,20000,gen_random_uuid()),
    (draft_order,customer_a,sales,'sales_operator','draft','not_due',0,0,0,gen_random_uuid());
  update public.orders set delivered_at='2026-10-01 12:00:00+03', payment_due_days_snapshot=7,
    due_date='2026-10-08 12:00:00+03' where id=delivered_order;
  insert into public.order_items(id,order_id,product_id,product_unit_id,unit,conversion_to_base_snapshot,
    quantity,picked_qty,unit_price_kurus,discount_rate_snapshot,final_unit_price_kurus,line_total_kurus) values
    (open_item,open_order,product_a,unit_a,'adet',1,4,1,10000,0,10000,40000),
    (delivered_item,delivered_order,product_a,unit_a,'adet',1,2,2,10000,0,10000,20000);
  insert into public.order_status_history(order_id,from_status,to_status,changed_by,reason,operation_key) values
    (open_order,null,'submitted',sales,'Sentetik başlangıç',gen_random_uuid()),
    (open_order,'submitted','picking',warehouse_user,'Sentetik kısmi toplama',gen_random_uuid());
  insert into public.order_approvals(order_id,reason,requested_by,status)
    values (draft_order,'Sentetik özel işlem inceleme örneği; sipariş henüz taslak',sales,'pending');
  insert into public.order_change_requests(order_id,type,requested_by,reason,status)
    values (open_order,'cancel',sales,'Sentetik iptal talebi','pending');
  insert into public.alternative_offers(order_item_id,offered_product_id,offered_unit_id,offered_qty,status,created_by)
    values (open_item,product_b,unit_b,1,'pending',sales);
  insert into public.inventory values (wh,product_a,97,3,default),(wh,product_b,0,0,default);
  insert into public.stock_counts(id,warehouse_id,created_by,status,reason)
    values (stock_count,wh,warehouse_user,'pending','Sentetik sayım; onay verilmedi');
  insert into public.stock_count_items(stock_count_id,product_id,system_qty,counted_qty,reason)
    values (stock_count,product_a,97,96,'Sentetik fark; stok henüz düzeltilmedi');
  insert into public.inventory_movements(warehouse_id,product_id,type,quantity,physical_delta,reserved_delta,order_item_id,created_by,operation_key) values
    (wh,product_a,'received',100,100,0,null,warehouse_user,gen_random_uuid()),
    (wh,product_a,'reserved',4,0,4,open_item,sales,gen_random_uuid()),
    (wh,product_a,'picked',1,-1,-1,open_item,warehouse_user,gen_random_uuid()),
    (wh,product_a,'reserved',2,0,2,delivered_item,sales,gen_random_uuid()),
    (wh,product_a,'picked',2,-2,-2,delivered_item,warehouse_user,gen_random_uuid());
  insert into public.delivery_runs(id,vehicle_id,primary_driver_id,status,started_at,ended_at)
    values (run,vehicle,driver,'completed','2026-10-01 09:00:00+03','2026-10-01 13:00:00+03');
  insert into public.delivery_stops(run_id,order_id,sequence,status,assigned_by,assigned_at,completed_at,closed_at,closed_by,close_reason)
    values (run,delivered_order,1,'completed',manager,'2026-10-01 08:00:00+03',
      '2026-10-01 12:00:00+03','2026-10-01 12:00:00+03',driver,'Sentetik tamamlanmış durak');
  insert into public.delivery_confirmations(order_id,event_type,driver_confirmed,customer_confirmed,finalizes_delivery,performed_by,operation_key) values
    (delivered_order,'driver',true,false,false,driver,gen_random_uuid()),
    (delivered_order,'customer',false,true,true,'30000000-0000-4000-8000-000000000008',gen_random_uuid());
  insert into public.order_returns(id,order_id,created_by,reason)
    values (returned,delivered_order,manager,'Sentetik, henüz onaysız iade talebi');
  insert into public.order_return_items values (returned,delivered_order,delivered_item,1,10000);
  insert into public.payments(id,order_id,payment_amount_kurus,method,collector_user_id,collected_at,verification_status,note,operation_key)
    values (payment,delivered_order,5000,'cash',sales,'2026-10-01 12:30:00+03','recorded','Sentetik kısmi ödeme',gen_random_uuid());
  insert into public.ratings(order_id,customer_id,driver_id,score,comment)
    values (delivered_order,customer_b,driver,4,'Sentetik puan');
  insert into public.employee_salary_records(employee_id,period,salary_kurus,bonus_kurus,created_by)
    values (sales,'2026-10-01',100,0,owner_user);
  insert into public.notifications(user_id,type,title,body,entity_type,entity_id)
    values ('30000000-0000-4000-8000-000000000008','order_delivered','Sentetik bildirim',
      'Push gönderilmez.','order',delivered_order);
  insert into public.audit_logs(actor_id,action,entity_type,entity_id,operation_key)
    select changed_by,'price_changed','product',product_id,operation_key from public.product_price_history;
  -- app_settings, driver_locations and payment_adjustments intentionally empty:
  -- no invented default due date, location history or fictitious correction.
end;
$$;
commit;
