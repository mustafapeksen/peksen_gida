import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peksen_gida/app.dart';
import 'package:peksen_gida/core/routing/app_router.dart';
import 'package:peksen_gida/features/auth/domain/account_repository.dart';
import 'package:peksen_gida/features/auth/presentation/auth_providers.dart';
import 'package:peksen_gida/features/delivery/data/dispatch_repository.dart';

import 'products_test.dart' show tapText;

class DispatchFake implements DispatchRepository {
  int reads = 0;
  bool failRead = false, failWrite = false, reject = false;
  Completer<void>? loading;
  Map<String, dynamic>? saved;
  final calls = <Map<String, dynamic>>[];
  final data = <String, dynamic>{
    'vehicles': [
      {'id': 'v1', 'plate': 'TEST-1', 'active': true},
      {'id': 'v2', 'plate': 'TEST-2', 'active': true},
    ],
    'drivers': [
      {'id': 'primary', 'name': 'Birincil test'},
      {'id': 'assistant', 'name': 'Yardımcı test'},
      {'id': 'free', 'name': 'Uygun sürücü'},
    ],
    'orders': [
      {'id': 'order3', 'number': 'Sipariş üç', 'run_id': 'old'},
    ],
    'runs': [
      {
        'id': 'run',
        'vehicle_id': 'v1',
        'plate': 'TEST-1',
        'primary_id': 'primary',
        'assistant_id': 'assistant',
        'status': 'planned',
        'managed': true,
        'ended_at': null,
        'stops': [
          {
            'id': 's1',
            'order_id': 'order1',
            'number': 'Bir',
            'sequence': 1,
            'order_status': 'loaded',
          },
          {
            'id': 's2',
            'order_id': 'order2',
            'number': 'İki',
            'sequence': 2,
            'order_status': 'loaded',
          },
        ],
      },
    ],
  };
  @override
  Future<Map<String, dynamic>> read() async {
    reads++;
    await loading?.future;
    if (failRead) throw StateError('synthetic read');
    return data;
  }

  @override
  Future<Map<String, dynamic>?> pending() async => saved;
  @override
  Future<void> perform(String action, Map<String, dynamic> params) async {
    final request = {'action': action, 'params': params};
    calls.add(request);
    saved = request;
    if (reject) {
      saved = null;
      throw const DispatchRejected();
    }
    if (failWrite) throw StateError('synthetic uncertainty');
    saved = null;
  }
}

Future<void> mountDispatch(
  WidgetTester tester,
  DispatchFake fake, {
  AccountRole role = AccountRole.manager,
}) async {
  final router = createAppRouter(
    previewEnabled: true,
    initialLocation: '/account/dispatch',
    isSignedIn: () => true,
  );
  final container = ProviderContainer(
    overrides: [
      appRouterProvider.overrideWithValue(router),
      accountProfileProvider.overrideWith(
        (_) async => AccountProfile(id: 'test', name: 'Test', role: role),
      ),
      dispatchRepositoryProvider.overrideWith((_) async => fake),
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

Future<void> chooseDispatch(
  WidgetTester tester,
  String label,
  String value,
) async {
  final finder = find.byWidgetPredicate(
    (w) =>
        w is DropdownButtonFormField<String> && w.decoration.labelText == label,
  );
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
  await tester.tap(find.text(value).last);
  await tester.pumpAndSettle();
}

void main() {
  for (final role in [
    AccountRole.customer,
    AccountRole.salesOperator,
    AccountRole.warehouse,
    AccountRole.accounting,
  ]) {
    testWidgets('${role.name} dispatch deep link never reads', (tester) async {
      final fake = DispatchFake();
      await mountDispatch(tester, fake, role: role);
      await tester.pumpAndSettle();
      expect(find.text('Bu ekrana erişim yetkiniz yok.'), findsOneWidget);
      expect(fake.reads, 0);
    });
  }
  testWidgets(
    'Vehicle form requires plate; uncertain request freezes payload and key',
    (tester) async {
      final fake = DispatchFake()..failWrite = true;
      await mountDispatch(tester, fake);
      await tester.pumpAndSettle();
      await tapText(tester, 'Araç ekle');
      await tapText(tester, 'Kaydet');
      expect(fake.calls, isEmpty);
      await tester.enterText(
        find.widgetWithText(TextField, 'Plaka'),
        '34 TEST 1',
      );
      await tapText(tester, 'Kaydet');
      expect(fake.calls.single['params']['data']['plate'], '34 TEST 1');
      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, 'Plaka'))
            .readOnly,
        true,
      );
      fake.failWrite = false;
      await tapText(tester, 'Aynı isteği yeniden dene');
      expect(fake.calls[1], fake.calls[0]);
      expect(find.byType(AlertDialog), findsNothing);
    },
  );
  testWidgets(
    'Owner creates run with free vehicle and primary; no manager departure',
    (tester) async {
      final fake = DispatchFake();
      await mountDispatch(tester, fake, role: AccountRole.owner);
      await tester.pumpAndSettle();
      expect(find.text('Yola çık'), findsNothing);
      expect(find.text('Bir sıra yukarı'), findsNothing);
      await tapText(tester, 'Sefer oluştur');
      await tapText(tester, 'Kaydet');
      expect(fake.calls, isEmpty);
      await chooseDispatch(tester, 'Araç', 'TEST-2');
      await chooseDispatch(tester, 'Birincil sürücü', 'Uygun sürücü');
      await tapText(tester, 'Kaydet');
      expect(fake.calls.single['action'], 'create_run');
      expect(fake.calls.single['params']['data'], {
        'vehicle_id': 'v2',
        'primary_id': 'free',
      });
    },
  );
  testWidgets(
    'Reassignment requires reason and target and sends no price or stock data',
    (tester) async {
      final fake = DispatchFake();
      await mountDispatch(tester, fake);
      await tester.pumpAndSettle();
      await tapText(tester, 'Ata');
      await chooseDispatch(tester, 'Hedef sefer', 'TEST-1 · run');
      await tapText(tester, 'Kaydet');
      expect(fake.calls, isEmpty);
      await tester.enterText(
        find.widgetWithText(TextField, 'Gerekçe (zorunlu)'),
        'Araç planı değişti',
      );
      await tapText(tester, 'Kaydet');
      expect(fake.calls.single['params']['data'], {
        'order_id': 'order3',
        'run_id': 'run',
        'reason': 'Araç planı değişti',
      });
    },
  );
  testWidgets(
    'Driver reorder sends complete permutation then departs; management hidden',
    (tester) async {
      final fake = DispatchFake();
      await mountDispatch(tester, fake, role: AccountRole.driver);
      await tester.pumpAndSettle();
      expect(find.text('Araç ekle'), findsNothing);
      expect(find.text('Seferi iptal et'), findsNothing);
      await tapText(tester, 'Bir sıra yukarı');
      await tapText(tester, 'Kaydet');
      expect(fake.calls.single['params']['data']['stop_ids'], ['s2', 's1']);
      await tapText(tester, 'Yola çık');
      await tapText(tester, 'Kaydet');
      expect(fake.calls.last['action'], 'depart');
      expect(fake.calls.last['params']['data'], {'run_id': 'run'});
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Hesabım'), findsOneWidget);
    },
  );
  testWidgets('Closed and completed stops cannot be moved', (tester) async {
    final fake = DispatchFake();
    (fake.data['runs'][0]['stops'][1] as Map)['completed_at'] = '2026-10-11';
    await mountDispatch(tester, fake, role: AccountRole.driver);
    await tester.pumpAndSettle();
    expect(find.text('Bir sıra yukarı'), findsNothing);
  });
  testWidgets('Pending operation blocks new writes and recovers same request', (
    tester,
  ) async {
    final fake = DispatchFake()
      ..saved = {
        'action': 'depart',
        'params': {
          'data': {'run_id': 'run'},
          'request_key': 'durable',
        },
      };
    await mountDispatch(tester, fake, role: AccountRole.driver);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Yola çık'))
          .onPressed,
      isNull,
    );
    await tapText(tester, 'Bekleyen işlemi yeniden dene');
    expect(fake.calls.single['params']['request_key'], 'durable');
  });
  testWidgets('Denied write shows safe error and allows correction', (
    tester,
  ) async {
    final fake = DispatchFake()..reject = true;
    await mountDispatch(tester, fake);
    await tester.pumpAndSettle();
    await tapText(tester, 'Araç ekle');
    await tester.enterText(find.widgetWithText(TextField, 'Plaka'), '34 TEST');
    await tapText(tester, 'Kaydet');
    expect(
      find.text(
        'İşlem reddedildi. Güncel atama, yetki ve durumları kontrol edin.',
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, 'Plaka'))
          .readOnly,
      false,
    );
  });
  testWidgets('Loading error refresh empty list and automatic refresh', (
    tester,
  ) async {
    final fake = DispatchFake()..loading = Completer<void>();
    await mountDispatch(tester, fake, role: AccountRole.driver);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    fake.failRead = true;
    fake.loading!.complete();
    await tester.pumpAndSettle();
    expect(
      find.text('Seferler alınamadı. Yenileyerek tekrar deneyin.'),
      findsOneWidget,
    );
    fake.failRead = false;
    fake.data['runs'] = [];
    await tester.tap(find.byTooltip('Yenile'));
    await tester.pumpAndSettle();
    expect(find.text('Görüntülenecek sefer yok.'), findsOneWidget);
    final reads = fake.reads;
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(fake.reads, greaterThan(reads));
  });
  testWidgets('Small screen keyboard form and back remain usable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    final fake = DispatchFake();
    await mountDispatch(tester, fake);
    await tester.pumpAndSettle();
    await tapText(tester, 'Araç ekle');
    tester.view.viewInsets = const FakeViewPadding(bottom: 250);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Plaka'), '34 SMALL');
    await tapText(tester, 'Kaydet');
    expect(fake.calls, hasLength(1));
    expect(tester.takeException(), isNull);
  });
}
