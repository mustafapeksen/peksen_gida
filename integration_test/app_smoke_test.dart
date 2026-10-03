import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:peksen_gida/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Android giriş, rol menüsü ve önizleme dönüş akışı', (
    tester,
  ) async {
    app.main();
    await tester.pumpAndSettle();

    expect(find.text('Pekşen Gıda'), findsOneWidget);
    final loginButton = tester.widget<FilledButton>(
      find.byKey(const ValueKey('login-submit')),
    );
    expect(loginButton.onPressed, isNull);

    await tester.ensureVisible(find.byKey(const ValueKey('preview-entry')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('preview-entry')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const ValueKey('role-warehouse')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('role-warehouse')));
    await tester.pumpAndSettle();
    expect(find.text('Rol menüsü'), findsOneWidget);

    final products = find.byKey(const ValueKey('menu-warehouse-products'));
    await tester.scrollUntilVisible(products, 160);
    await tester.pumpAndSettle();
    await tester.tap(products);
    await tester.pumpAndSettle();
    expect(find.text('Bu ekran henüz bağlı değil'), findsOneWidget);

    await tester.tap(find.byTooltip('Geri'));
    await tester.pumpAndSettle();
    expect(find.text('Rol menüsü'), findsOneWidget);
    await tester.tap(find.byTooltip('Geri'));
    await tester.pumpAndSettle();
    expect(find.text('Son seçilen rol: Depo'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const ValueKey('state-empty')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('state-empty')));
    await tester.pumpAndSettle();
    expect(find.text('Henüz kayıt yok'), findsOneWidget);

    await tester.tap(find.byTooltip('Geri'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Geri'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('login-email')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
