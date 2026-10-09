import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/sales_checkout_test.dart'
    show FakeSales, SalesShop, mountSales, addSalesItem;
import '../test/products_test.dart' show tapText;

// Native UI with deterministic repositories; real RLS/checkout tested in SQL.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Sales chooses assigned customer, reprices through shared cart and goes back',
    (tester) async {
      final shop = SalesShop();
      await mountSales(tester, FakeSales(), shop);
      await tester.pumpAndSettle();
      await tapText(tester, 'Firma A');
      expect(find.textContaining('Müşteri adına: Firma A'), findsOneWidget);
      await addSalesItem(tester);
      await tapText(tester, 'Güncel fiyatı kontrol et');
      shop.change = true;
      await tapText(tester, 'Fiyatı onayla ve gönder');
      expect(shop.submittedCustomers, ['a']);
      await tapText(tester, 'Güncel fiyatı onayla ve gönder');
      expect(shop.submittedCustomers, ['a', 'a']);
      expect(find.textContaining('order-test'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Ürün detayı'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Katalog'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Atanmış müşteriler'), findsOneWidget);
      await tapText(tester, 'Firma B');
      await tapText(tester, 'Sepet');
      expect(
        find.text('Sepetiniz boş. Katalogdan ürün ekleyin.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
