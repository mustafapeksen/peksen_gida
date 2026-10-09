import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/customer_checkout_test.dart' show FakeShop, mountShop;
import '../test/products_test.dart' show tapText;

// Native form/navigation smoke uses a fake repository. SQL tests separately
// verify real authorization, exact pricing, snapshots and reservations.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android Customer catalog, cart, explicit reprice approval and back',
    (tester) async {
      final repo = FakeShop();
      await mountShop(tester, repo);
      await tester.pumpAndSettle();
      await tapText(tester, 'Test ürün');
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('paket (0.25 kg)').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '4');
      await tapText(tester, 'Sepete ekle');
      await tapText(tester, 'Güncel fiyatı kontrol et');
      repo.change = true;
      await tapText(tester, 'Fiyatı onayla ve gönder');
      expect(repo.submits, 1);
      await tapText(tester, 'Güncel fiyatı onayla ve gönder');
      expect(repo.submits, 2);
      expect(find.textContaining('order-test'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Ürün detayı'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
