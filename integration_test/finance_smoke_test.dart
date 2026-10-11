import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:peksen_gida/features/auth/domain/account_repository.dart';

import '../test/finance_test.dart' show FinanceFake, mountFinance;
import '../test/products_test.dart' show tapText;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Android payment form and system back', (tester) async {
    final fake = FinanceFake();
    await mountFinance(tester, fake);
    await tester.pumpAndSettle();
    await tapText(tester, 'Tahsilat kaydet');
    await tester.enterText(
      find.widgetWithText(TextField, 'Tutar (TL)'),
      '15,25',
    );
    await tapText(tester, 'Kaydet');
    expect(fake.calls.single['params']['amount_kurus'], '1525');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Hesabım'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Android assigned Accounting verification', (tester) async {
    final fake = FinanceFake();
    await mountFinance(tester, fake, role: AccountRole.accounting);
    await tester.pumpAndSettle();
    await tapText(tester, 'Doğrula');
    await tapText(tester, 'Kaydet');
    expect(fake.calls.single['action'], 'verify_payment');
    expect(tester.takeException(), isNull);
  });
}
