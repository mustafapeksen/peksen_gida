"""Phase 16 price/checkout race; disposable local DB, reset before and after."""
import json
import sys
import uuid

sys.dont_write_bytecode = True
from inventory_concurrency_test import auth, overlap, run


def main():
    product, unit, price = run("select p.id||'|'||u.id||'|'||p.unit_price_kurus from public.products p join public.product_units u on u.product_id=p.id where p.sku='TEST-A' and u.unit_name='adet';").split('|')
    price = int(price)
    customer = '31000000-0000-4000-8000-000000000001'
    cart = json.dumps([{'unit_id': unit, 'quantity': 4}])
    quote = run('begin;' + auth(1) + f"select public.quote_cart('{customer}','{cart}');commit;")
    before_orders = run('select count(*) from public.orders;')
    before_stock = run(f"select reserved_qty from public.inventory where product_id='{product}';")

    def change(old, new):
        return f"select public.change_product_price('{product}',{old},{new},'Synthetic price race','{uuid.uuid4()}');"

    def checkout(accepted):
        literal = accepted.replace("'", "''")
        return f"select public.checkout_cart('{customer}','{cart}','{literal}','{uuid.uuid4()}');"

    _, result = overlap(auth(6) + change(price, price + 100), auth(1) + checkout(quote))
    assert result[0]['outcome'] == 'changed'
    assert run('select count(*) from public.orders;') == before_orders
    assert run(f"select reserved_qty from public.inventory where product_id='{product}';") == before_stock
    print('PASS 1: checkout waiting on price lock re-quotes; no order or reservation')

    confirmed = json.loads(run('begin;' + auth(1) + checkout(json.dumps(result[0]['quote'])) + 'commit;'))
    assert confirmed['status'] == 'submitted'
    order = confirmed['order_id']
    snapshot = run(f"select exact_final_price_kurus_snapshot from public.order_items where order_id='{order}';")
    overlap(auth(6) + change(price + 100, price + 200), auth(1) + f"select to_jsonb(i) from public.order_items i where order_id='{order}';")
    assert run(f"select exact_final_price_kurus_snapshot from public.order_items where order_id='{order}';") == snapshot
    print('PASS 2: explicit reconfirmation creates order; later price change preserves snapshot')

    rejected = "do $test$ begin begin " + change(price + 200, price + 400).replace('select public.', 'perform public.') + "raise exception 'Stale price accepted'; exception when serialization_failure then null; end; end $test$;"
    overlap(auth(6) + change(price + 200, price + 300), auth(7) + rejected)
    assert run(f"select unit_price_kurus from public.products where id='{product}';") == str(price + 300)
    print('PASS 3: concurrent Manager/Owner stale price update rejected')
    print('3/3 PASS; reset --local removes committed synthetic records')


if __name__ == '__main__':
    main()
