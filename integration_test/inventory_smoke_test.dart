import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/inventory_test.dart' show InventoryFake, mountInventory;
import '../test/products_test.dart' show tapText;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Android warehouse receiving, queue and back smoke', (
    tester,
  ) async {
    final fake = InventoryFake();
    await mountInventory(tester, fake);
    await tester.pumpAndSettle();
    await tapText(tester, 'Mal kabulü');
    await tester.enterText(find.widgetWithText(TextField, 'Miktar'), '1,25');
    await tapText(tester, 'Onayla');
    expect(fake.calls.single.take(3), ['receive', 'u', '1.25']);
    await tapText(tester, 'Toplama');
    await tapText(tester, 'Toplamayı başlat');
    await tapText(tester, 'Onayla');
    expect(find.text('Toplanıyor'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Hesabım'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
