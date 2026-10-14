// Phase 16: real local Auth/PostgREST, all seven roles in one business chain.
// No direct SQL setup or state transition shortcuts. Reset before and after.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:peksen_gida/features/products/presentation/price_page.dart'
    show newOperationKey;

void main() {
  test('Seven real roles: checkout → picking → dispatch → delivery → collection → report', () async {
    final url = Platform.environment['PEKSEN_AUTH_TEST_URL'];
    final key = Platform.environment['PEKSEN_AUTH_TEST_KEY'];
    final password = Platform.environment['PEKSEN_AUTH_TEST_INPUT'];
    if (url != 'http://127.0.0.1:55321' || key == null || password == null) {
      throw TestFailure('Use local auth runner.');
    }
    var stage = 'login';
    Future<SupabaseClient> login(String account) async {
      final c = SupabaseClient(
        url!,
        key,
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      addTearDown(c.dispose);
      await c.auth.signInWithPassword(
        email: '$account@peksen.invalid',
        password: password,
      );
      return c;
    }

    Future<void> denied(Future<dynamic> operation) async => expectLater(
      operation,
      throwsA(
        isA<PostgrestException>().having((e) => e.code, 'SQLSTATE', '42501'),
      ),
    );
    try {
      final customer = await login('customer.a'),
          sales = await login('sales'),
          warehouse = await login('warehouse'),
          accounting = await login('accounting'),
          driver = await login('driver'),
          manager = await login('manager'),
          owner = await login('owner');
      final otherCustomer = await login('customer.b');
      const customerId = '31000000-0000-4000-8000-000000000001';
      const salesId = '30000000-0000-4000-8000-000000000002';
      const driverId = '30000000-0000-4000-8000-000000000005';
      stage = 'assignment and role boundaries';
      await denied(
        sales.rpc('customer_catalog', params: {'target_customer': customerId}),
      );
      await manager.rpc(
        'assign_customer_sales',
        params: {'target_customer': customerId, 'sales_user': salesId},
      );
      await owner.rpc(
        'set_customer_credit_limit',
        params: {
          'target_customer': customerId,
          'limit_kurus': 10000000,
          'reason': 'Synthetic E2E limit',
          'request_key': newOperationKey(),
        },
      );
      for (final actor in [
        customer,
        sales,
        warehouse,
        accounting,
        driver,
        manager,
      ]) {
        await denied(
          actor.rpc(
            'owner_salary_workspace',
            params: {'target_month': '2026-10-01'},
          ),
        );
        expect(
          await actor.from('employee_salary_records').select('id'),
          isEmpty,
        );
      }
      await sales.auth.updateUser(UserAttributes(data: {'role': 'owner'}));
      await sales.auth.refreshSession();
      await denied(sales.rpc('owner_audit_page'));
      expect(
        await warehouse.from('products').select('unit_price_kurus'),
        isEmpty,
      );
      await denied(
        accounting.rpc(
          'change_product_price',
          params: {
            'target_product': '33000000-0000-4000-8000-000000000001',
            'expected_price': 10000,
            'new_price': 1,
            'change_reason': 'Denied',
            'request_key': newOperationKey(),
          },
        ),
      );
      stage = 'customer and sales quote';
      final catalog = await customer.rpc(
        'customer_catalog',
        params: {'target_customer': customerId},
      ) as List;
      final product = catalog.cast<Map>().firstWhere(
        (p) => p['sku'] == 'TEST-A',
      );
      final unit = (product['units'] as List).cast<Map>().firstWhere(
        (u) => u['name'] == 'adet',
      )['id'];
      final items = [
        {'unit_id': unit, 'quantity': 4},
      ];
      final quote = await customer.rpc(
        'quote_cart',
        params: {'target_customer': customerId, 'items': items},
      );
      expect(
        await sales.rpc(
          'quote_cart',
          params: {'target_customer': customerId, 'items': items},
        ),
        quote,
      );
      await denied(
        otherCustomer.rpc(
          'quote_cart',
          params: {'target_customer': customerId, 'items': items},
        ),
      );
      stage = 'checkout replay';
      final checkout = {
        'target_customer': customerId,
        'items': items,
        'accepted_quote': quote,
        'request_key': newOperationKey(),
      };
      final submitted =
          await customer.rpc('checkout_cart', params: checkout) as Map;
      expect(submitted['status'], 'submitted');
      expect(await customer.rpc('checkout_cart', params: checkout), submitted);
      final order = submitted['order_id'] as String;
      expect(
        await otherCustomer.from('orders').select('id').eq('id', order),
        isEmpty,
      );
      await denied(
        customer.from('orders').update({'status': 'delivered'}).eq('id', order),
      );
      stage = 'sales checkout and cancellation';
      final salesQuote = await sales.rpc(
        'quote_cart',
        params: {'target_customer': customerId, 'items': items},
      );
      final salesOrder = await sales.rpc(
        'checkout_cart',
        params: {
          'target_customer': customerId,
          'items': items,
          'accepted_quote': salesQuote,
          'request_key': newOperationKey(),
        },
      ) as Map;
      final cancel = {
        'target_order': salesOrder['order_id'],
        'requested_action': 'cancel_submitted',
        'request_reason': 'Synthetic cancellation',
        'request_key': newOperationKey(),
      };
      await sales.rpc('request_order_action', params: cancel);
      await sales.rpc('request_order_action', params: cancel);
      expect(
        (await manager
            .from('orders')
            .select('source,status,created_by')
            .eq('id', salesOrder['order_id'])
            .single())['status'],
        'cancelled',
      );
      stage = 'warehouse';
      Future<dynamic> wh(String action, {String? item, int? quantity}) =>
          warehouse.rpc(
            'warehouse_order_action',
            params: {
              'target_order': order,
              'action': action,
              'target_item': item,
              'pick_quantity': quantity,
              'request_key': newOperationKey(),
            },
          );
      final prep = await warehouse.rpc(
        'warehouse_workspace',
        params: {'section': 'preparation'},
      ) as List;
      final preparation = prep.cast<Map>().firstWhere(
        (p) => p['order_id'] == order,
      );
      expect(preparation.keys.toSet(), {'order_id', 'status', 'items'});
      final item = (preparation['items'] as List).single as Map;
      expect(item.containsKey('line_total_kurus'), isFalse);
      await wh('start');
      await wh('pick', item: item['id'] as String, quantity: 4);
      stage = 'manager assignment and driver departure';
      Future<Map> dispatch(
        SupabaseClient c,
        String action,
        Map<String, dynamic> data,
      ) async => await c.rpc(
        'dispatch_action',
        params: {
          'action': action,
          'data': data,
          'request_key': newOperationKey(),
        },
      ) as Map;
      final vehicle = await dispatch(manager, 'vehicle', {
        'plate': 'PHASE16-E2E',
        'active': true,
      });
      final run = await dispatch(manager, 'create_run', {
        'vehicle_id': vehicle['id'],
        'primary_id': driverId,
      });
      await dispatch(manager, 'assign', {
        'run_id': run['id'],
        'order_id': order,
      });
      await wh('load');
      await dispatch(driver, 'depart', {'run_id': run['id']});
      stage = 'delivery finalization';
      Future<Map> delivery(
        SupabaseClient c,
        String action, [
        Map<String, dynamic> extra = const {},
      ]) async => await c.rpc(
        'delivery_action',
        params: {
          'action': action,
          'data': {'order_id': order, ...extra},
          'request_key': newOperationKey(),
        },
      ) as Map;
      expect(
        (await delivery(driver, 'driver_confirm'))['status'],
        'delivery_pending_confirmation',
      );
      await denied(
        otherCustomer.rpc(
          'delivery_action',
          params: {
            'action': 'customer_confirm',
            'data': {'order_id': order},
            'request_key': newOperationKey(),
          },
        ),
      );
      expect(
        (await delivery(customer, 'customer_confirm'))['status'],
        'delivered',
      );
      await delivery(customer, 'rate', {
        'score': 5,
        'reason_codes': [],
        'comment': 'Synthetic E2E',
      });
      expect(await driver.from('ratings').select('id'), isEmpty);
      stage = 'collection and verification';
      final paymentArgs = {
        'target_order': order,
        'amount_kurus': 1000,
        'payment_method': 'cash',
        'payment_note': 'Synthetic E2E',
        'request_key': newOperationKey(),
      };
      await denied(driver.rpc('record_payment', params: paymentArgs));
      final payment =
          await sales.rpc('record_payment', params: paymentArgs) as Map;
      expect(await sales.rpc('record_payment', params: paymentArgs), payment);
      final verify = {
        'target_payment': payment['payment_id'],
        'request_key': newOperationKey(),
      };
      expect(
        (await accounting.rpc('verify_payment', params: verify)
            as Map)['status'],
        'verified',
      );
      final finance = await accounting.rpc(
        'finance_workspace',
        params: {'section': 'orders'},
      ) as List;
      final balance = finance.cast<Map>().firstWhere((r) => r['id'] == order);
      expect(
        BigInt.parse(balance['balance_kurus'] as String),
        BigInt.parse((quote as Map)['total_kurus'] as String) -
            BigInt.from(1000),
      );
      await denied(
        accounting
            .from('payments')
            .update({'payment_amount_kurus': 0})
            .eq('id', payment['payment_id']),
      );
      stage = 'owner report, salary and revoked sales';
      final report = await manager.rpc(
        'management_report',
        params: {'start_day': '2026-01-01', 'end_day': '2026-12-31'},
      ) as Map;
      expect((report['ratings'] as List).isNotEmpty, isTrue);
      await owner.rpc(
        'save_salary',
        params: {
          'target_employee': salesId,
          'target_month': '2097-01-01',
          'salary_kurus': '1',
          'bonus_kurus': '0',
          'reason': 'Synthetic E2E',
          'expected_revision': -1,
          'request_key': newOperationKey(),
        },
      );
      expect(
        (await owner.rpc(
          'owner_salary_workspace',
          params: {'target_month': '2097-01-01'},
        ) as Map)['records'],
        hasLength(1),
      );
      await manager.rpc(
        'assign_customer_sales',
        params: {'target_customer': customerId, 'sales_user': null},
      );
      await denied(
        sales.rpc(
          'quote_cart',
          params: {'target_customer': customerId, 'items': items},
        ),
      );
      expect(await sales.from('orders').select('id').eq('id', order), isEmpty);
      expect(
        await accounting.rpc(
          'finance_workspace',
          params: {'section': 'orders'},
        ),
        isEmpty,
      );
      await customer.auth.signOut(scope: SignOutScope.local);
      await denied(
        customer.rpc(
          'customer_catalog',
          params: {'target_customer': customerId},
        ),
      );
    } catch (_) {
      throw TestFailure(
        'Seven-role local E2E failed at $stage; sensitive details suppressed.',
      );
    }
  });
}
