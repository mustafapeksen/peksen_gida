import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:peksen_gida/features/auth/domain/account_repository.dart';

import '../test/reports_test.dart' show ReportFake, mountReports;
import '../test/products_test.dart' show tapText;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Android Manager report and back', (tester) async {
    await mountReports(tester, ReportFake());
    await tester.pumpAndSettle();
    expect(find.text('submitted: 2'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Hesabım'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Android Owner manual salary form and keyboard', (tester) async {
    final fake = ReportFake();
    await mountReports(
      tester,
      fake,
      role: AccountRole.owner,
      section: 'salary',
    );
    await tester.pumpAndSettle();
    await tapText(tester, 'Kayıt oluştur');
    await tester.enterText(
      find.widgetWithText(TextField, 'Maaş (TL)'),
      '25,10',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Gerekçe'),
      'Android smoke',
    );
    await tapText(tester, 'Kaydet');
    expect(fake.writes.single['salary_kurus'], '2510');
    expect(tester.takeException(), isNull);
  });
  testWidgets('Android Accounting report denied', (tester) async {
    final fake = ReportFake();
    await mountReports(tester, fake, role: AccountRole.accounting);
    await tester.pumpAndSettle();
    expect(find.textContaining('erişim yetkiniz yok'), findsOneWidget);
    expect(fake.reads, 0);
  });
}
