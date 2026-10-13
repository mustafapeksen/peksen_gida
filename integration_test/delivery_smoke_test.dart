import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:peksen_gida/features/auth/domain/account_repository.dart';

import '../test/delivery_test.dart' show DeliveryFake, mountDelivery;
import '../test/products_test.dart' show tapText;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Android Driver confirmation and back', (tester) async {
    final fake = DeliveryFake();
    fake.order['status'] = 'out_for_delivery';
    await mountDelivery(tester, fake, role: AccountRole.driver);
    await tester.pumpAndSettle();
    await tapText(tester, 'Teslimatı bildir');
    await tapText(tester, 'Onayla');
    expect(fake.calls.single['action'], 'driver_confirm');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Hesabım'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Android Customer dispute keyboard and explicit action', (
    tester,
  ) async {
    final fake = DeliveryFake();
    await mountDelivery(tester, fake);
    await tester.pumpAndSettle();
    await tapText(tester, 'Teslim almadım');
    await tester.enterText(find.byType(TextFormField), 'Teslimat gelmedi');
    await tapText(tester, 'Onayla');
    expect(fake.calls.single['action'], 'dispute');
    expect(tester.takeException(), isNull);
  });
}
