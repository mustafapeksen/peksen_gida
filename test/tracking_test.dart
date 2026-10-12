import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peksen_gida/app.dart';
import 'package:peksen_gida/core/routing/app_router.dart';
import 'package:peksen_gida/features/auth/domain/account_repository.dart';
import 'package:peksen_gida/features/auth/presentation/auth_providers.dart';
import 'package:peksen_gida/features/tracking/data/tracking_repository.dart';
import 'package:peksen_gida/features/tracking/domain/location_source.dart';
import 'package:peksen_gida/features/tracking/domain/tracking_publisher.dart';
import 'package:peksen_gida/features/tracking/presentation/tracking_map.dart';
import 'package:peksen_gida/features/tracking/presentation/tracking_providers.dart';

class TrackingFake implements TrackingRepository {
  bool allow = true, offline = false, failRead = false;
  final sent = <Map<String, dynamic>>[];
  final actions = <String>[];
  final events = StreamController<void>.broadcast();
  List<Map<String, dynamic>> rows = [
    {
      'id': 'run',
      'plate': 'TEST',
      'can_publish': false,
      'status': 'live',
      'latitude': 41.0,
      'longitude': 29.0,
      'sampled_at': DateTime.now().toUtc().toIso8601String(),
      'stale': false,
    },
  ];
  @override
  Future<List<Map<String, dynamic>>> read() async {
    if (failRead) throw StateError('synthetic failure');
    return rows;
  }

  @override
  Future<bool> control(String run, String publisher, String action) async {
    actions.add(action);
    if (offline) throw StateError('offline');
    return allow;
  }

  @override
  Future<bool> publish(
    String run,
    String publisher,
    Map<String, dynamic> sample,
  ) async {
    sent.add(sample);
    if (offline) throw StateError('offline');
    return allow;
  }

  @override
  Stream<void> changes() => events.stream;
}

class LocationFake implements LocationSource {
  bool permitted = true;
  int starts = 0, stops = 0;
  final controller = StreamController<Map<String, dynamic>>.broadcast();
  @override
  Stream<Map<String, dynamic>> get samples => controller.stream;
  @override
  Future<bool> start() async {
    starts++;
    return permitted;
  }

  @override
  Future<void> stop() async {
    stops++;
  }
}

Future<void> mountTracking(
  WidgetTester tester,
  TrackingFake fake, {
  AccountRole role = AccountRole.customer,
  bool nativeMap = false,
  LocationFake? source,
  String initialLocation = '/account/tracking',
}) async {
  final router = createAppRouter(
    previewEnabled: true,
    initialLocation: initialLocation,
    isSignedIn: () => true,
  );
  final location = source ?? LocationFake();
  final publisher = TrackingPublisher(fake, location);
  final container = ProviderContainer(
    overrides: [
      appRouterProvider.overrideWithValue(router),
      accountProfileProvider.overrideWith(
        (_) async => AccountProfile(id: 'test', name: 'Test', role: role),
      ),
      trackingRepositoryProvider.overrideWith((_) async => fake),
      trackingPublisherProvider.overrideWith((_) async => publisher),
      trackingChangesProvider.overrideWith((_) => fake.changes()),
      if (!nativeMap)
        trackingMapBuilderProvider.overrideWithValue(
          (lat, lon) => Text('map:$lat,$lon'),
        ),
    ],
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    publisher.dispose();
    container.dispose();
    router.dispose();
    await location.controller.close();
    await fake.events.close();
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

Future<void> flushSamples() =>
    Future<void>.delayed(const Duration(milliseconds: 5));
void main() {
  test('publisher denied by server never starts native service', () async {
    final fake = TrackingFake()..allow = false;
    final source = LocationFake();
    final publisher = TrackingPublisher(fake, source);
    await publisher.start('run', 'key');
    expect(source.starts, 0);
    expect(publisher.run, isNull);
    publisher.dispose();
    await source.controller.close();
    await fake.events.close();
  });
  test('permission denied is reported without changing any order', () async {
    final fake = TrackingFake();
    final source = LocationFake()..permitted = false;
    final publisher = TrackingPublisher(fake, source);
    await publisher.start('run', 'key');
    expect(fake.sent.single, {'tracking_status': 'permission_denied'});
    expect(publisher.run, isNull);
    expect(fake.actions, ['start']);
    publisher.dispose();
    await source.controller.close();
    await fake.events.close();
  });
  test('offline sample is never replayed after reconnection', () async {
    final fake = TrackingFake();
    final source = LocationFake();
    final publisher = TrackingPublisher(fake, source);
    await publisher.start('run', 'key');
    fake.offline = true;
    source.controller.add({'tracking_status': 'live', 'latitude': 41});
    await flushSamples();
    fake.offline = false;
    await publisher.checkScope();
    expect(fake.sent.length, 1);
    source.controller.add({'tracking_status': 'live', 'latitude': 42});
    await flushSamples();
    expect(fake.sent.map((e) => e['latitude']), [41, 42]);
    await publisher.stop();
    publisher.dispose();
    await source.controller.close();
    await fake.events.close();
  });
  test(
    'scope end stops native sharing; subsequent samples discarded',
    () async {
      final fake = TrackingFake();
      final source = LocationFake();
      final publisher = TrackingPublisher(fake, source);
      await publisher.start('run', 'key');
      fake.allow = false;
      await publisher.checkScope();
      expect(publisher.run, isNull);
      expect(source.stops, greaterThan(1));
      source.controller.add({'tracking_status': 'live'});
      await flushSamples();
      expect(fake.sent, isEmpty);
      publisher.dispose();
      await source.controller.close();
      await fake.events.close();
    },
  );
  test(
    'dispose immediately revokes local session and stops native service',
    () async {
      final fake = TrackingFake();
      final source = LocationFake();
      final publisher = TrackingPublisher(fake, source);
      await publisher.start('run', 'key');
      publisher.dispose();
      expect(publisher.run, isNull);
      await flushSamples();
      expect(fake.actions.last, 'stop');
      expect(source.stops, greaterThan(1));
      await source.controller.close();
      await fake.events.close();
    },
  );
  testWidgets(
    'customer sees map with no publish button and back returns account',
    (tester) async {
      await mountTracking(tester, TrackingFake());
      await tester.pumpAndSettle();
      expect(find.text('map:41.0,29.0'), findsOneWidget);
      expect(find.text('Konum paylaşımını başlat'), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Hesabım'), findsOneWidget);
    },
  );

  testWidgets(
    'driver without active run explains assignment without permission request',
    (tester) async {
      final fake = TrackingFake()..rows = [];
      final source = LocationFake();
      await mountTracking(
        tester,
        fake,
        role: AccountRole.driver,
        source: source,
      );
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Aktif primary seferiniz yok. Konum paylaşımı için Manager/Owner tarafından primary sürücü olarak atanmanız gerekir.',
        ),
        findsOneWidget,
      );
      expect(find.text('Araç ve seferler'), findsOneWidget);
      expect(find.text('Konum paylaşımını başlat'), findsNothing);
      expect(source.starts, 0);
      expect(fake.actions, isEmpty);
    },
  );
  testWidgets(
    'assistant reads map with explanation and cannot start permission flow',
    (tester) async {
      final source = LocationFake();
      final fake = TrackingFake();
      await mountTracking(
        tester,
        fake,
        role: AccountRole.driver,
        source: source,
      );
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Assistant sürücü haritayı görüntüleyebilir; konum paylaşımı bu fazda primary sürücüye aittir.',
        ),
        findsOneWidget,
      );
      expect(find.text('map:41.0,29.0'), findsOneWidget);
      expect(find.text('Konum paylaşımını başlat'), findsNothing);
      expect(source.starts, 0);
      expect(fake.actions, isEmpty);
    },
  );
  testWidgets('manager is not described as assistant', (tester) async {
    await mountTracking(tester, TrackingFake(), role: AccountRole.manager);
    await tester.pumpAndSettle();
    expect(find.textContaining('Assistant sürücü'), findsNothing);
    expect(find.text('Konum paylaşımını başlat'), findsNothing);
  });
  for (final permitted in [true, false]) {
    testWidgets(
      'primary explicitly starts permission flow; permitted=$permitted',
      (tester) async {
        final fake = TrackingFake();
        fake.rows.single['can_publish'] = true;
        fake.rows.single['status'] = 'off';
        final source = LocationFake()..permitted = permitted;
        await mountTracking(
          tester,
          fake,
          role: AccountRole.driver,
          source: source,
        );
        await tester.pumpAndSettle();
        expect(source.starts, 0);
        expect(fake.actions, isEmpty);
        await tester.ensureVisible(find.text('Konum paylaşımını başlat'));
        await tester.tap(find.text('Konum paylaşımını başlat'));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pumpAndSettle();
        expect(source.starts, 1);
        expect(fake.actions, ['start']);
        if (permitted) {
          expect(find.textContaining('Konum paylaşımı açık.'), findsOneWidget);
          source.controller.add({
            'tracking_status': 'live',
            'latitude': 41,
            'longitude': 29,
          });
          await tester.pumpAndSettle();
          expect(fake.sent.single['latitude'], 41);
          expect(find.text('Konum güncellendi.'), findsOneWidget);
          await tester.ensureVisible(find.text('Paylaşımı durdur'));
          await tester.tap(find.text('Paylaşımı durdur'));
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pumpAndSettle();
          expect(fake.actions, ['start', 'stop']);
        } else {
          expect(
            find.textContaining(
              'Takip sorunu: konum veya bildirim izni verilmedi.',
            ),
            findsOneWidget,
          );
          expect(fake.sent, [
            {'tracking_status': 'permission_denied'},
          ]);
          expect(source.stops, greaterThan(0));
          // Only the tracking control/status API is called; no order/run transition.
          expect(fake.actions, ['start']);
        }
      },
    );
  }
  testWidgets(
    'narrow driver account has touchable tracking/dispatch cards and real route',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await mountTracking(
        tester,
        TrackingFake()..rows = [],
        role: AccountRole.driver,
        initialLocation: '/account',
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('İş ekranları sonraki'), findsNothing);
      for (final title in ['Canlı teslimat konumu', 'Araç ve seferler']) {
        final tile = find.ancestor(
          of: find.text(title),
          matching: find.byType(ListTile),
        );
        expect(tile, findsOneWidget);
        expect(tester.getSize(tile).height, greaterThanOrEqualTo(48));
        expect(tester.widget<ListTile>(tile).onTap, isNotNull);
      }
      await tester.ensureVisible(find.text('Canlı teslimat konumu'));
      await tester.tap(find.text('Canlı teslimat konumu'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Aktif primary seferiniz yok.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Hesabım'), findsOneWidget);
    },
  );
  testWidgets('stale point explicitly warns', (tester) async {
    final fake = TrackingFake();
    fake.rows.single['stale'] = true;
    await mountTracking(tester, fake);
    await tester.pumpAndSettle();
    expect(find.textContaining('Eski konum'), findsOneWidget);
  });
  testWidgets('lost read authorization hides cached point', (tester) async {
    final fake = TrackingFake();
    await mountTracking(tester, fake);
    await tester.pumpAndSettle();
    fake.failRead = true;
    fake.events.add(null);
    await tester.pumpAndSettle();
    expect(find.text('map:41.0,29.0'), findsNothing);
    expect(find.textContaining('Önceki konum gizlendi'), findsOneWidget);
  });
  testWidgets('realtime invalidation clears ended delivery', (tester) async {
    final fake = TrackingFake();
    await mountTracking(tester, fake);
    await tester.pumpAndSettle();
    fake.rows = [];
    fake.events.add(null);
    await tester.pumpAndSettle();
    expect(find.text('map:41.0,29.0'), findsNothing);
    expect(find.text('Takip edilebilir aktif teslimat yok.'), findsOneWidget);
  });
  testWidgets('unauthorized role cannot read tracking', (tester) async {
    await mountTracking(tester, TrackingFake(), role: AccountRole.warehouse);
    await tester.pumpAndSettle();
    expect(find.text('map:41.0,29.0'), findsNothing);
  });
  testWidgets('small screen scrolls primary controls without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fake = TrackingFake();
    fake.rows.single['can_publish'] = true;
    await mountTracking(tester, fake, role: AccountRole.driver);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Konum paylaşımını başlat'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
