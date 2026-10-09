import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/products_test.dart' show FakeProducts, mountProducts, tapText;

// Native navigation/form smoke with a deterministic repository. Real DB pricing
// and authorization are verified separately by product_pricing_test.sql.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Android ürün, fiyat formu ve sistem geri akışı', (tester) async {
    final repo = FakeProducts();
    await mountProducts(tester, repo);
    await tester.pumpAndSettle();
    expect(find.text('Ürünler ve birimler'), findsOneWidget);
    await tapText(tester, 'Fiyat ve geçmiş');
    await tester.enterText(find.byType(TextField).at(0), '2,50');
    await tester.enterText(find.byType(TextField).at(1), 'Sentetik kontrol');
    await tapText(tester, 'Fiyatı kaydet');
    expect(repo.amount, '250');
    expect(find.text('Fiyat güncellendi.'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Ürünler ve birimler'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
