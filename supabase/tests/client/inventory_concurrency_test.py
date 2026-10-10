"""Disposable LOCAL DB only; run after reset and reset again after this test.

Uses Docker's local Unix-socket psql, no credential files/tokens. Tests committed
synthetic fixtures because separate sessions cannot see rollback-only fixtures.
No remote target/config override is accepted. Python standard library only.
"""
import json
import subprocess
import time
import uuid

CONTAINER = 'supabase_db_peksen_gida_phase3_local'
COMMAND = ['docker', 'exec', '-i', CONTAINER, 'psql', '-X', '-qAt', '-v', 'ON_ERROR_STOP=1', '-U', 'postgres', '-d', 'postgres']


def run(sql):
    result = subprocess.run(COMMAND, input=sql, text=True, capture_output=True, timeout=40)
    if result.returncode:
        raise RuntimeError('Local SQL test failed: ' + result.stderr)
    return result.stdout.strip()


def worker(sql):
    process = subprocess.Popen(COMMAND, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    process.stdin.write(sql)
    process.stdin.close()
    process.stdin = None
    return process


def finish(process):
    out, err = process.communicate(timeout=40)
    if process.returncode:
        raise RuntimeError('Concurrent local SQL failed: ' + err)
    return [json.loads(line) for line in out.splitlines() if line.startswith('{')]


def wait_for_sleep():
    for _ in range(100):
        if run("select count(*) from pg_stat_activity where application_name='phase9_concurrency_first' and wait_event='PgSleep';") == '1':
            return
        time.sleep(0.05)
    raise RuntimeError('First session did not reach lock barrier')


def auth(suffix):
    return f"set local request.jwt.claim.sub='30000000-0000-4000-8000-{suffix:012d}'; set local role authenticated;"


def overlap(first, second):
    a = worker("begin; set local application_name='phase9_concurrency_first';" + first + 'select pg_sleep(3); commit;')
    try:
        wait_for_sleep()
        b = worker('begin;' + second + 'commit;')
        return finish(a), finish(b)
    finally:
        if a.poll() is None:
            a.kill()


def main():
    product, unit = run("select p.id||'|'||u.id from public.products p join public.product_units u on u.product_id=p.id where p.sku='TEST-A' and u.unit_name='adet';").split('|')
    before = json.loads(run(f"select jsonb_build_object('physical',physical_qty::text,'reserved',reserved_qty::text) from public.inventory where product_id='{product}';"))
    if before != {'physical': '97', 'reserved': '3'}:
        raise RuntimeError('Fresh local reset required; unexpected fixture balance')
    cart = json.dumps([{'unit_id': unit, 'quantity': 60}])

    def checkout(customer, key):
        return f"select public.checkout_cart('{customer}','{cart}',public.quote_cart('{customer}','{cart}'),'{key}');"

    customer_a = '31000000-0000-4000-8000-000000000001'
    customer_b = '31000000-0000-4000-8000-000000000002'
    first, second = overlap(auth(1) + checkout(customer_a, uuid.uuid4()), auth(8) + checkout(customer_b, uuid.uuid4()))
    assert first[0]['status'] == 'submitted', first
    assert second[0]['outcome'] == 'changed', second
    assert run(f"select reserved_qty from public.inventory where product_id='{product}';") == '63'
    print('PASS 1: concurrent customers cannot over-reserve; loser must reconfirm')
    # Explicitly submit the new quote. Shortage order must reserve nothing.
    result = json.loads(run('begin;' + auth(8) + checkout(customer_b, uuid.uuid4()) + 'commit;'))
    assert result['status'] == 'pending_approval', result
    assert run(f"select reserved_qty from public.inventory where product_id='{product}';") == '63'
    print('PASS 2: reconfirmed shortage order has zero new reservation')

    key = uuid.uuid4()
    receive = auth(3) + f"select public.receive_inventory('{unit}',0.125,'Concurrency fixture','{key}');"
    a, b = overlap(receive, receive)
    assert a == b
    assert run(f"select count(*) from public.inventory_movements where operation_key='{key}';") == '1'
    assert run(f"select physical_qty from public.inventory where product_id='{product}';") == '97.125'
    print('PASS 3: concurrent same-key receiving records one exact movement')

    order_id = first[0]['order_id']
    start = auth(3) + f"select public.warehouse_order_action('{order_id}','start',null,null,'{uuid.uuid4()}');"
    # Rejection is captured on purpose and asserted; any other error escapes.
    cancel = auth(1) + f"""do $test$ begin
      begin perform public.request_order_action('{order_id}','cancel_submitted','Race fixture','{uuid.uuid4()}');
        raise exception 'Cancellation unexpectedly succeeded';
      exception when check_violation then null; end;
    end $test$;"""
    a, _ = overlap(start, cancel)
    assert a[0]['status'] == 'picking'
    assert run(f"select status from public.orders where id='{order_id}';") == 'picking'
    assert run(f"select reserved_qty from public.inventory where product_id='{product}';") == '63'
    print('PASS 4: start versus cancel serializes without released reservation')
    print('4/4 PASS; reset --local now removes the committed synthetic test data')


if __name__ == '__main__':
    main()
