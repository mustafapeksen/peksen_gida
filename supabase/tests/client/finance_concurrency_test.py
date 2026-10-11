"""Synthetic local Docker DB only; reset before AND after this test.

Reuse the existing two-connection/pg_stat_activity barrier harness. No keys,
passwords, remote targets or application auth state are read or written.
"""
import json
import uuid
import sys

sys.dont_write_bytecode = True

from inventory_concurrency_test import auth, overlap, run


def main():
    order = '35000000-0000-4000-8000-000000000002'
    customer = '31000000-0000-4000-8000-000000000001'
    assert run(f"select private.order_balance('{order}');") == '15000', 'Fresh reset required'
    run("update public.customers set assigned_sales_operator_id='30000000-0000-4000-8000-000000000002';")

    def collect(amount, key):
        return f"select public.record_payment('{order}',{amount},'cash','Synthetic concurrency','{key}');"

    first = auth(2) + collect(10000, uuid.uuid4())
    second = auth(2) + f"""do $test$ begin
      begin perform public.record_payment('{order}',10000,'pos','Synthetic concurrency','{uuid.uuid4()}');
        raise exception 'Concurrent overpayment unexpectedly succeeded';
      exception when check_violation then null; end;
    end $test$;"""
    overlap(first, second)
    assert run(f"select private.order_balance('{order}');") == '5000'
    assert run(f"select count(*) from public.payments where order_id='{order}';") == '2'
    print('PASS 1: different-key concurrent collections cannot overpay')

    key = uuid.uuid4()
    a, b = overlap(auth(2) + collect(1000, key), auth(2) + collect(1000, key))
    assert a == b
    assert run(f"select count(*) from public.payments where operation_key='{key}';") == '1'
    assert run(f"select private.order_balance('{order}');") == '4000'
    print('PASS 2: same-key concurrent collection creates one payment and one reduction')

    run('begin;' + auth(7) + f"select public.set_customer_credit_limit('{customer}',0,'Synthetic zero','{uuid.uuid4()}');commit;")
    unit = run("select u.id from public.product_units u join public.products p on p.id=u.product_id where p.sku='TEST-A' and u.unit_name='adet';")
    cart = json.dumps([{'unit_id': unit, 'quantity': 4}])
    result = json.loads(run('begin;' + auth(1) + f"select public.checkout_cart('{customer}','{cart}',public.quote_cart('{customer}','{cart}'),'{uuid.uuid4()}');commit;"))
    assert result['approval_cause'] == 'credit'
    approval = run(f"select id from public.order_approvals where order_id='{result['order_id']}';")
    key = uuid.uuid4()
    decision = auth(7) + f"select public.decide_credit_approval('{approval}',true,'Synthetic approval','{key}');"
    a, b = overlap(decision, decision)
    assert a == b and a[0]['status'] == 'submitted'
    assert run(f"select count(*) from public.inventory_movements where reference_id='{result['order_id']}';") == '1'
    assert run("select reserved_qty from public.inventory i join public.products p on p.id=i.product_id where p.sku='TEST-A';") == '7'
    print('PASS 3: concurrent credit approval reserves the stored snapshot once')
    print('3/3 PASS; reset --local now removes committed synthetic fixtures')


if __name__ == '__main__':
    main()
