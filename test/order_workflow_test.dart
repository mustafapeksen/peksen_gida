import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peksen_gida/app.dart';
import 'package:peksen_gida/core/routing/app_router.dart';
import 'package:peksen_gida/features/auth/domain/account_repository.dart';
import 'package:peksen_gida/features/auth/presentation/auth_providers.dart';
import 'package:peksen_gida/features/customer/presentation/shop_providers.dart';
import 'package:peksen_gida/features/orders/data/order_workflow_repository.dart';

import 'customer_checkout_test.dart' show FakeShop;
import 'products_test.dart' show tapText;

class WorkflowFake extends FakeShop implements OrderWorkflowRepository {
  String status = 'submitted';
  bool failRead = false, failSend = false;
  Completer<void>? waitRead;
  final calls = <List<String>>[];
  final requests = <Map<String, dynamic>>[];
  @override
  Future<List<Map<String, dynamic>>> orders(String customerId) async => [
    {
      'id': 'order-test',
      'status': status,
      'total_kurus': 10000,
      'order_items': <dynamic>[],
    },
  ];
  @override
  Future<Map<String, dynamic>> state(String orderId) async {
    await waitRead?.future;
    if (failRead) throw StateError('private backend details');
    return {'status': status, 'requests': requests, 'history': <dynamic>[]};
  }

  @override
  Future<void> act(
    String orderId,
    String action,
    String reason,
    String key,
  ) async {
    calls.add([orderId, action, reason, key]);
    if (failSend) throw StateError('private backend details');
    if (action == 'cancel_submitted') {
      status = 'cancelled';
    } else {
      requests.add({
        'id': 'r',
        'type': action == 'request_cancel' ? 'cancel' : 'change',
        'status': 'pending',
        'reason': reason,
      });
    }
  }
}

Future<void> mountWorkflow(WidgetTester tester, WorkflowFake fake) async {
  final router = createAppRouter(
    previewEnabled: true,
    initialLocation: '/account/shop/orders',
    isSignedIn: () => true,
  );
  final container = ProviderContainer(
    overrides: [
      appRouterProvider.overrideWithValue(router),
      accountProfileProvider.overrideWith(
        (_) async => const AccountProfile(
          id: 'test',
          name: 'Test',
          role: AccountRole.customer,
        ),
      ),
      shopRepositoryProvider.overrideWith((_) async => fake),
      orderWorkflowRepositoryProvider.overrideWith((_) async => fake),
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
  await tester.tap(find.byType(ExpansionTile));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets(
    'Cancellation requires reason and explicit confirmation; result refreshes',
    (tester) async {
      final fake = WorkflowFake();
      await mountWorkflow(tester, fake);
      await tapText(tester, 'Siparişi iptal et');
      await tapText(tester, 'Onayla');
      expect(fake.calls, isEmpty);
      expect(find.text('Gerekçe yazın.'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Yanlış sipariş');
      await tapText(tester, 'Onayla');
      expect(fake.calls.single.take(3), [
        'order-test',
        'cancel_submitted',
        'Yanlış sipariş',
      ]);
      expect(find.text('İptal edildi'), findsOneWidget);
      expect(find.text('Siparişi iptal et'), findsNothing);
    },
  );
  testWidgets('Uncertain retry retains immutable payload and operation key', (
    tester,
  ) async {
    final fake = WorkflowFake()..failSend = true;
    await mountWorkflow(tester, fake);
    await tapText(tester, 'Siparişi iptal et');
    await tester.enterText(find.byType(TextField), 'Tek iptal');
    await tapText(tester, 'Onayla');
    expect(find.textContaining('İşlem doğrulanamadı'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isTrue);
    fake.failSend = false;
    await tapText(tester, 'Aynı isteği yeniden dene');
    expect(fake.calls.length, 2);
    expect(fake.calls[0], fake.calls[1]);
    expect(find.text('İptal edildi'), findsOneWidget);
  });
  testWidgets('Change request records intent and keeps order submitted', (
    tester,
  ) async {
    final fake = WorkflowFake();
    await mountWorkflow(tester, fake);
    await tapText(tester, 'Değişiklik talebi oluştur');
    await tester.enterText(find.byType(TextField), 'Miktar değişsin');
    await tapText(tester, 'Onayla');
    expect(fake.status, 'submitted');
    expect(fake.calls.single[1], 'request_change');
    expect(find.text('Değişiklik · Bekliyor'), findsOneWidget);
    expect(find.text('Miktar değişsin'), findsOneWidget);
  });
  testWidgets(
    'Picking offers request only; delivered offers neither operation',
    (tester) async {
      final fake = WorkflowFake()..status = 'picking';
      await mountWorkflow(tester, fake);
      expect(find.text('Siparişi iptal et'), findsNothing);
      await tapText(tester, 'İptal talebi oluştur');
      await tester.enterText(find.byType(TextField), 'İptal değerlendirmesi');
      await tapText(tester, 'Onayla');
      expect(fake.status, 'picking');
      expect(fake.calls.single[1], 'request_cancel');
    },
  );
  testWidgets('Delivered order has no edit or cancellation action', (
    tester,
  ) async {
    await mountWorkflow(tester, WorkflowFake()..status = 'delivered');
    expect(find.text('Siparişi iptal et'), findsNothing);
    expect(find.text('İptal talebi oluştur'), findsNothing);
    expect(find.text('Değişiklik talebi oluştur'), findsNothing);
  });
  testWidgets(
    'Workflow failure is recoverable and does not expose backend details',
    (tester) async {
      final fake = WorkflowFake()..failRead = true;
      await mountWorkflow(tester, fake);
      expect(find.textContaining('private backend'), findsNothing);
      fake.failRead = false;
      await tapText(tester, 'Sipariş işlemlerini yeniden yükle');
      expect(find.text('Henüz talep yok.'), findsOneWidget);
    },
  );
  testWidgets(
    'Workflow loading does not show actions before authorization response',
    (tester) async {
      final fake = WorkflowFake()..waitRead = Completer<void>();
      await mountWorkflow(tester, fake);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Siparişi iptal et'), findsNothing);
      fake.waitRead!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Siparişi iptal et'), findsOneWidget);
    },
  );
  testWidgets(
    'Small screen with keyboard allows reason and back dismisses without mutation',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      final fake = WorkflowFake();
      await mountWorkflow(tester, fake);
      await tapText(tester, 'Siparişi iptal et');
      tester.view.viewInsets = const FakeViewPadding(bottom: 240);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'Dar ekran');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(fake.calls, isEmpty);
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
