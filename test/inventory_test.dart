import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peksen_gida/app.dart';
import 'package:peksen_gida/core/routing/app_router.dart';
import 'package:peksen_gida/features/auth/domain/account_repository.dart';
import 'package:peksen_gida/features/auth/presentation/auth_providers.dart';
import 'package:peksen_gida/features/inventory/data/inventory_repository.dart';
import 'package:peksen_gida/features/inventory/presentation/inventory_page.dart';

import 'products_test.dart' show tapText;

class InventoryFake implements InventoryRepository {
  int reads = 0;
  bool failRead = false, failWrite = false;
  Completer<void>? pending;
  final calls = <List<Object?>>[];
  final rows = <String, List<Map<String, dynamic>>>{
    'stock': [
      {
        'id': 'p',
        'name': 'Test ürün',
        'unit': 'kg',
        'physical': '100.125',
        'reserved': '3',
        'available': '97.125',
        'units': [
          {'id': 'u', 'name': 'paket', 'conversion': '0.25'},
        ],
      },
    ],
    'preparation': [
      {
        'order_id': 'o',
        'status': 'submitted',
        'items': [
          {
            'id': 'i',
            'name': 'Test ürün',
            'unit': 'paket',
            'quantity': 3,
            'picked': 0,
            'conversion': '0.25',
          },
        ],
      },
    ],
    'counts': [
      {
        'id': 'c',
        'status': 'pending',
        'items': [
          {
            'name': 'Test ürün',
            'unit': 'kg',
            'system': '100',
            'counted': '99',
            'difference': '-1',
          },
        ],
      },
    ],
    'movements': [
      {
        'id': 'm',
        'name': 'Test ürün',
        'type': 'received',
        'quantity': '100',
        'unit': 'kg',
        'physical_delta': '100',
        'reserved_delta': '0',
        'created_at': '2026-10-11',
      },
    ],
  };
  @override
  Future<List<Map<String, dynamic>>> read(String section) async {
    reads++;
    await pending?.future;
    if (failRead) throw StateError('private detail');
    return rows[section]!;
  }

  void record(List<Object?> values) {
    calls.add(values);
    if (failWrite) throw StateError('network');
  }

  @override
  Future<void> orderAction(
    String order,
    String action,
    String? item,
    int? quantity,
    String key,
  ) async {
    record([action, order, item, quantity, key]);
    rows['preparation']!.first['status'] = action == 'start'
        ? 'picking'
        : action == 'load'
        ? 'loaded'
        : 'picked';
    if (action == 'load') rows['preparation'] = [];
  }

  @override
  Future<void> receive(
    String unit,
    String quantity,
    String note,
    String key,
  ) async => record(['receive', unit, quantity, note, key]);
  @override
  Future<void> count(
    String product,
    String quantity,
    String note,
    String key,
  ) async => record(['count', product, quantity, note, key]);
  @override
  Future<void> approveCount(String count, String key) async {
    record(['approve', count, key]);
    rows['counts']!.first['status'] = 'approved';
  }
}

Future<ProviderContainer> mountInventory(
  WidgetTester tester,
  InventoryFake fake, {
  AccountRole role = AccountRole.warehouse,
  AccountProfile? Function()? profile,
}) async {
  final router = createAppRouter(
    previewEnabled: true,
    initialLocation: '/account/inventory',
    isSignedIn: () => true,
  );
  final container = ProviderContainer(
    overrides: [
      appRouterProvider.overrideWithValue(router),
      accountProfileProvider.overrideWith(
        (_) async => profile != null
            ? profile()
            : AccountProfile(id: 'test', name: 'Test', role: role),
      ),
      inventoryRepositoryProvider.overrideWith((_) async => fake),
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
  return container;
}

void main() {
  test('Stock inputs preserve decimal precision and reject invalid/nonfinite values', () {
    expect(
      inventoryQuantity('0,12500000000000000001'),
      '0.12500000000000000001',
    );
    for (final value in ['NaN', 'Infinity', '-1', '1e2', '0', '']) {
      expect(inventoryQuantity(value), isNull);
    }
    expect(inventoryQuantity('0', allowZero: true), '0');
    expect(inventoryQuantity('1.5', integer: true), isNull);
    expect(inventoryQuantity('2147483648', integer: true), isNull);
  });
  for (final role in [
    AccountRole.customer,
    AccountRole.salesOperator,
    AccountRole.accounting,
    AccountRole.driver,
  ]) {
    testWidgets('${role.name} cannot fetch warehouse data', (tester) async {
      final fake = InventoryFake();
      await mountInventory(tester, fake, role: role);
      await tester.pumpAndSettle();
      expect(find.text('Bu ekrana erişim yetkiniz yok.'), findsOneWidget);
      expect(fake.reads, 0);
    });
  }
  testWidgets(
    'Warehouse receives exact decimal and reuses key/payload after uncertain error',
    (tester) async {
      final fake = InventoryFake()..failWrite = true;
      await mountInventory(tester, fake);
      await tester.pumpAndSettle();
      await tapText(tester, 'Mal kabulü');
      await tester.enterText(find.widgetWithText(TextField, 'Miktar'), '0,125');
      await tester.enterText(
        find.widgetWithText(TextField, 'Evrak / sayım notu'),
        'Sentetik belge',
      );
      await tapText(tester, 'Onayla');
      expect(fake.calls.single.take(4), [
        'receive',
        'u',
        '0.125',
        'Sentetik belge',
      ]);
      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, 'Miktar'))
            .readOnly,
        isTrue,
      );
      fake.failWrite = false;
      await tapText(tester, 'Aynı isteği yeniden dene');
      expect(fake.calls[0], fake.calls[1]);
      expect(find.byType(AlertDialog), findsNothing);
    },
  );
  testWidgets(
    'Zero receiving is rejected; zero count is allowed and not approved by warehouse',
    (tester) async {
      final fake = InventoryFake();
      await mountInventory(tester, fake);
      await tester.pumpAndSettle();
      await tapText(tester, 'Mal kabulü');
      await tester.enterText(find.widgetWithText(TextField, 'Miktar'), '0');
      await tapText(tester, 'Onayla');
      expect(fake.calls, isEmpty);
      await tapText(tester, 'Kapat');
      await tapText(tester, 'Sayım gönder');
      await tester.enterText(find.widgetWithText(TextField, 'Miktar'), '0');
      await tapText(tester, 'Onayla');
      expect(fake.calls.single.take(3), ['count', 'p', '0']);
      await tapText(tester, 'Sayım');
      expect(find.text('Sayımı onayla'), findsNothing);
    },
  );
  for (final role in [AccountRole.manager, AccountRole.owner]) {
    testWidgets(
      '${role.name} approves count without receiving count-entry permission',
      (tester) async {
        final fake = InventoryFake();
        await mountInventory(tester, fake, role: role);
        await tester.pumpAndSettle();
        expect(find.text('Sayım gönder'), findsNothing);
        await tapText(tester, 'Sayım');
        await tapText(tester, 'Sayımı onayla');
        await tapText(tester, 'Onayla');
        expect(fake.calls.single.take(2), ['approve', 'c']);
        expect(find.text('Onaylandı'), findsOneWidget);
        expect(find.text('Sayımı onayla'), findsNothing);
      },
    );
  }
  testWidgets(
    'Preparation requires start, integer pick and explicit load confirmation',
    (tester) async {
      final fake = InventoryFake();
      await mountInventory(tester, fake);
      await tester.pumpAndSettle();
      await tapText(tester, 'Toplama');
      expect(find.text('Kalem topla'), findsNothing);
      await tapText(tester, 'Toplamayı başlat');
      await tapText(tester, 'Onayla');
      expect(fake.calls.last.take(4), ['start', 'o', null, null]);
      await tapText(tester, 'Kalem topla');
      await tester.enterText(find.widgetWithText(TextField, 'Miktar'), '1.5');
      await tapText(tester, 'Onayla');
      expect(fake.calls.length, 1);
      await tester.enterText(find.widgetWithText(TextField, 'Miktar'), '3');
      await tapText(tester, 'Onayla');
      expect(fake.calls.last.take(4), ['pick', 'o', 'i', 3]);
      await tapText(tester, 'Yüklemeyi tamamla');
      expect(fake.calls.length, 2);
      await tapText(tester, 'Onayla');
      expect(fake.calls.last.take(4), ['load', 'o', null, null]);
      expect(find.text('Henüz kayıt yok.'), findsOneWidget);
    },
  );
  testWidgets(
    'Loading error retry and empty states are usable without raw errors',
    (tester) async {
      final fake = InventoryFake()..pending = Completer<void>();
      await mountInventory(tester, fake);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      fake.failRead = true;
      fake.pending!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Depo kayıtları yüklenemedi.'), findsOneWidget);
      expect(find.text('private detail'), findsNothing);
      fake.failRead = false;
      fake.rows['stock'] = [];
      await tapText(tester, 'Yeniden dene');
      expect(find.text('Henüz kayıt yok.'), findsOneWidget);
    },
  );
  testWidgets('Profile revocation clears data and stops further reads', (
    tester,
  ) async {
    final fake = InventoryFake();
    var allowed = true;
    final container = await mountInventory(
      tester,
      fake,
      profile: () => allowed
          ? const AccountProfile(
              id: 'a',
              name: 'W',
              role: AccountRole.warehouse,
            )
          : null,
    );
    await tester.pumpAndSettle();
    expect(find.text('Test ürün'), findsOneWidget);
    allowed = false;
    final before = fake.reads;
    container.invalidate(accountProfileProvider);
    await tester.pumpAndSettle();
    expect(find.text('Test ürün'), findsNothing);
    expect(fake.reads, before);
  });
  testWidgets('Small screen keyboard form and back navigation work', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fake = InventoryFake();
    await mountInventory(tester, fake);
    await tester.pumpAndSettle();
    await tapText(tester, 'Sayım gönder');
    tester.view.viewInsets = const FakeViewPadding(bottom: 220);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Miktar'), '99');
    await tapText(tester, 'Onayla');
    expect(fake.calls.single.take(3), ['count', 'p', '99']);
    expect(tester.takeException(), isNull);
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Hesabım'), findsOneWidget);
  });
}
