import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peksen_gida/app.dart';
import 'package:peksen_gida/core/routing/app_router.dart';
import 'package:peksen_gida/features/auth/domain/account_repository.dart';
import 'package:peksen_gida/features/auth/presentation/auth_providers.dart';
import 'package:peksen_gida/features/delivery/data/delivery_repository.dart';

import 'products_test.dart' show tapText;

class DeliveryFake implements DeliveryRepository {
  Map<String, dynamic>? saved;
  bool fail = false, failRead = false;
  int reads = 0;
  Completer<void>? loading;
  final calls = <Map<String, dynamic>>[];
  final data = <String, dynamic>{
    'orders': <Map<String, dynamic>>[
      {
        'id': 'order',
        'number': 'Test siparişi',
        'status': 'delivery_pending_confirmation',
        'can_rate': false,
        'evidence': [],
      },
    ],
  };
  Map<String, dynamic> get order =>
      (data['orders'] as List).first as Map<String, dynamic>;
  @override
  Future<Map<String, dynamic>> read() async {
    reads++;
    await loading?.future;
    if (failRead) throw StateError('Synthetic read');
    return data;
  }

  @override
  Future<Map<String, dynamic>?> pending() async => saved;
  @override
  Future<Map<String, dynamic>> perform(
    String action,
    Map<String, dynamic> params,
  ) async {
    saved = {'action': action, 'params': params};
    calls.add(saved!);
    if (fail) throw StateError('Synthetic transport failure');
    saved = null;
    return {'status': 'delivered'};
  }

  @override
  Future<void> upload(String path, Uint8List bytes, String mime) async {}
  @override
  Future<Uint8List> download(String path) async => Uint8List(0);
}

Future<void> mountDelivery(
  WidgetTester tester,
  DeliveryFake fake, {
  AccountRole role = AccountRole.customer,
}) async {
  final router = createAppRouter(
    previewEnabled: true,
    initialLocation: '/account/deliveries',
    isSignedIn: () => true,
  );
  final container = ProviderContainer(
    overrides: [
      appRouterProvider.overrideWithValue(router),
      accountProfileProvider.overrideWith(
        (_) async => AccountProfile(id: 'test', name: 'Test', role: role),
      ),
      deliveryRepositoryProvider.overrideWith((_) async => fake),
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
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('Customer must explicitly confirm and sends one request', (
    tester,
  ) async {
    final fake = DeliveryFake();
    await mountDelivery(tester, fake);
    await tester.pumpAndSettle();
    await tapText(tester, 'Teslim aldım');
    expect(fake.calls, isEmpty);
    await tapText(tester, 'Onayla');
    expect(fake.calls.single['action'], 'customer_confirm');
    expect(fake.calls.single['params']['data'], {'order_id': 'order'});
    expect(fake.calls.single['params']['request_key'], isNotEmpty);
  });
  testWidgets('Reason required; narrow keyboard form and back remain usable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fake = DeliveryFake();
    await mountDelivery(tester, fake);
    await tester.pumpAndSettle();
    await tapText(tester, 'Teslim almadım');
    await tapText(tester, 'Onayla');
    expect(find.text('Gerekçe gerekli.'), findsOneWidget);
    expect(fake.calls, isEmpty);
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    addTearDown(tester.view.resetViewInsets);
    await tester.enterText(find.byType(TextFormField), 'Ürün gelmedi');
    await tapText(tester, 'Onayla');
    expect(fake.calls.single['params']['data']['reason'], 'Ürün gelmedi');
    expect(tester.takeException(), isNull);
    tester.view.resetViewInsets();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Hesabım'), findsOneWidget);
  });
  testWidgets('Driver initiates only; cannot finalize or rate', (tester) async {
    final fake = DeliveryFake();
    fake.order['status'] = 'out_for_delivery';
    await mountDelivery(tester, fake, role: AccountRole.driver);
    await tester.pumpAndSettle();
    expect(find.text('Teslim aldım'), findsNothing);
    expect(find.text('Sürücüyü puanla'), findsNothing);
    await tapText(tester, 'Teslimatı bildir');
    expect(find.textContaining('tek başına kesinleştirmez'), findsOneWidget);
    await tapText(tester, 'Onayla');
    expect(fake.calls.single['action'], 'driver_confirm');
  });
  testWidgets(
    'Manager resolution requires reason; no failed returned actions',
    (tester) async {
      final fake = DeliveryFake();
      fake.order['status'] = 'delivery_disputed';
      await mountDelivery(tester, fake, role: AccountRole.manager);
      await tester.pumpAndSettle();
      await tapText(tester, 'Gerekçeli teslimat çözümü');
      await tapText(tester, 'Onayla');
      expect(fake.calls, isEmpty);
      await tester.enterText(
        find.byType(TextFormField),
        'Müşteri ile görüşüldü',
      );
      await tapText(tester, 'Onayla');
      expect(fake.calls.single['action'], 'resolve');
      expect(find.text('İade'), findsNothing);
    },
  );
  testWidgets(
    'Uncertain response retries exact request rather than a new operation',
    (tester) async {
      final fake = DeliveryFake()..fail = true;
      await mountDelivery(tester, fake);
      await tester.pumpAndSettle();
      await tapText(tester, 'Teslim aldım');
      await tapText(tester, 'Onayla');
      final first = fake.calls.single;
      fake.fail = false;
      await tapText(tester, 'Aynı isteği yeniden dene');
      expect(fake.calls.last, first);
    },
  );
  testWidgets(
    'Rating is offered only when server allows and collects reasons',
    (tester) async {
      final fake = DeliveryFake();
      fake.order.addAll({'status': 'delivered', 'can_rate': true});
      await mountDelivery(tester, fake);
      await tester.pumpAndSettle();
      await tapText(tester, 'Sürücüyü puanla');
      await tapText(tester, 'Geç geldi');
      await tapText(tester, 'Onayla');
      expect(fake.calls.single['action'], 'rate');
      expect(fake.calls.single['params']['data']['reasons'], ['late']);
      expect(fake.calls.single['params']['data']['score'], 5);
    },
  );
  testWidgets('Forbidden role never calls delivery repository', (tester) async {
    final fake = DeliveryFake();
    await mountDelivery(tester, fake, role: AccountRole.warehouse);
    await tester.pumpAndSettle();
    expect(fake.reads, 0);
    expect(find.textContaining('Teslimatlar okunamadı'), findsOneWidget);
  });
  testWidgets('Loading error retry empty state', (tester) async {
    final fake = DeliveryFake()..loading = Completer<void>();
    await mountDelivery(tester, fake);
    expect(find.byType(CircularProgressIndicator), findsWidgets);
    fake.failRead = true;
    fake.loading!.complete();
    await tester.pumpAndSettle();
    expect(find.textContaining('Teslimatlar okunamadı'), findsOneWidget);
    fake.failRead = false;
    fake.data['orders'] = [];
    await tester.tap(find.byTooltip('Yenile'));
    await tester.pumpAndSettle();
    expect(find.text('Bu kapsamda teslimatınız yok.'), findsOneWidget);
  });
  test('Evidence MIME is based on bytes', () {
    expect(
      evidenceMime(Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10])),
      'image/png',
    );
    expect(evidenceMime(Uint8List.fromList([255, 216, 255, 0])), 'image/jpeg');
    expect(evidenceMime(Uint8List.fromList('<html>'.codeUnits)), isNull);
  });
}
