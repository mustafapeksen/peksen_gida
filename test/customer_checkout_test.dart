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

import 'products_test.dart' show tapText;

class FakeShop implements ShopRepository {
  Map<String, dynamic>? pendingRequest;
  @override
  Future<Map<String, dynamic>?> pendingCheckout(String customerId) async =>
      pendingRequest;
  @override
  Future<List<Map<String, dynamic>>> orders(String customerId) async => [];
  List<CatalogProduct> products = [
    const CatalogProduct(
      id: 'p',
      name: 'Test ürün',
      categoryId: 'c',
      category: 'Gıda',
      baseUnit: 'kg',
      minimum: '1',
      listPrice: '10000',
      finalPrice: '7500',
      discount: '0.25',
      stockState: 'empty',
      units: [CatalogUnit('u', 'paket', '0.25')],
    ),
  ];
  int reads = 0, submits = 0, saves = 0;
  bool fail = false, change = false, failSubmit = false;
  Completer<void>? pending;
  final keys = <String>[];
  List<Map<String, dynamic>>? draft;
  @override
  Future<String> customerId(String userId) async => 'c';
  @override
  Future<List<CatalogProduct>> catalog(String id) async {
    reads++;
    await pending?.future;
    if (fail) throw StateError('private');
    return products;
  }

  @override
  Future<Map<String, dynamic>> quote(String id, List<CartLine> lines) async {
    if (lines.any((l) => l.quantity < 4)) throw StateError('Minimum');
    return {
      'fingerprint': change ? 'new' : 'old',
      'total_kurus': change ? '8000' : '7500',
      'stock_sufficient': false,
      'lines': [
        for (final l in lines)
          {
            'name': l.productName,
            'unit': l.unitName,
            'quantity': l.quantity,
            'line_total_kurus': change ? '8000' : '7500',
            'conversion_to_base_snapshot': '0.25',
            'exact_final_price_kurus_snapshot': change ? '2000' : '1875',
          },
      ],
    };
  }

  @override
  Future<void> saveDraft(String id, List<CartLine> lines) async {
    saves++;
    draft = lines.map((l) => l.toJson()).toList();
  }

  @override
  Future<List<Map<String, dynamic>>?> loadDraft(String id) async => draft;
  @override
  Future<Map<String, dynamic>> checkout(
    String id,
    List<CartLine> lines,
    Map<String, dynamic> accepted,
    String key,
  ) async {
    submits++;
    keys.add(key);
    if (failSubmit) throw StateError('network');
    if (change && accepted['fingerprint'] == 'old') {
      return {'outcome': 'changed', 'quote': await quote(id, lines)};
    }
    return {
      'outcome': 'created',
      'order_id': 'order-test',
      'status': 'pending_approval',
    };
  }
}

Future<ProviderContainer> mountShop(
  WidgetTester tester,
  FakeShop repo, {
  String route = '/account/shop',
  AccountRole role = AccountRole.customer,
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
        (_) async => AccountProfile(id: 'test', name: 'Test', role: role),
      ),
      shopRepositoryProvider.overrideWith((_) async => repo),
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

const sampleLine = CartLine(
  productName: 'Test ürün',
  unitId: 'u',
  unitName: 'paket',
  quantity: 4,
);

void main() {
  testWidgets(
    'Interrupted send restores the same request after page reopening',
    (tester) async {
      final repo = FakeShop();
      repo.pendingRequest = {
        'key': 'stable-retry-key',
        'quote': await repo.quote('c', [sampleLine]),
        'lines': [
          {
            ...sampleLine.toJson(),
            'product_name': sampleLine.productName,
            'unit_name': sampleLine.unitName,
          },
        ],
      };
      await mountShop(tester, repo, route: '/account/shop/cart');
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Önceki gönderimin sonucu bekleniyor'),
        findsOneWidget,
      );
      await tapText(tester, 'Aynı gönderimi tekrar dene');
      expect(repo.keys, ['stable-retry-key']);
      expect(find.textContaining('order-test'), findsOneWidget);
    },
  );
  testWidgets('Own orders route has empty state and returns to catalog', (
    tester,
  ) async {
    await mountShop(tester, FakeShop());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Siparişlerim'));
    await tester.pumpAndSettle();
    expect(find.text('Henüz siparişiniz yok.'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Katalog'), findsOneWidget);
  });
  test('Exact fractional kuruş display and payload have no client price', () {
    expect(formatExactKurus('0.375'), '0,00375 TL');
    expect(formatExactKurus('9007199254740993.25'), '90071992547409,9325 TL');
    expect(sampleLine.toJson(), {'unit_id': 'u', 'quantity': 4});
  });
  testWidgets(
    'Customer catalog includes out-of-stock prices and detail back route',
    (tester) async {
      await mountShop(tester, FakeShop());
      await tester.pumpAndSettle();
      expect(find.text('Stok Yok'), findsOneWidget);
      expect(find.textContaining('Size özel %25'), findsOneWidget);
      await tapText(tester, 'Test ürün');
      expect(find.text('Minimum: 1 kg'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Katalog'), findsOneWidget);
    },
  );
  for (final role in AccountRole.values.where(
    (r) => r != AccountRole.customer,
  )) {
    testWidgets('${role.name} cannot open Customer UI', (tester) async {
      final repo = FakeShop();
      await mountShop(tester, repo, role: role);
      await tester.pumpAndSettle();
      expect(find.text('Bu ekran müşteri hesabı gerektirir.'), findsOneWidget);
      expect(repo.reads, 0);
    });
  }
  testWidgets('Catalog loading failure retry and empty states', (tester) async {
    final repo = FakeShop()..pending = Completer<void>();
    await mountShop(tester, repo);
    expect(find.byType(CircularProgressIndicator), findsWidgets);
    repo.fail = true;
    repo.pending!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Katalog yüklenemedi. Yeniden dene'), findsOneWidget);
    repo.fail = false;
    repo.products = [];
    await tapText(tester, 'Katalog yüklenemedi. Yeniden dene');
    expect(find.text('Bu kategoride ürün yok.'), findsOneWidget);
  });
  testWidgets('Minimum validated before adding, positive integer required', (
    tester,
  ) async {
    final repo = FakeShop();
    final c = await mountShop(tester, repo, route: '/account/shop/product/p');
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('paket (0.25 kg)').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '1.5');
    await tapText(tester, 'Sepete ekle');
    expect(c.read(cartProvider), isEmpty);
    await tester.enterText(find.byType(TextField), '1');
    await tapText(tester, 'Sepete ekle');
    expect(find.textContaining('Minimum taban miktarı'), findsOneWidget);
    expect(c.read(cartProvider), isEmpty);
    await tester.enterText(find.byType(TextField), '4');
    await tapText(tester, 'Sepete ekle');
    expect(c.read(cartProvider).single.quantity, 4);
    expect(find.text('Sepet'), findsOneWidget);
  });
  testWidgets(
    'Price change needs explicit second approval; result clears cart',
    (tester) async {
      final repo = FakeShop();
      final c = await mountShop(tester, repo, route: '/account/shop/cart');
      await tester.pumpAndSettle();
      c.read(cartProvider.notifier).setLine(sampleLine);
      await tester.pumpAndSettle();
      await tapText(tester, 'Güncel fiyatı kontrol et');
      repo.change = true;
      await tapText(tester, 'Fiyatı onayla ve gönder');
      expect(repo.submits, 1);
      expect(c.read(cartProvider), hasLength(1));
      expect(find.textContaining('Sipariş kaydedilmedi'), findsOneWidget);
      expect(find.textContaining('Önceki toplam: 75,00'), findsOneWidget);
      await tapText(tester, 'Güncel fiyatı onayla ve gönder');
      expect(repo.submits, 2);
      expect(c.read(cartProvider), isEmpty);
      expect(find.textContaining('order-test'), findsOneWidget);
    },
  );
  testWidgets('Unknown network result retries same key and prevents edits', (
    tester,
  ) async {
    final repo = FakeShop()..failSubmit = true;
    final c = await mountShop(tester, repo, route: '/account/shop/cart');
    await tester.pumpAndSettle();
    c.read(cartProvider.notifier).setLine(sampleLine);
    await tester.pumpAndSettle();
    await tapText(tester, 'Güncel fiyatı kontrol et');
    await tapText(tester, 'Fiyatı onayla ve gönder');
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Çıkar'))
          .onPressed,
      isNull,
    );
    repo.failSubmit = false;
    await tapText(tester, 'Aynı gönderimi tekrar dene');
    expect(repo.keys.toSet(), hasLength(1));
  });
  testWidgets(
    'Draft restore rechecks current catalog and cart edit invalidates quote',
    (tester) async {
      final repo = FakeShop()
        ..draft = [
          {'unit_id': 'u', 'quantity': 4},
        ];
      final c = await mountShop(tester, repo, route: '/account/shop/cart');
      await tester.pumpAndSettle();
      await tapText(tester, 'Kayıtlı taslağı yükle');
      expect(c.read(cartProvider).single.quantity, 4);
      await tapText(tester, 'Güncel fiyatı kontrol et');
      expect(find.byKey(const ValueKey('cart-total')), findsOneWidget);
      c.read(cartProvider.notifier).setLine(sampleLine.withQuantity(8));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('cart-total')), findsNothing);
      await tapText(tester, 'Taslağı kaydet');
      expect(repo.draft!.single['quantity'], 8);
    },
  );
  testWidgets('Small screen and keyboard leave form usable', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await mountShop(tester, FakeShop(), route: '/account/shop/product/p');
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 250);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(TextField));
    await tester.enterText(find.byType(TextField), '4');
    await tapText(tester, 'Sepete ekle');
    expect(tester.takeException(), isNull);
  });
}
