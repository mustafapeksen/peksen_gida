import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:peksen_gida/app.dart';
import 'package:peksen_gida/core/config/preview_config.dart';
import 'package:peksen_gida/core/routing/app_router.dart';
import 'package:peksen_gida/features/preview/domain/role_menu.dart';

// SPEC §23, intentionally independent of the application's menu definition.
const sourceScreens = <String, List<String>>{
  'customer': [
    'Login',
    'Home',
    'Categories',
    'Products',
    'Product Detail',
    'Cart',
    'Checkout',
    'Orders',
    'Order Detail',
    'Live Delivery',
    'Delivery Confirmation',
    'Rating',
    'Profile',
  ],
  'sales_operator': [
    'Dashboard',
    'Customers',
    'Customer Detail',
    'Catalog',
    'Create Order',
    'Order Detail',
    'Alternative Offer',
    'Payments',
    'Customer History',
  ],
  'warehouse': [
    'Dashboard',
    'Order Queue',
    'Picking',
    'Missing Item',
    'Products',
    'Price Management',
    'Receiving',
    'Inventory',
    'Stock Count',
    'Movements',
  ],
  'accounting': [
    'Dashboard',
    'Payments',
    'Payment Verification',
    'Customer Accounts',
    'Credit Limit',
    'Price Management',
    'Reports',
  ],
  'driver': [
    "Today's Run",
    'Stops',
    'Stop Detail',
    'Navigation Handoff',
    'GPS Status',
    'Delivery Confirmation',
    'Exception',
  ],
  'manager': [
    'Dashboard',
    'Orders',
    'Inventory',
    'Deliveries',
    'Live Vehicles',
    'Customers',
    'Employees',
    'Ratings',
    'Discounts',
    'Reports',
  ],
  'owner': [
    'Dashboard',
    'Orders',
    'Inventory',
    'Deliveries',
    'Live Vehicles',
    'Customers',
    'Employees',
    'Ratings',
    'Discounts',
    'Reports',
    'Finance',
    'Salary/Bonus',
    'Settings',
    'Audit Log',
  ],
};

Future<GoRouter> pumpApp(
  WidgetTester tester, {
  bool previewEnabled = true,
  String initialLocation = '/',
}) async {
  final router = createAppRouter(
    previewEnabled: previewEnabled,
    initialLocation: initialLocation,
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        developmentPreviewEnabledProvider.overrideWithValue(previewEnabled),
        appRouterProvider.overrideWithValue(router),
      ],
      child: const PeksenGidaApp(),
    ),
  );
  await pumpNavigation(tester);
  return router;
}

// Loading intentionally animates forever, so navigation must not rely on
// pumpAndSettle. These bounded frames complete the route transition instead.
Future<void> pumpNavigation(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 800));
  await tester.pump();
}

String locationOf(GoRouter router) =>
    router.routeInformationProvider.value.uri.path;

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
  await pumpNavigation(tester);
  expect(finder.hitTestable(), findsOneWidget);
  await tester.tap(finder);
  await pumpNavigation(tester);
}

Future<void> scrollToMenu(
  WidgetTester tester,
  Finder menu,
  Finder scrollable,
) async {
  await tester.scrollUntilVisible(
    menu,
    120,
    scrollable: scrollable,
    maxScrolls: 100,
  );
  await pumpNavigation(tester);
  await Scrollable.ensureVisible(tester.element(menu), alignment: 0.5);
  await pumpNavigation(tester);
  expect(menu.hitTestable(), findsOneWidget);
}

Future<void> appBack(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Geri'));
  await pumpNavigation(tester);
}

void useSmallScreen(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(320, 568);
  tester.platformDispatcher.textScaleFactorTestValue = 2;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

void main() {
  test('Yedi rol ve 70 ekran kaynak envanterini eksiksiz korur', () {
    expect(AppRole.values.map((role) => role.id), sourceScreens.keys);
    expect(roleMenus.keys.toSet(), AppRole.values.toSet());
    for (final role in AppRole.values) {
      final entries = roleMenus[role]!;
      expect(
        entries.map((entry) => entry.sourceLabel),
        sourceScreens[role.id],
        reason: role.id,
      );
      expect(
        entries.map((entry) => entry.id).toSet(),
        hasLength(entries.length),
      );
    }
    expect(roleMenus.values.expand((entries) => entries), hasLength(70));
    expect(AppRole.fromId('order_operator'), isNull);
  });

  testWidgets('Giriş alanları gerçek oturum açma işlemi başlatmaz', (
    tester,
  ) async {
    final router = await pumpApp(tester, previewEnabled: false);
    final email = find.byKey(const ValueKey('login-email'));
    final password = find.byKey(const ValueKey('login-password'));
    final submit = find.byKey(const ValueKey('login-submit'));

    expect(email, findsOneWidget);
    expect(password, findsOneWidget);
    expect(tester.widget<ButtonStyleButton>(submit).onPressed, isNull);
    expect(find.byKey(const ValueKey('preview-entry')), findsNothing);

    await tester.enterText(email, 'test@example.invalid');
    await tester.enterText(password, 'synthetic-password');
    await tester.pump();
    expect(tester.widget<ButtonStyleButton>(submit).onPressed, isNull);
    expect(locationOf(router), '/');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Önizleme kapalıyken doğrudan alt rota da açılamaz', (
    tester,
  ) async {
    final router = await pumpApp(tester, previewEnabled: false);
    for (final path in [
      '/preview',
      '/preview/states/loading',
      '/preview/roles/owner',
      '/preview/roles/owner/finance',
      '/preview/roles/unknown/unknown',
      '/preview/olmayan-sayfa/alt-sayfa',
    ]) {
      router.go(path);
      await pumpNavigation(tester);
      expect(locationOf(router), '/', reason: path);
      expect(find.byKey(const ValueKey('login-email')), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('Kapalı önizleme deep link başlangıcı da girişe döner', (
    tester,
  ) async {
    final router = await pumpApp(
      tester,
      previewEnabled: false,
      initialLocation: '/preview/roles/owner/finance',
    );
    expect(locationOf(router), '/');
    expect(find.byKey(const ValueKey('login-email')), findsOneWidget);
  });

  testWidgets('Login alias tek giriş rotasına yönlenir', (tester) async {
    final router = await pumpApp(tester, initialLocation: '/login');
    expect(locationOf(router), '/');
    expect(find.byKey(const ValueKey('login-email')), findsOneWidget);
  });

  for (final role in AppRole.values) {
    testWidgets('${role.id} her menüyü açar ve menü listesine geri döner', (
      tester,
    ) async {
      final router = await pumpApp(
        tester,
        initialLocation: '/preview/roles/${role.id}',
      );
      expect(find.text(role.label), findsWidgets);
      final list = find.byKey(PageStorageKey('role-menu-${role.id}'));
      final scrollable = find.descendant(
        of: list,
        matching: find.byType(Scrollable),
      );
      final entries = roleMenus[role]!;
      for (final entry in entries) {
        final menu = find.byKey(ValueKey('menu-${role.id}-${entry.id}'));
        await scrollToMenu(tester, menu, scrollable);
        await tapVisible(tester, menu);
        expect(locationOf(router), '/preview/roles/${role.id}/${entry.id}');
        expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('destination-title')))
              .data,
          entry.label,
        );
        expect(find.text('Bu ekran henüz bağlı değil'), findsOneWidget);
        expect(find.text('Sayfa bulunamadı'), findsNothing);
        await appBack(tester);
        expect(locationOf(router), '/preview/roles/${role.id}');
        expect(find.text('Rol menüsü'), findsOneWidget);
        expect(tester.takeException(), isNull, reason: entry.sourceLabel);
      }
    });
  }

  testWidgets('Önizlemede seçilen rol geri dönünce hatırlanır', (tester) async {
    final router = await pumpApp(tester);
    await tapVisible(tester, find.byKey(const ValueKey('preview-entry')));
    expect(locationOf(router), '/preview');
    final role = AppRole.warehouse;
    final roleButton = find.byKey(ValueKey('role-${role.id}'));
    await tester.scrollUntilVisible(roleButton, 180);
    await tapVisible(tester, roleButton);
    expect(locationOf(router), '/preview/roles/${role.id}');
    await appBack(tester);
    expect(locationOf(router), '/preview');
    expect(find.text('Son seçilen rol: ${role.label}'), findsOneWidget);
  });

  testWidgets(
    'Doğrudan ekran bağlantısından menü, önizleme ve girişe dönülür',
    (tester) async {
      final router = await pumpApp(
        tester,
        initialLocation: '/preview/roles/owner/audit',
      );
      expect(find.text('İşlem kayıtları'), findsWidgets);
      for (final expected in ['/preview/roles/owner', '/preview', '/']) {
        await appBack(tester);
        expect(locationOf(router), expected);
      }
      expect(find.byKey(const ValueKey('login-email')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Android geri olayı iç içe ekranları sırayla kapatır', (
    tester,
  ) async {
    final router = await pumpApp(
      tester,
      initialLocation: '/preview/roles/owner/audit',
    );
    for (final expected in ['/preview/roles/owner', '/preview', '/']) {
      await tester.binding.handlePopRoute();
      await pumpNavigation(tester);
      expect(locationOf(router), expected);
      expect(tester.takeException(), isNull);
    }
    expect(find.byKey(const ValueKey('login-email')), findsOneWidget);
  });

  for (final state in ['loading', 'empty', 'error']) {
    testWidgets('$state durumu gösterilir ve önizlemeye dönülebilir', (
      tester,
    ) async {
      final router = await pumpApp(tester, initialLocation: '/preview');
      final stateButton = find.byKey(ValueKey('state-$state'));
      await tester.scrollUntilVisible(stateButton, 180);
      await tapVisible(tester, stateButton);
      expect(locationOf(router), '/preview/states/$state');
      expect(find.byKey(ValueKey('state-$state-title')), findsOneWidget);
      expect(
        find.byType(CircularProgressIndicator),
        state == 'loading' ? findsOneWidget : findsNothing,
      );
      await tapVisible(tester, find.text('Önizlemeye dön'));
      expect(locationOf(router), '/preview');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Hata ekranının örnek eylemi boş duruma yönlendirir', (
    tester,
  ) async {
    final router = await pumpApp(
      tester,
      initialLocation: '/preview/states/error',
    );
    await tapVisible(tester, find.text('Boş liste örneğine git'));
    expect(locationOf(router), '/preview/states/empty');
    expect(find.byKey(const ValueKey('state-empty-title')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final path in [
    '/olmayan-sayfa',
    '/preview/roles/order_operator',
    '/preview/roles/customer/olmayan-ekran',
    '/preview/states/olmayan-durum',
  ]) {
    testWidgets('Bilinmeyen rota güvenli hata ekranı gösterir: $path', (
      tester,
    ) async {
      final router = await pumpApp(tester, initialLocation: path);
      expect(find.text('Sayfa bulunamadı'), findsOneWidget);
      await tapVisible(tester, find.text('Giriş ekranına dön'));
      expect(locationOf(router), '/');
      expect(find.byKey(const ValueKey('login-email')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Bilinmeyen rotada Android geri girişe döner: $path', (
      tester,
    ) async {
      final router = await pumpApp(tester, initialLocation: path);
      expect(find.text('Sayfa bulunamadı'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await pumpNavigation(tester);
      expect(tester.takeException(), isNull);
      expect(locationOf(router), '/');
      expect(find.byKey(const ValueKey('login-email')), findsOneWidget);
    });
  }

  for (final previewEnabled in [true, false]) {
    testWidgets('Açık uygulamada bilinmeyen bağlantı ve Android geri: '
        'preview=$previewEnabled', (tester) async {
      final router = await pumpApp(tester, previewEnabled: previewEnabled);
      router.go('/olmayan-sayfa?ornek=1');
      await pumpNavigation(tester);
      expect(locationOf(router), '/not-found');
      expect(find.text('Sayfa bulunamadı'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.binding.handlePopRoute();
      await pumpNavigation(tester);
      expect(locationOf(router), '/');
      expect(find.byKey(const ValueKey('login-email')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Önizleme kapalıyken bilinmeyen ilk bağlantıdan geri dönülür', (
    tester,
  ) async {
    final router = await pumpApp(
      tester,
      previewEnabled: false,
      initialLocation: '/olmayan-sayfa',
    );
    expect(locationOf(router), '/not-found');
    expect(find.text('Sayfa bulunamadı'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await pumpNavigation(tester);
    expect(locationOf(router), '/');
    expect(find.byKey(const ValueKey('login-email')), findsOneWidget);
    expect(find.byKey(const ValueKey('preview-entry')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final role in AppRole.values) {
    testWidgets('Dar ekranda büyük yazıyla ${role.id} menülerine erişilir', (
      tester,
    ) async {
      useSmallScreen(tester);
      final router = await pumpApp(tester, initialLocation: '/preview');
      final roleButton = find.byKey(ValueKey('role-${role.id}'));
      await tapVisible(tester, roleButton);
      expect(locationOf(router), '/preview/roles/${role.id}');
      expect(tester.takeException(), isNull);

      final list = find.byKey(PageStorageKey('role-menu-${role.id}'));
      final scrollable = find.descendant(
        of: list,
        matching: find.byType(Scrollable),
      );
      for (final entry in roleMenus[role]!) {
        final menu = find.byKey(ValueKey('menu-${role.id}-${entry.id}'));
        await scrollToMenu(tester, menu, scrollable);
        expect(tester.takeException(), isNull, reason: entry.sourceLabel);
        await tapVisible(tester, menu);
        expect(locationOf(router), '/preview/roles/${role.id}/${entry.id}');
        final title = find.byKey(const ValueKey('destination-title'));
        await tester.ensureVisible(title);
        await pumpNavigation(tester);
        expect(title.hitTestable(), findsOneWidget);
        expect(tester.widget<Text>(title).data, entry.label);
        final explanation = find.text('Bu ekran henüz bağlı değil');
        await tester.ensureVisible(explanation);
        await pumpNavigation(tester);
        expect(explanation.hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull, reason: entry.sourceLabel);
        await appBack(tester);
        expect(locationOf(router), '/preview/roles/${role.id}');
      }
      await appBack(tester);
      expect(locationOf(router), '/preview');
      expect(find.text('Son seçilen rol: ${role.label}'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final state in ['loading', 'empty', 'error']) {
    testWidgets('Dar ekranda büyük yazıyla $state eylemleri kullanılabilir', (
      tester,
    ) async {
      useSmallScreen(tester);
      final router = await pumpApp(tester, initialLocation: '/preview');
      await tapVisible(tester, find.byKey(ValueKey('state-$state')));
      expect(locationOf(router), '/preview/states/$state');
      final title = find.byKey(ValueKey('state-$state-title'));
      await tester.ensureVisible(title);
      await pumpNavigation(tester);
      expect(title.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (state == 'error') {
        await tapVisible(tester, find.text('Boş liste örneğine git'));
        expect(locationOf(router), '/preview/states/empty');
      }
      await tapVisible(tester, find.text('Önizlemeye dön'));
      expect(locationOf(router), '/preview');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Dar ekranda büyük yazıyla bilinmeyen rotadan dönülebilir', (
    tester,
  ) async {
    useSmallScreen(tester);
    final router = await pumpApp(tester, initialLocation: '/olmayan-sayfa');
    expect(find.text('Sayfa bulunamadı'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tapVisible(tester, find.text('Giriş ekranına dön'));
    expect(locationOf(router), '/');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Dar ekranda büyük yazı ve klavyeyle iki alana erişilir', (
    tester,
  ) async {
    useSmallScreen(tester);
    tester.view.viewInsets = const FakeViewPadding(bottom: 220);
    addTearDown(tester.view.resetViewInsets);
    await pumpApp(tester);
    expect(tester.takeException(), isNull);

    for (final entry in {
      'login-email': 'narrow@example.invalid',
      'login-password': 'synthetic-password',
    }.entries) {
      final field = find.byKey(ValueKey(entry.key));
      await tester.ensureVisible(field);
      await tester.pump();
      expect(field.hitTestable(), findsOneWidget);
      await tester.enterText(field, entry.value);
      await tester.pump();
      expect(find.text(entry.value), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}
