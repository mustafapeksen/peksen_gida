import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peksen_gida/app.dart';
import 'package:peksen_gida/core/routing/app_router.dart';
import 'package:peksen_gida/features/auth/domain/account_repository.dart';
import 'package:peksen_gida/features/auth/presentation/auth_providers.dart';
import 'package:peksen_gida/features/customer/domain/shop_repository.dart';
import 'package:peksen_gida/features/customer/presentation/shop_providers.dart';
import 'package:peksen_gida/features/sales/domain/sales_repository.dart';
import 'package:peksen_gida/features/sales/presentation/sales_customers_page.dart';

import 'customer_checkout_test.dart' show FakeShop;
import 'products_test.dart' show tapText;

class FakeSales implements SalesRepository {
  List<SalesCustomer> customers = [
    const SalesCustomer('a', 'Firma A'),
    const SalesCustomer('b', 'Firma B'),
  ];
  Completer<void>? pending;
  bool fail = false;
  int reads = 0;
  @override
  Future<List<SalesCustomer>> assignedCustomers() async {
    reads++;
    await pending?.future;
    if (fail) throw StateError('internal');
    return customers;
  }
}

class SalesShop extends FakeShop {
  final targets = <String>[];
  final submittedCustomers = <String>[];
  final savedDrafts = <String, List<Map<String, dynamic>>>{};
  @override
  Future<List<CatalogProduct>> catalog(String id) async {
    targets.add(id);
    return super.catalog(id);
  }

  @override
  Future<Map<String, dynamic>> checkout(
    String id,
    List<CartLine> lines,
    Map<String, dynamic> quote,
    String key,
  ) async {
    submittedCustomers.add(id);
    return super.checkout(id, lines, quote, key);
  }

  @override
  Future<void> saveDraft(String id, List<CartLine> lines) async {
    savedDrafts[id] = lines.map((l) => l.toJson()).toList();
  }

  @override
  Future<List<Map<String, dynamic>>?> loadDraft(String id) async =>
      savedDrafts[id];
}

Future<ProviderContainer> mountSales(
  WidgetTester tester,
  FakeSales sales,
  SalesShop shop, {
  String route = '/account/sales',
  AccountRole role = AccountRole.salesOperator,
}) async {
  final router = createAppRouter(
    previewEnabled: true,
    initialLocation: route,
    isSignedIn: () => true,
  );
  final c = ProviderContainer(
    overrides: [
      appRouterProvider.overrideWithValue(router),
      accountProfileProvider.overrideWith(
        (_) async =>
            AccountProfile(id: 'test-sales', name: 'Sales', role: role),
      ),
      salesRepositoryProvider.overrideWith((_) async => sales),
      shopRepositoryProvider.overrideWith((_) async => shop),
    ],
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    c.dispose();
    router.dispose();
  });
  await tester.pumpWidget(
    UncontrolledProviderScope(container: c, child: const PeksenGidaApp()),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  return c;
}

Future<void> addSalesItem(WidgetTester tester) async {
  await tapText(tester, 'Test ürün');
  await tester.tap(find.byType(DropdownButtonFormField<String>));
  await tester.pumpAndSettle();
  await tester.tap(find.text('paket (0.25 kg)').last);
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), '4');
  await tapText(tester, 'Sepete ekle');
}

void main() {
  testWidgets('Direct customer switch replaces an already priced cart', (
    tester,
  ) async {
    final shop = SalesShop();
    final c = await mountSales(tester, FakeSales(), shop);
    await tester.pumpAndSettle();
    await tapText(tester, 'Firma A');
    await addSalesItem(tester);
    await tapText(tester, 'Güncel fiyatı kontrol et');
    expect(find.byKey(const ValueKey('cart-total')), findsOneWidget);
    c.read(appRouterProvider).go('/account/sales/b/cart');
    await tester.pumpAndSettle();
    expect(find.textContaining('Müşteri adına: Firma B'), findsOneWidget);
    expect(
      find.text('Sepetiniz boş. Katalogdan ürün ekleyin.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('cart-total')), findsNothing);
    expect(find.text('Fiyatı onayla ve gönder'), findsNothing);
  });
  testWidgets(
    'Sales selects customer, shares quote and explicitly approves repricing',
    (tester) async {
      final repo = SalesShop();
      await mountSales(tester, FakeSales(), repo);
      await tester.pumpAndSettle();
      await tapText(tester, 'Firma A');
      expect(repo.targets, ['a']);
      expect(find.textContaining('Müşteri adına: Firma A'), findsOneWidget);
      await addSalesItem(tester);
      await tapText(tester, 'Güncel fiyatı kontrol et');
      repo.change = true;
      await tapText(tester, 'Fiyatı onayla ve gönder');
      expect(repo.submittedCustomers, ['a']);
      expect(find.textContaining('Sipariş kaydedilmedi'), findsOneWidget);
      await tapText(tester, 'Güncel fiyatı onayla ve gönder');
      expect(repo.submittedCustomers, ['a', 'a']);
      expect(find.textContaining('order-test'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Ürün detayı'), findsOneWidget);
    },
  );
  testWidgets(
    'Switching customer discards memory cart and isolates saved drafts',
    (tester) async {
      final repo = SalesShop();
      final c = await mountSales(tester, FakeSales(), repo);
      await tester.pumpAndSettle();
      await tapText(tester, 'Firma A');
      await addSalesItem(tester);
      await tapText(tester, 'Taslağı kaydet');
      expect(repo.savedDrafts.keys, ['a']);
      c.read(appRouterProvider).go('/account/sales');
      await tester.pumpAndSettle();
      await tapText(tester, 'Firma B');
      await tapText(tester, 'Sepet');
      expect(
        find.text('Sepetiniz boş. Katalogdan ürün ekleyin.'),
        findsOneWidget,
      );
      await tapText(tester, 'Kayıtlı taslağı yükle');
      expect(find.text('Kaydedilmiş taslak yok.'), findsOneWidget);
      c.read(appRouterProvider).go('/account/sales/a/cart');
      await tester.pumpAndSettle();
      await tapText(tester, 'Kayıtlı taslağı yükle');
      expect(find.text('4 paket'), findsOneWidget);
      expect(repo.targets, containsAll(['a', 'b']));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Guessed customer route never loads catalog or cart', (
    tester,
  ) async {
    final repo = SalesShop();
    await mountSales(
      tester,
      FakeSales(),
      repo,
      route: '/account/sales/unknown/cart',
    );
    await tester.pumpAndSettle();
    expect(find.text('Bu müşteri aktif atamalarınızda değil.'), findsOneWidget);
    expect(repo.targets, isEmpty);
    expect(repo.submits, 0);
    expect(find.text('Sepet'), findsNothing);
  });
  testWidgets('Refreshing revoked assignment removes visible catalog', (
    tester,
  ) async {
    final sales = FakeSales();
    final repo = SalesShop();
    await mountSales(tester, sales, repo, route: '/account/sales/a');
    await tester.pumpAndSettle();
    expect(find.text('Test ürün'), findsOneWidget);
    sales.customers = [];
    await tester.tap(find.byTooltip('Atamayı yenile'));
    await tester.pumpAndSettle();
    expect(find.text('Bu müşteri aktif atamalarınızda değil.'), findsOneWidget);
    expect(find.text('Test ürün'), findsNothing);
  });
  testWidgets('Selection loading error retry and empty states', (tester) async {
    final sales = FakeSales()..pending = Completer<void>();
    await mountSales(tester, sales, SalesShop());
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    sales.fail = true;
    sales.pending!.complete();
    await tester.pumpAndSettle();
    expect(
      find.text('Müşteri erişimi doğrulanamadı. Yeniden dene'),
      findsOneWidget,
    );
    sales.fail = false;
    sales.customers = [];
    await tapText(tester, 'Müşteri erişimi doğrulanamadı. Yeniden dene');
    expect(find.text('Size atanmış aktif müşteri yok.'), findsOneWidget);
  });
  for (final role in AccountRole.values.where(
    (r) => r != AccountRole.salesOperator,
  )) {
    testWidgets(
      '${role.name} cannot enter Sales selection or guessed checkout',
      (tester) async {
        final sales = FakeSales();
        final repo = SalesShop();
        final c = await mountSales(tester, sales, repo, role: role);
        await tester.pumpAndSettle();
        expect(sales.reads, 0);
        expect(find.text('Firma A'), findsNothing);
        c.read(appRouterProvider).go('/account/sales/a/cart');
        await tester.pumpAndSettle();
        expect(
          find.text('Bu ekran satış operasyonu hesabı gerektirir.'),
          findsOneWidget,
        );
        expect(repo.targets, isEmpty);
      },
    );
  }
  testWidgets('Small screen keyboard and scoped order-list back navigation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await mountSales(
      tester,
      FakeSales(),
      SalesShop(),
      route: '/account/sales/a',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Siparişlerim'));
    await tester.pumpAndSettle();
    expect(find.text('Henüz siparişiniz yok.'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tapText(tester, 'Test ürün');
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('paket (0.25 kg)').last);
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 220);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byType(TextField),
      100,
      scrollable: find
          .descendant(
            of: find.byType(ListView).last,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.ensureVisible(find.byType(TextField));
    await tester.enterText(find.byType(TextField), '4');
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).last, const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(find.text('Sepete ekle').hitTestable(), findsOneWidget);
    await tester.tap(find.text('Sepete ekle').hitTestable());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Sepet'), findsOneWidget);
    expect(find.text('4 paket'), findsOneWidget);
    expect(find.textContaining('Müşteri adına: Firma A'), findsOneWidget);
  });
}
