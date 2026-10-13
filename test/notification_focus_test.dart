import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peksen_gida/app.dart';
import 'package:peksen_gida/core/routing/app_router.dart';
import 'package:peksen_gida/features/auth/domain/account_repository.dart';
import 'package:peksen_gida/features/auth/presentation/auth_providers.dart';
import 'package:peksen_gida/features/customer/presentation/shop_providers.dart';
import 'package:peksen_gida/features/customer/presentation/orders_page.dart';
import 'package:peksen_gida/features/inventory/data/inventory_repository.dart';
import 'package:peksen_gida/features/inventory/presentation/inventory_page.dart';
import 'package:peksen_gida/features/notifications/data/notification_repository.dart';
import 'package:peksen_gida/features/orders/data/order_workflow_repository.dart';
import 'package:peksen_gida/features/sales/domain/sales_repository.dart';
import 'package:peksen_gida/features/sales/presentation/sales_customers_page.dart';

import 'notifications_test.dart' show NotificationFake, notificationId;
import 'order_workflow_test.dart' show WorkflowFake;
import 'inventory_test.dart' show InventoryFake;
import 'sales_checkout_test.dart' show FakeSales;
import 'products_test.dart' show tapText;

const otherOrder = '14000000-0000-4000-8000-000000000002';

class FocusShop extends WorkflowFake {
  bool hidden = false;
  @override
  Future<List<Map<String, dynamic>>> orders(String customerId) async => [
    for (final id in [if (!hidden) notificationId, otherOrder])
      {
        'id': id,
        'status': 'submitted',
        'total_kurus': 10000,
        'order_items': <dynamic>[],
      },
  ];
}

Future<ProviderContainer> mountNotificationFocus(
  WidgetTester tester,
  AccountRole role, {
  NotificationFake? notice,
  FocusShop? shop,
  InventoryFake? inventory,
}) async {
  final fake = notice ?? NotificationFake();
  fake.route = role == AccountRole.warehouse
      ? '/account/inventory?order=$notificationId'
      : role == AccountRole.salesOperator
      ? '/account/sales/$notificationId/orders?order=$notificationId'
      : '/account/shop/orders?order=$notificationId';
  final workflow = shop ?? FocusShop();
  final stock = inventory ?? InventoryFake();
  if (inventory == null) {
    final template = stock.rows['preparation']!.single;
    stock.rows['preparation'] = [
      for (final id in [notificationId, otherOrder])
        {...template, 'order_id': id},
    ];
  }
  final sales = FakeSales()
    ..customers = [const SalesCustomer(notificationId, 'Test firma')];
  final router = createAppRouter(
    previewEnabled: true,
    initialLocation: '/account/notifications',
    isSignedIn: () => true,
  );
  final container = ProviderContainer(
    overrides: [
      appRouterProvider.overrideWithValue(router),
      accountProfileProvider.overrideWith(
        (_) async => AccountProfile(id: 'test', name: 'Test', role: role),
      ),
      notificationRepositoryProvider.overrideWith((_) async => fake),
      shopRepositoryProvider.overrideWith((_) async => workflow),
      orderWorkflowRepositoryProvider.overrideWith((_) async => workflow),
      inventoryRepositoryProvider.overrideWith((_) async => stock),
      salesRepositoryProvider.overrideWith((_) async => sales),
    ],
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    router.dispose();
  });
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const PeksenGidaApp(),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  test('Order query permits one UUID on approved internal paths only', () {
    for (final path in [
      '/account/shop/orders',
      '/account/inventory',
      '/account/sales/$notificationId/orders',
    ]) {
      expect(allowedNotificationRoute('$path?order=$notificationId'), isTrue);
      expect(
        allowedNotificationRoute(
          'https://evil.invalid$path?order=$notificationId',
        ),
        isFalse,
      );
      expect(
        allowedNotificationRoute(
          '$path?order=$notificationId&order=$otherOrder',
        ),
        isFalse,
      );
      expect(
        allowedNotificationRoute('$path?order=$notificationId#hidden'),
        isFalse,
      );
      expect(allowedNotificationRoute('$path?order=../admin'), isFalse);
    }
  });
  for (final role in [AccountRole.customer, AccountRole.salesOperator]) {
    testWidgets(
      '${role.id} notification opens only the selected expanded order',
      (tester) async {
        final notice = NotificationFake();
        await mountNotificationFocus(tester, role, notice: notice);
        await tapText(tester, 'Sipariş hazırlanıyor');
        expect(notice.opens, 1);
        expect(find.text('Sipariş detayı'), findsOneWidget);
        expect(find.byType(ExpansionTile), findsOneWidget);
        expect(find.textContaining(notificationId), findsOneWidget);
        expect(find.textContaining(otherOrder), findsNothing);
        expect(
          tester
              .widget<ExpansionTile>(find.byType(ExpansionTile))
              .initiallyExpanded,
          isTrue,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('Customer permission loss clears selected card on refresh', (
    tester,
  ) async {
    final shop = FocusShop();
    final container = await mountNotificationFocus(
      tester,
      AccountRole.customer,
      shop: shop,
    );
    await tapText(tester, 'Sipariş hazırlanıyor');
    expect(find.byType(ExpansionTile), findsOneWidget);
    shop.hidden = true;
    container.invalidate(customerOrdersProvider);
    await tester.pumpAndSettle();
    expect(find.byType(ExpansionTile), findsNothing);
    expect(
      find.text('Bu sipariş bulunamadı veya erişiminiz sona erdi.'),
      findsOneWidget,
    );
    expect(find.textContaining(otherOrder), findsNothing);
  });
  testWidgets('Warehouse notification selects preparation tab and one record', (
    tester,
  ) async {
    await mountNotificationFocus(tester, AccountRole.warehouse);
    await tapText(tester, 'Sipariş hazırlanıyor');
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      1,
    );
    expect(find.textContaining(notificationId), findsOneWidget);
    expect(find.textContaining(otherOrder), findsNothing);
    expect(find.text('Toplamayı başlat'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Warehouse missing target does not fall back to other preparation records',
    (tester) async {
      final inventory = InventoryFake();
      final container = await mountNotificationFocus(
        tester,
        AccountRole.warehouse,
        inventory: inventory,
      );
      await tapText(tester, 'Sipariş hazırlanıyor');
      expect(
        find.text(
          'Sipariş hazırlık kapsamında değil veya erişiminiz sona erdi.',
        ),
        findsOneWidget,
      );
      expect(find.text('Toplamayı başlat'), findsNothing);
      inventory.failRead = true;
      container.invalidate(inventoryRowsProvider);
      await tester.pumpAndSettle();
      expect(find.text('Depo kayıtları yüklenemedi.'), findsOneWidget);
      expect(find.text('Toplamayı başlat'), findsNothing);
    },
  );
  testWidgets('Revoked click never mounts a target workspace', (tester) async {
    final notice = NotificationFake()..denied = true;
    await mountNotificationFocus(
      tester,
      AccountRole.salesOperator,
      notice: notice,
    );
    await tapText(tester, 'Sipariş hazırlanıyor');
    expect(notice.opens, 1);
    expect(find.text('Sipariş detayı'), findsNothing);
    expect(find.textContaining('İşlem tamamlanamadı'), findsOneWidget);
  });
}
