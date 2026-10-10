import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/order_workflow_test.dart' show WorkflowFake, mountWorkflow;
import '../test/products_test.dart' show tapText;

// Android UI smoke with fixture repository; SQL tests verify real transactions.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Order cancellation confirmation and return to list', (
    tester,
  ) async {
    final fake = WorkflowFake();
    await mountWorkflow(tester, fake);
    await tapText(tester, 'Siparişi iptal et');
    await tester.enterText(find.byType(TextField), 'Android iptal kontrolü');
    await tapText(tester, 'Onayla');
    expect(find.text('İptal edildi'), findsOneWidget);
    expect(fake.calls.length, 1);
    expect(tester.takeException(), isNull);
  });
}
