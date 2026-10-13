import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peksen_gida/app.dart';
import 'package:peksen_gida/core/routing/app_router.dart';
import 'package:peksen_gida/core/notifications/push_service.dart';
import 'package:peksen_gida/features/auth/domain/account_repository.dart';
import 'package:peksen_gida/features/auth/presentation/auth_providers.dart';
import 'package:peksen_gida/features/notifications/data/notification_repository.dart';
import 'package:peksen_gida/features/products/presentation/product_providers.dart';
import 'package:peksen_gida/features/products/domain/product_repository.dart';

import 'products_test.dart' show tapText;

const notificationId = '14000000-0000-4000-8000-000000000001';

class NotificationFake implements NotificationRepository {
  bool fail = false, denied = false;
  Completer<void>? loading;
  String route = '/account/finance';
  int opens = 0, reads = 0;
  Map<String, dynamic>? saved;
  final campaigns = <Map<String, dynamic>>[];
  final rows = <Map<String, dynamic>>[
    {
      'id': notificationId,
      'type': 'preparing',
      'body': 'Yeni bir bildiriminiz var.',
      'created_at': '2026-10-13T10:00:00Z',
      'read_at': null,
    },
  ];
  @override
  Future<List<Map<String, dynamic>>> inbox({
    Map<String, dynamic>? before,
  }) async {
    await loading?.future;
    if (fail) throw StateError('Synthetic');
    return before == null ? rows : [];
  }

  @override
  Future<void> markRead(String id) async {
    reads++;
    rows.single['read_at'] = '2026-10-13T11:00:00Z';
  }

  @override
  Future<String> destination(String id) async {
    opens++;
    if (denied) throw StateError('Revoked');
    return route;
  }

  @override
  Future<Map<String, dynamic>?> pendingCampaign() async => saved;
  @override
  Future<void> campaign(Map<String, dynamic> params) async {
    saved = params;
    campaigns.add(params);
    if (fail) throw StateError('Offline');
    saved = null;
  }
}

Future<void> mountNotifications(
  WidgetTester tester,
  NotificationFake fake, {
  AccountRole role = AccountRole.customer,
  String path = '/account/notifications',
}) async {
  final router = createAppRouter(
    previewEnabled: true,
    initialLocation: path,
    isSignedIn: () => true,
  );
  final container = ProviderContainer(
    overrides: [
      appRouterProvider.overrideWithValue(router),
      accountProfileProvider.overrideWith(
        (_) async => AccountProfile(id: 'test', name: 'Test', role: role),
      ),
      notificationRepositoryProvider.overrideWith((_) async => fake),
      productsProvider.overrideWith(
        (_) async => [
          const Product(
            id: notificationId,
            sku: 'TEST',
            name: 'Test ürün',
            baseUnit: 'adet',
            active: true,
            units: [],
          ),
        ],
      ),
      pricingCustomersProvider.overrideWith(
        (_) async => [
          {'id': notificationId, 'company_name': 'Test müşteri'},
        ],
      ),
    ],
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    router.dispose();
  });
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const PeksenGidaApp(),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  test(
    'Push accepts only current recipient and UUID, ignores supplied URL',
    () {
      expect(
        notificationFromPush({
          'user_id': 'a',
          'notification_id': notificationId,
          'route': 'https://evil.invalid',
        }, 'a'),
        notificationId,
      );
      expect(
        notificationFromPush({
          'user_id': 'b',
          'notification_id': notificationId,
        }, 'a'),
        isNull,
      );
      expect(
        notificationFromPush({
          'user_id': 'a',
          'notification_id': '../account',
        }, 'a'),
        isNull,
      );
      expect(
        notificationFromPush({
          'user_id': 'a',
          'notification_id': notificationId,
        }, null),
        isNull,
      );
    },
  );
  test('Only known internal destinations pass allowlist', () {
    for (final route in [
      'https://evil.invalid',
      '/account/admin',
      '//evil.invalid',
      '/account/shop/product/$notificationId?next=evil',
      '/account/sales/../orders',
    ]) {
      expect(allowedNotificationRoute(route), isFalse);
    }
    expect(
      allowedNotificationRoute('/account/shop/product/$notificationId'),
      isTrue,
    );
    expect(
      allowedNotificationRoute(
        '/account/shop/orders/$notificationId/alternatives',
      ),
      isTrue,
    );
    expect(
      allowedNotificationRoute('/account/sales/$notificationId/orders'),
      isTrue,
    );
  });
  test('Generated id has UUID v4 layout and distinct values', () {
    final id = notificationRequestId();
    expect(validNotificationId(id), isTrue);
    expect(id[14], '4');
    expect(notificationRequestId(), isNot(id));
  });
  testWidgets('Inbox works without Firebase and read action is explicit', (
    tester,
  ) async {
    final fake = NotificationFake();
    await mountNotifications(tester, fake);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Cihaz bildirimi yapılandırılmadı'),
      findsOneWidget,
    );
    expect(fake.reads, 0);
    await tapText(tester, 'Okundu işaretle');
    expect(fake.reads, 1);
    expect(find.text('Okundu işaretle'), findsNothing);
  });
  testWidgets('Revoked target remains in inbox with safe error', (
    tester,
  ) async {
    final fake = NotificationFake()..denied = true;
    await mountNotifications(tester, fake);
    await tester.pumpAndSettle();
    await tapText(tester, 'Sipariş hazırlanıyor');
    expect(fake.opens, 1);
    expect(find.textContaining('İşlem tamamlanamadı'), findsOneWidget);
    expect(find.text('Bildirimler'), findsOneWidget);
  });
  testWidgets('Unexpected server path cannot open admin', (tester) async {
    final fake = NotificationFake()..route = '/account/admin';
    await mountNotifications(tester, fake);
    await tester.pumpAndSettle();
    await tapText(tester, 'Sipariş hazırlanıyor');
    expect(find.textContaining('İşlem tamamlanamadı'), findsOneWidget);
  });
  testWidgets('Empty loading and failure states', (tester) async {
    final fake = NotificationFake()
      ..loading = Completer<void>()
      ..rows.clear();
    await mountNotifications(tester, fake);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    fake.loading!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Henüz bildiriminiz yok.'), findsOneWidget);
    fake.fail = true;
    await tester.tap(find.byTooltip('Yenile'));
    await tester.pumpAndSettle();
    expect(
      find.text('Bildirimler yüklenemedi. Yeniden deneyin.'),
      findsOneWidget,
    );
  });
  testWidgets('Customer cannot open campaign form', (tester) async {
    await mountNotifications(
      tester,
      NotificationFake(),
      path: '/account/notifications/campaign',
    );
    await tester.pumpAndSettle();
    expect(find.text('Bu işlem yalnız Manager/Owner içindir.'), findsOneWidget);
  });
  testWidgets('Manager campaign explicit targets and retry keeps same key', (
    tester,
  ) async {
    final fake = NotificationFake()..fail = true;
    await mountNotifications(
      tester,
      fake,
      role: AccountRole.manager,
      path: '/account/notifications/campaign',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Test ürün').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CheckboxListTile));
    await tester.enterText(find.byType(TextField), 'Duyuru gerekçesi');
    await tester.pumpAndSettle();
    await tapText(tester, 'Bildirimi oluştur');
    expect(fake.campaigns.length, 1);
    fake.fail = false;
    await tapText(tester, 'Aynı isteği tekrar dene');
    expect(fake.campaigns.length, 2);
    expect(fake.campaigns[0], fake.campaigns[1]);
    expect(fake.campaigns[0]['customers'], [notificationId]);
    expect(
      find.textContaining('Fiyat ve iskonto değiştirilmedi'),
      findsOneWidget,
    );
  });
  testWidgets('Narrow inbox and back navigation', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await mountNotifications(tester, NotificationFake());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Hesabım'), findsOneWidget);
  });
}
