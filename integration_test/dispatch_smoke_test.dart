import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:peksen_gida/features/auth/domain/account_repository.dart';

import '../test/dispatch_test.dart' show DispatchFake, mountDispatch;
import '../test/products_test.dart' show tapText;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Android dispatch vehicle form and system back', (tester) async {
    final fake = DispatchFake();
    await mountDispatch(tester, fake);
    await tester.pumpAndSettle();
    await tapText(tester, 'Araç ekle');
    await tester.enterText(
      find.widgetWithText(TextField, 'Plaka'),
      '34 ANDROID',
    );
    await tapText(tester, 'Kaydet');
    expect(fake.calls.single['action'], 'vehicle');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Hesabım'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Android assigned Driver reorder and departure', (tester) async {
    final fake = DispatchFake();
    await mountDispatch(tester, fake, role: AccountRole.driver);
    await tester.pumpAndSettle();
    await tapText(tester, 'Bir sıra yukarı');
    await tapText(tester, 'Kaydet');
    expect(fake.calls.single['params']['data']['stop_ids'], ['s2', 's1']);
    await tapText(tester, 'Yola çık');
    await tapText(tester, 'Kaydet');
    expect(fake.calls.last['action'], 'depart');
    expect(tester.takeException(), isNull);
  });
}
