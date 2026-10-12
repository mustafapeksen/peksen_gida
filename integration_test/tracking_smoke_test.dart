import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:peksen_gida/features/auth/domain/account_repository.dart';

import '../test/tracking_test.dart'
    show TrackingFake, LocationFake, mountTracking;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Driver account opens no-run explanation without requesting GPS',
    (tester) async {
      final source = LocationFake();
      final repository = TrackingFake()..rows = [];
      await mountTracking(
        tester,
        repository,
        role: AccountRole.driver,
        source: source,
        initialLocation: '/account',
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Canlı teslimat konumu'));
      await tester.tap(find.text('Canlı teslimat konumu'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Aktif primary seferiniz yok.'),
        findsOneWidget,
      );
      expect(find.text('Araç ve seferler'), findsOneWidget);
      expect(source.starts, 0);
      expect(repository.actions, isEmpty);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Hesabım'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Driver primary denial is visible after explicit action (fake GPS)',
    (tester) async {
      final source = LocationFake()..permitted = false;
      final repository = TrackingFake();
      repository.rows.single['can_publish'] = true;
      await mountTracking(
        tester,
        repository,
        role: AccountRole.driver,
        source: source,
      );
      await tester.pumpAndSettle();
      expect(source.starts, 0);
      await tester.ensureVisible(find.text('Konum paylaşımını başlat'));
      await tester.tap(find.text('Konum paylaşımını başlat'));
      await tester.pumpAndSettle();
      expect(source.starts, 1);
      expect(
        find.textContaining(
          'Takip sorunu: konum veya bildirim izni verilmedi.',
        ),
        findsOneWidget,
      );
      expect(repository.sent.single, {'tracking_status': 'permission_denied'});
      expect(repository.actions, ['start']);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Android native MapLibre screen and system back', (tester) async {
    await mountTracking(tester, TrackingFake(), nativeMap: true);
    // Native style/network rendering is not a real-device GPS acceptance test.
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('Canlı teslimat konumu'), findsOneWidget);
    expect(find.text('Araç: TEST'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Hesabım'), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
  });
}
