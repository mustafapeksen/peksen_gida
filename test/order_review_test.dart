import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peksen_gida/app.dart';
import 'package:peksen_gida/core/routing/app_router.dart';
import 'package:peksen_gida/features/auth/domain/account_repository.dart';
import 'package:peksen_gida/features/auth/presentation/auth_providers.dart';
import 'package:peksen_gida/features/customer/presentation/shop_providers.dart';
import 'package:peksen_gida/features/orders/data/order_review_repository.dart';
import 'package:peksen_gida/features/sales/presentation/sales_customers_page.dart';

import 'customer_checkout_test.dart' show FakeShop;
import 'sales_checkout_test.dart' show FakeSales;
import 'products_test.dart' show tapText;
import 'order_workflow_test.dart' show WorkflowFake, mountWorkflow;

class ReviewFake implements OrderReviewRepository {
  bool failRead = false, failWrite = false;
  int reads = 0;
  Completer<void>? waiting;
  final calls = <List<Object>>[];
  final rows = <Map<String, dynamic>>[
    {
      'id': 'r',
      'order_id': 'o',
      'customer': 'Firma A',
      'order_status': 'submitted',
      'status': 'pending',
      'type': 'change',
      'reason': 'Müşteri niyeti',
      'decision_note': null,
    },
  ];
  final offers = <Map<String, dynamic>>[
    {
      'id': 'a',
      'item_id': 'i',
      'name': 'Alternatif ürün',
      'unit': 'adet',
      'quantity': 2,
      'status': 'pending',
    },
  ];
  String orderStatus = 'submitted';
  @override
  Future<List<Map<String, dynamic>>> requests() async {
    reads++;
    await waiting?.future;
    if (failRead) throw StateError('private');
    return rows;
  }

  @override
  Future<void> decide(
    String request,
    bool approve,
    String note,
    String key,
  ) async {
    calls.add([request, approve, note, key]);
    if (failWrite) throw StateError('private');
    rows.single['status'] = approve ? 'approved' : 'rejected';
    rows.single['decision_note'] = note;
  }

  @override
  Future<Map<String, dynamic>> alternatives(String order) async {
    await waiting?.future;
    if (failRead) throw StateError('private');
    return {
      'status': orderStatus,
      'items': [
        {'id': 'i', 'name': 'Eski ürün', 'quantity': 1, 'unit': 'adet'},
      ],
      'offers': offers,
    };
  }

  @override
  Future<void> propose(
    String item,
    String unit,
    int quantity,
    String key,
  ) async {
    calls.add([item, unit, quantity, key]);
    if (failWrite) throw StateError('private');
    offers.add({
      'id': 'b',
      'item_id': item,
      'name': 'Yeni teklif',
      'unit': 'paket',
      'quantity': quantity,
      'status': 'pending',
    });
  }

  @override
  Future<void> respond(String offer, bool accept, String key) async {
    calls.add([offer, accept, key]);
    if (failWrite) throw StateError('private');
    offers.single['status'] = accept ? 'accepted' : 'rejected';
  }
}

Future<void> mountReview(
  WidgetTester tester,
  ReviewFake fake, {
  AccountRole role = AccountRole.manager,
  String route = '/account/order-requests',
}) async {
  final router = createAppRouter(
    previewEnabled: true,
    initialLocation: route,
    isSignedIn: () => true,
  );
  final container = ProviderContainer(
    overrides: [
      appRouterProvider.overrideWithValue(router),
      accountProfileProvider.overrideWith(
        (_) async => AccountProfile(id: 'actor', name: 'Test', role: role),
      ),
      orderReviewRepositoryProvider.overrideWith((_) async => fake),
      shopRepositoryProvider.overrideWith((_) async => FakeShop()),
      salesRepositoryProvider.overrideWith((_) async => FakeSales()),
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
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

class DecisionHistoryFake extends WorkflowFake {
  @override
  Future<Map<String, dynamic>> state(String orderId) async => {
    'status': 'submitted',
    'requests': [
      {
        'type': 'change',
        'status': 'approved',
        'reason': 'Niyet',
        'decision_note': 'Uygulama bekliyor',
      },
    ],
    'history': [
      {
        'event_type': 'request_decided',
        'request_decision': 'approved',
        'to_status': 'submitted',
        'reason': 'Uygulama bekliyor',
        'created_at': '2026-10-10',
      },
    ],
  };
}

void main() {
  testWidgets(
    'Manager decision requires note and preserves submitted order display',
    (tester) async {
      final fake = ReviewFake();
      await mountReview(tester, fake);
      await tester.pumpAndSettle();
      await tapText(tester, 'Talebi onayla');
      await tapText(tester, 'Onayla');
      expect(fake.calls, isEmpty);
      expect(find.text('Karar notu zorunludur.'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Yalnız karar');
      await tapText(tester, 'Onayla');
      expect(fake.calls.single.take(3), ['r', true, 'Yalnız karar']);
      expect(
        find.text('Talep onaylandı; siparişe uygulanmadı'),
        findsOneWidget,
      );
      expect(find.textContaining('Gönderildi'), findsOneWidget);
      expect(find.text('Talebi onayla'), findsNothing);
    },
  );
  testWidgets('Owner rejects and shows decision note', (tester) async {
    final fake = ReviewFake();
    await mountReview(tester, fake, role: AccountRole.owner);
    await tester.pumpAndSettle();
    await tapText(tester, 'Talebi reddet');
    await tester.enterText(find.byType(TextField), 'Uygun değil');
    await tapText(tester, 'Onayla');
    expect(fake.calls.single[1], false);
    expect(find.text('Karar notu: Uygun değil'), findsOneWidget);
  });
  for (final role in [
    AccountRole.customer,
    AccountRole.salesOperator,
    AccountRole.warehouse,
    AccountRole.accounting,
    AccountRole.driver,
  ]) {
    testWidgets('${role.name} cannot open review queue', (tester) async {
      final fake = ReviewFake();
      await mountReview(tester, fake, role: role);
      await tester.pumpAndSettle();
      expect(fake.reads, 0);
      expect(find.textContaining('Bu ekran yönetici'), findsOneWidget);
    });
  }
  testWidgets(
    'Picking and previously approved request have no decision buttons',
    (tester) async {
      final fake = ReviewFake();
      fake.rows.single['order_status'] = 'picking';
      await mountReview(tester, fake);
      await tester.pumpAndSettle();
      expect(find.text('Talebi onayla'), findsNothing);
      expect(find.text('Talebi reddet'), findsNothing);
      fake.rows.single['order_status'] = 'submitted';
      fake.rows.single['status'] = 'approved';
      await tapText(tester, 'Talepleri yenile');
      expect(find.text('Talebi onayla'), findsNothing);
      expect(find.text('Talebi reddet'), findsNothing);
    },
  );
  testWidgets('Decision uncertain retry keeps same note and key', (
    tester,
  ) async {
    final fake = ReviewFake()..failWrite = true;
    await mountReview(tester, fake);
    await tester.pumpAndSettle();
    await tapText(tester, 'Talebi onayla');
    await tester.enterText(find.byType(TextField), 'Sabit not');
    await tapText(tester, 'Onayla');
    expect(tester.widget<TextField>(find.byType(TextField)).readOnly, true);
    fake.failWrite = false;
    await tapText(tester, 'Aynı isteği yeniden dene');
    expect(fake.calls.length, 2);
    expect(fake.calls[0], fake.calls[1]);
  });
  testWidgets('Queue loading failure retry and empty state', (tester) async {
    final fake = ReviewFake()
      ..waiting = Completer<void>()
      ..failRead = true;
    await mountReview(tester, fake);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    fake.waiting!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Talepleri yeniden yükle'), findsOneWidget);
    fake.failRead = false;
    fake.rows.clear();
    await tapText(tester, 'Talepleri yeniden yükle');
    expect(find.text('Henüz sipariş talebi yok.'), findsOneWidget);
  });
  testWidgets('Customer accepts alternative as intent and cannot propose', (
    tester,
  ) async {
    final fake = ReviewFake();
    await mountReview(
      tester,
      fake,
      role: AccountRole.customer,
      route: '/account/shop/orders/o/alternatives',
    );
    await tester.pumpAndSettle();
    expect(find.text('Alternatif öner'), findsNothing);
    await tapText(tester, 'Kabul et');
    expect(
      find.text('Sipariş kalemleri, tutar ve rezervasyon değişmeyecek.'),
      findsOneWidget,
    );
    await tapText(tester, 'Onayla');
    expect(fake.calls.single.take(2), ['a', true]);
    expect(find.text('Müşteri kabul etti — yalnız niyet'), findsOneWidget);
  });
  testWidgets(
    'Customer rejects alternative and advanced order cannot respond',
    (tester) async {
      final fake = ReviewFake();
      await mountReview(
        tester,
        fake,
        role: AccountRole.customer,
        route: '/account/shop/orders/o/alternatives',
      );
      await tester.pumpAndSettle();
      await tapText(tester, 'Reddet');
      await tapText(tester, 'Onayla');
      expect(fake.calls.single[1], false);
      fake.offers.single['status'] = 'pending';
      fake.orderStatus = 'picking';
      await tapText(tester, 'Teklifleri yenile');
      expect(find.text('Kabul et'), findsNothing);
      expect(find.text('Reddet'), findsNothing);
    },
  );
  testWidgets('Sales chooses line unit and integer quantity; cannot accept', (
    tester,
  ) async {
    final fake = ReviewFake();
    await mountReview(
      tester,
      fake,
      role: AccountRole.salesOperator,
      route: '/account/sales/a/orders/o/alternatives',
    );
    await tester.pumpAndSettle();
    expect(find.text('Kabul et'), findsNothing);
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tapText(tester, 'Eski ürün (1 adet)');
    await tester.tap(find.byType(DropdownButtonFormField<String>).last);
    await tester.pumpAndSettle();
    await tapText(tester, 'Test ürün / paket');
    await tester.enterText(find.byType(TextField), '4');
    await tapText(tester, 'Alternatif öner');
    await tapText(tester, 'Onayla');
    expect(fake.calls.single.take(3), ['i', 'u', 4]);
    expect(find.text('Yeni teklif · 4 paket'), findsOneWidget);
  });
  testWidgets(
    'Small keyboard screen permits decision and Android back dismisses safely',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      final fake = ReviewFake();
      await mountReview(tester, fake);
      await tester.pumpAndSettle();
      await tapText(tester, 'Talebi onayla');
      tester.view.viewInsets = const FakeViewPadding(bottom: 240);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'Not');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(fake.calls, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Customer history labels decision separately from status transition',
    (tester) async {
      await mountWorkflow(tester, DecisionHistoryFake());
      await tester.pumpAndSettle();
      expect(
        find.text('Talep onaylandı — siparişe uygulanmadı'),
        findsOneWidget,
      );
      expect(find.text('Güncel durum: Gönderildi'), findsOneWidget);
      expect(
        find.textContaining('Karar notu: Uygulama bekliyor'),
        findsOneWidget,
      );
    },
  );
}
