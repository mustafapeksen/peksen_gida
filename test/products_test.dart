import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peksen_gida/app.dart';
import 'package:peksen_gida/core/routing/app_router.dart';
import 'package:peksen_gida/features/auth/domain/account_repository.dart';
import 'package:peksen_gida/features/auth/presentation/auth_providers.dart';
import 'package:peksen_gida/features/products/domain/product_repository.dart';
import 'package:peksen_gida/features/products/presentation/product_providers.dart';

class FakeProducts implements ProductRepository {
  @override
  Future<List<Map<String, dynamic>>> pricingCustomers() async => [
    {'id': 'c', 'company_name': 'Firma'},
  ];
  @override
  Future<Map<String, dynamic>> quote(
    String customerId,
    String unitId,
    int quantity,
  ) async => {
    'base_quantity': '1',
    'discount_rate_snapshot': '0.5',
    'exact_final_price_kurus_snapshot': '0.375',
    'line_total_kurus': '2',
  };
  List<Product> products = [
    const Product(
      id: 'p',
      sku: 'TEST',
      name: 'Sentetik ürün',
      baseUnit: 'kg',
      active: false,
      priceKurus: '3',
      minimum: '1',
      units: [ProductUnit('u', 'paket', '0.25', true)],
    ),
  ];
  int reads = 0, writes = 0, creates = 0, activations = 0;
  bool fail = false;
  String? key, amount;
  Completer<void>? pending;
  List<Map<String, String>>? createdUnits;
  @override
  Future<List<Product>> list() async {
    reads++;
    await pending?.future;
    if (fail) throw StateError('private-backend-detail');
    return products;
  }

  @override
  Future<List<Map<String, dynamic>>> priceHistory(String id) async => [];
  @override
  Future<List<Map<String, dynamic>>> categories() async => [
    {'id': 'c', 'name': 'Gıda'},
  ];
  @override
  Future<void> changePrice({
    required String productId,
    required String? expectedPrice,
    required String newPrice,
    required String reason,
    required String operationKey,
  }) async {
    writes++;
    key = operationKey;
    amount = newPrice;
    if (fail) throw StateError('private');
  }

  @override
  Future<void> createDraft({
    required String id,
    required String sku,
    required String name,
    required String categoryId,
    required String baseUnit,
    required int minimum,
    required String packageLabel,
    required List<Map<String, String>> units,
  }) async {
    creates++;
    createdUnits = units;
  }

  @override
  Future<void> activate(String productId, String expectedPrice) async {
    activations++;
  }
}

Future<ProviderContainer> mountProducts(
  WidgetTester tester,
  FakeProducts repo, {
  AccountRole role = AccountRole.manager,
  String route = '/account/products',
  bool signedIn = true,
  AccountProfile? Function()? loadProfile,
}) async {
  final router = createAppRouter(
    previewEnabled: true,
    initialLocation: route,
    isSignedIn: () => signedIn,
  );
  final container = ProviderContainer(
    overrides: [
      appRouterProvider.overrideWithValue(router),
      accountProfileProvider.overrideWith(
        (_) async => loadProfile == null
            ? AccountProfile(id: 'test', name: 'Test', role: role)
            : loadProfile(),
      ),
      productRepositoryProvider.overrideWith((_) async => repo),
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

Future<void> tapText(WidgetTester tester, String label) async {
  if (find.text(label).evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      find.text(label),
      150,
      scrollable: find
          .descendant(
            of: find.byType(ListView).last,
            matching: find.byType(Scrollable),
          )
          .first,
    );
  }
  await tester.ensureVisible(find.text(label));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
  test('Discount display preserves exact decimal percent', () {
    expect(formatDiscountPercent('0.5'), '50');
    expect(formatDiscountPercent('0.123456'), '12,3456');
    expect(formatDiscountPercent('1'), '100');
  });
  testWidgets(
    'Quote displays backend line result rather than multiplying rounded unit',
    (t) async {
      await mountProducts(
        t,
        FakeProducts(),
        route: '/account/products/p/quote',
      );
      await t.pumpAndSettle();
      await t.tap(find.byType(DropdownButtonFormField<String>).first);
      await t.pumpAndSettle();
      await t.tap(find.text('Firma').last);
      await t.pumpAndSettle();
      await t.tap(find.byType(DropdownButtonFormField<String>).last);
      await t.pumpAndSettle();
      await t.tap(find.text('paket').last);
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), '4');
      await tapText(t, 'Hesapla');
      expect(find.text('Kalem toplamı: 0,02 TL'), findsOneWidget);
      expect(find.text('İskonto: %50'), findsOneWidget);
      await t.enterText(find.byType(TextField), '6');
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('quote-total')), findsNothing);
    },
  );
  test(
    'Money parsing never loses bigint precision or accepts extra decimals',
    () {
      expect(parseMoney('92233720368547758,07'), '9223372036854775807');
      expect(parseMoney('92233720368547758,08'), isNull);
      expect(parseMoney('0,03'), '3');
      expect(parseMoney('1.5'), '150');
      for (final v in ['1,234', '-1', 'NaN', '1e3', '1.000,00', '']) {
        expect(parseMoney(v), isNull);
      }
      expect(formatKurus('9223372036854775807'), '92233720368547758,07 TL');
    },
  );
  test('Product transport preserves exact decimal text and nullable price', () {
    final p = Product.fromJson({
      'id': 'p',
      'sku': 'S',
      'name': 'N',
      'base_unit': 'kg',
      'active': false,
      'units': [
        {
          'id': 'u',
          'name': 'paket',
          'conversion': '0.123456789012345678901',
          'orderable': true,
        },
      ],
    });
    expect(p.priceKurus, isNull);
    expect(p.units.single.conversion, '0.123456789012345678901');
  });
  testWidgets(
    'Warehouse lists units but never sees a price even from overbroad fixture',
    (t) async {
      await mountProducts(t, FakeProducts(), role: AccountRole.warehouse);
      await t.pumpAndSettle();
      expect(find.text('1 paket = 0.25 kg'), findsOneWidget);
      expect(find.textContaining('Liste fiyatı'), findsNothing);
      expect(find.text('Fiyat ve geçmiş'), findsNothing);
      expect(find.text('Ürün oluştur'), findsOneWidget);
    },
  );
  for (final role in [
    AccountRole.customer,
    AccountRole.salesOperator,
    AccountRole.accounting,
    AccountRole.driver,
  ]) {
    testWidgets(
      '${role.id} direct management route is denied without repository call',
      (t) async {
        final repo = FakeProducts();
        await mountProducts(t, repo, role: role);
        await t.pumpAndSettle();
        expect(find.text('Bu ekrana erişim yetkiniz yok.'), findsOneWidget);
        expect(repo.reads, 0);
      },
    );
  }
  testWidgets('Warehouse direct price route cannot load or change price', (
    t,
  ) async {
    final repo = FakeProducts();
    await mountProducts(
      t,
      repo,
      role: AccountRole.warehouse,
      route: '/account/products/p/price',
    );
    await t.pumpAndSettle();
    expect(find.text('Fiyat yönetimi yetkiniz yok.'), findsOneWidget);
    expect(repo.reads, 0);
  });
  testWidgets('Signed-out direct product route returns to login', (t) async {
    final repo = FakeProducts();
    await mountProducts(t, repo, signedIn: false);
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('login-email')), findsOneWidget);
    expect(repo.reads, 0);
  });
  testWidgets('Loading, sanitized error and retry reach empty state', (
    t,
  ) async {
    final repo = FakeProducts()
      ..pending = Completer<void>()
      ..fail = true;
    await mountProducts(t, repo);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    repo.pending!.complete();
    await t.pumpAndSettle();
    expect(find.text('Ürünler yüklenemedi.'), findsOneWidget);
    expect(find.textContaining('private'), findsNothing);
    repo.fail = false;
    repo.products = [];
    await tapText(t, 'Yeniden dene');
    expect(find.text('Henüz ürün yok.'), findsOneWidget);
  });
  testWidgets(
    'Price request validates reason and reuses key after uncertain failure',
    (t) async {
      final repo = FakeProducts();
      await mountProducts(t, repo, route: '/account/products/p/price');
      await t.pumpAndSettle();
      await tapText(t, 'Fiyatı kaydet');
      expect(repo.writes, 0);
      await t.enterText(find.byType(TextField).at(0), '2,50');
      await t.enterText(find.byType(TextField).at(1), 'Güncelleme');
      repo.fail = true;
      await tapText(t, 'Fiyatı kaydet');
      final key = repo.key;
      await tapText(t, 'Fiyatı kaydet');
      expect(repo.key, key);
      expect(repo.amount, '250');
      expect(repo.writes, 2);
      repo.fail = false;
      await tapText(t, 'Fiyatı kaydet');
      expect(find.text('Fiyat güncellendi.'), findsOneWidget);
    },
  );
  testWidgets('Manager explicitly activates priced draft', (t) async {
    final repo = FakeProducts();
    await mountProducts(t, repo, route: '/account/products/p/price');
    await t.pumpAndSettle();
    await tapText(t, 'Bu fiyatla satışa aç');
    expect(repo.activations, 1);
  });
  testWidgets('Role revocation clears product content on profile refresh', (
    t,
  ) async {
    final repo = FakeProducts();
    AccountProfile? current = const AccountProfile(
      id: 'test',
      name: 'Test',
      role: AccountRole.manager,
    );
    final container = await mountProducts(t, repo, loadProfile: () => current);
    await t.pumpAndSettle();
    current = null;
    container.invalidate(accountProfileProvider);
    await t.pumpAndSettle();
    expect(find.text('Sentetik ürün'), findsNothing);
    expect(find.text('Bu ekrana erişim yetkiniz yok.'), findsOneWidget);
  });
  testWidgets(
    'Small screen form creates draft with exact conversion and returns to list',
    (t) async {
      t.view.physicalSize = const Size(320, 568);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final repo = FakeProducts();
      await mountProducts(t, repo);
      await t.pumpAndSettle();
      await tapText(t, 'Ürün oluştur');
      Future<void> enter(String label, String text) async {
        final f = find.widgetWithText(TextFormField, label);
        await t.ensureVisible(f);
        await t.pumpAndSettle();
        await t.enterText(f, text);
      }

      await enter('SKU', 'YENI');
      await enter('Ürün adı', 'Yeni ürün');
      await enter('Taban birim', 'kg');
      await t.ensureVisible(find.byType(DropdownButtonFormField<String>));
      await t.pumpAndSettle();
      await t.tap(find.byType(DropdownButtonFormField<String>));
      await t.pumpAndSettle();
      await t.tap(find.text('Gıda').last);
      await t.pumpAndSettle();
      await enter('Satış birimi', 'paket');
      await enter('1 satış biriminin taban miktarı', '0,125');
      t.view.viewInsets = const FakeViewPadding(bottom: 220);
      addTearDown(t.view.resetViewInsets);
      await t.pumpAndSettle();
      await tapText(t, 'Fiyatsız ürün oluştur');
      expect(repo.creates, 1);
      expect(repo.createdUnits!.single['conversion'], '0.125');
      expect(find.text('Ürünler ve birimler'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
}
