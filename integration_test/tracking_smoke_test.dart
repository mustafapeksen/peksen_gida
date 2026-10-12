import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/tracking_test.dart' show TrackingFake, mountTracking;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
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
