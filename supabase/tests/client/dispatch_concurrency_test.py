"""Disposable local Docker DB; reset before and after. No credential access.

Uses two real connections and the existing pg_stat_activity barrier harness.
"""
import json
import sys
import uuid

sys.dont_write_bytecode = True
from inventory_concurrency_test import auth, overlap, run


def rpc(action, data, key=None):
    return f"select public.dispatch_action('{action}','{json.dumps(data)}','{key or uuid.uuid4()}');"


def rejected(sql):
    return "do $test$ begin begin " + sql.replace('select public.', 'perform public.') + " raise exception 'Unexpected dispatch success'; exception when check_violation then null; end; end $test$;"


def main():
    assert run("select count(*) from public.delivery_runs where dispatch_managed;") == '0', 'Fresh reset required'
    driver = '30000000-0000-4000-8000-000000000005'
    assistant = '30000000-0000-4000-8000-000000000009'
    other = '30000000-0000-4000-8000-000000000010'
    for identity in [assistant, other]:
        run(f"insert into auth.users(id,email) values('{identity}','{identity}@example.invalid');"
            f"insert into public.profiles(id,role,name) values('{identity}','driver','Synthetic race driver');")
    v1, v2 = str(uuid.uuid4()), str(uuid.uuid4())
    run(f"insert into public.vehicles(id,plate) values('{v1}','RACE-1'),('{v2}','RACE-2');")
    payload = {'vehicle_id': v1, 'primary_id': driver, 'assistant_id': assistant}
    a, _ = overlap(auth(6) + rpc('create_run', payload),
                   auth(7) + rejected(rpc('create_run', {'vehicle_id': v1, 'primary_id': other})))
    run1 = a[0]['id']
    assert run(f"select count(*) from public.delivery_runs where vehicle_id='{v1}' and ended_at is null;") == '1'
    print('PASS 1: concurrent vehicle allocation cannot create two open runs')

    overlap(auth(6) + rpc('vehicle', {'id': v2, 'plate': 'RACE-2', 'active': True}),
            auth(7) + rejected(rpc('create_run', {'vehicle_id': v2, 'primary_id': assistant})))
    assert run(f"select count(*) from public.delivery_runs where primary_driver_id='{assistant}' and ended_at is null;") == '0'
    print('PASS 2: assistant also occupies the primary driver resource slot')

    key = uuid.uuid4()
    create = rpc('create_run', {'vehicle_id': v2, 'primary_id': other}, key)
    a, b = overlap(auth(6) + create, auth(6) + create)
    assert a == b
    run2 = a[0]['id']
    assert run(f"select count(*) from public.delivery_runs where vehicle_id='{v2}' and ended_at is null;") == '1'
    print('PASS 3: concurrent same-key run creation is idempotent')

    unit = run("select u.id from public.product_units u join public.products p on p.id=u.product_id where p.sku='TEST-A' and u.unit_name='adet';")
    customer = '31000000-0000-4000-8000-000000000001'
    cart = json.dumps([{'unit_id': unit, 'quantity': 4}])
    result = json.loads(run('begin;' + auth(1) + f"select public.checkout_cart('{customer}','{cart}',public.quote_cart('{customer}','{cart}'),'{uuid.uuid4()}');commit;"))
    order = result['order_id']
    run('begin;' + auth(3) + f"select public.warehouse_order_action('{order}','start',null,null,'{uuid.uuid4()}');commit;")
    item = run(f"select id from public.order_items where order_id='{order}';")
    run('begin;' + auth(3) + f"select public.warehouse_order_action('{order}','pick','{item}',4,'{uuid.uuid4()}');commit;")
    load = auth(3) + f"select public.warehouse_order_action('{order}','load',null,null,'{uuid.uuid4()}');"
    a, b = overlap(auth(6) + rpc('assign', {'run_id': run1, 'order_id': order}), load)
    assert b[0]['status'] == 'loaded'
    print('PASS 4: load waits for assignment and sees committed stop without deadlock')

    # A second real order avoids reusing a completed load receipt as a new action.
    result = json.loads(run('begin;' + auth(1) + f"select public.checkout_cart('{customer}','{cart}',public.quote_cart('{customer}','{cart}'),'{uuid.uuid4()}');commit;"))
    order = result['order_id']
    run('begin;' + auth(3) + f"select public.warehouse_order_action('{order}','start',null,null,'{uuid.uuid4()}');commit;")
    item = run(f"select id from public.order_items where order_id='{order}';")
    run('begin;' + auth(3) + f"select public.warehouse_order_action('{order}','pick','{item}',4,'{uuid.uuid4()}');commit;")
    run('begin;' + auth(6) + rpc('assign', {'run_id': run1, 'order_id': order}) + 'commit;')
    load = auth(3) + f"select public.warehouse_order_action('{order}','load',null,null,'{uuid.uuid4()}');"
    overlap(load, auth(6) + rejected(rpc('assign', {'run_id': run2, 'order_id': order, 'reason': 'Race fixture'})))
    assert run(f"select run_id from public.delivery_stops where order_id='{order}' and closed_at is null;") == run1
    print('PASS 5: committed loading blocks concurrent reassignment')

    key = uuid.uuid4()
    depart = auth(9) + rpc('depart', {'run_id': run1}, key)
    a, b = overlap(depart, depart)
    assert a == b and a[0]['status'] == 'in_progress'
    assert run(f"select count(*) from public.order_status_history where order_id='{order}' and to_status='out_for_delivery';") == '1'
    print('PASS 6: concurrent assistant departure creates exactly one order transition')
    print('6/6 PASS; reset --local now removes committed synthetic fixtures')


if __name__ == '__main__':
    main()
