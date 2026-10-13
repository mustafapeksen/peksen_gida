"""Local committed synthetic fixtures; two real connections, no credentials.
Run after reset and reset again after acceptance to remove fixtures.
"""
import json
import sys
import uuid

sys.dont_write_bytecode = True
from inventory_concurrency_test import auth, overlap, run


def main():
    order, vehicle, delivery_run = [str(uuid.uuid4()) for _ in range(3)]
    run(f"""
      insert into orders(id,customer_id,created_by,source,status,payment_status,
        subtotal_kurus,discount_total_kurus,total_kurus,operation_key)
      values('{order}','31000000-0000-4000-8000-000000000001',
        '30000000-0000-4000-8000-000000000001','customer_app','out_for_delivery','not_due',100,0,100,gen_random_uuid());
      insert into vehicles(id,plate) values('{vehicle}','RACE-DELIVERY');
      insert into delivery_runs(id,vehicle_id,primary_driver_id,status,started_at,dispatch_managed)
        values('{delivery_run}','{vehicle}','30000000-0000-4000-8000-000000000005','in_progress',now(),true);
      insert into delivery_stops(run_id,order_id,sequence,status,assigned_by)
        values('{delivery_run}','{order}',1,'assigned','30000000-0000-4000-8000-000000000006');
    """)

    def action(name, extra=None, key=None):
        data = json.dumps({'order_id': order, **(extra or {})})
        return f"select public.delivery_action('{name}','{data}','{key or uuid.uuid4()}');"

    def reject(sql, error):
        return "do $test$ begin begin " + sql.replace('select public.', 'perform public.') + f" raise exception 'Unexpected success'; exception when {error} then null; end; end $test$;"

    sql = auth(5) + action('driver_confirm', key=uuid.uuid4())
    a, b = overlap(sql, sql)
    assert a == b
    assert run(f"select count(*) from delivery_confirmations where order_id='{order}';") == '1'
    print('PASS 1: concurrent identical Driver requests create one fact and receipt')
    overlap(auth(1) + action('customer_confirm'), auth(6) + reject(action('resolve', {'reason': 'Concurrent exception'}), 'check_violation'))
    assert run(f"select count(*) from delivery_confirmations where order_id='{order}' and finalizes_delivery;") == '1'
    assert run(f"select count(*) from order_status_history where order_id='{order}' and to_status='delivered';") == '1'
    print('PASS 2: concurrent Customer/Manager finalization creates one closure/history')
    overlap(auth(1) + action('rate', {'score': 5}), auth(1) + reject(action('rate', {'score': 1}), 'unique_violation'))
    assert run(f"select count(*) from ratings where order_id='{order}';") == '1'
    print('PASS 3: concurrent ratings create exactly one immutable score')
    run('begin;' + auth(6) + f"select dispatch_action('complete','{{\"run_id\":\"{delivery_run}\"}}','{uuid.uuid4()}'); commit;")


if __name__ == '__main__':
    main()
