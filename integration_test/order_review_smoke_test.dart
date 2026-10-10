import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:peksen_gida/features/auth/domain/account_repository.dart';

import '../test/order_review_test.dart' show ReviewFake, mountReview;
import '../test/products_test.dart' show tapText;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android manager records decision without applying order change',
    (tester) async {
      final fake = ReviewFake();
      await mountReview(tester, fake);
      await tester.pumpAndSettle();
      await tapText(tester, 'Talebi onayla');
      await tester.enterText(find.byType(TextField), 'Android karar kontrolü');
      await tapText(tester, 'Onayla');
      expect(fake.calls.length, 1);
      expect(
        find.text('Talep onaylandı; siparişe uygulanmadı'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Android Customer accepts alternative intent without changing order',
    (tester) async {
      final fake = ReviewFake();
      await mountReview(
        tester,
        fake,
        role: AccountRole.customer,
        route: '/account/shop/orders/o/alternatives',
      );
      await tester.pumpAndSettle();
      await tapText(tester, 'Kabul et');
      await tapText(tester, 'Onayla');
      expect(fake.calls.single.take(2), ['a', true]);
      expect(find.text('Müşteri kabul etti — yalnız niyet'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
