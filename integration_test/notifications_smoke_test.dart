import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/notifications_test.dart'
    show NotificationFake, mountNotifications;
import '../test/products_test.dart' show tapText;
import '../test/notification_focus_test.dart' show mountNotificationFocus, otherOrder;
import '../test/notifications_test.dart' show notificationId;
import 'package:peksen_gida/features/auth/domain/account_repository.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Android notification opens only its order and Warehouse preparation', (tester) async {
    await mountNotificationFocus(tester, AccountRole.customer);
    await tapText(tester, 'Sipariş hazırlanıyor');
    expect(find.text('Sipariş detayı'), findsOneWidget);
    expect(find.textContaining(notificationId), findsOneWidget);
    expect(find.textContaining(otherOrder), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Android Warehouse notification opens its preparation record', (tester) async {
    await mountNotificationFocus(tester, AccountRole.warehouse);
    await tapText(tester, 'Sipariş hazırlanıyor');
    expect(find.textContaining(notificationId), findsOneWidget);
    expect(find.textContaining(otherOrder), findsNothing);
    expect(find.text('Toplamayı başlat'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Android notification inbox read, denied deep link and back', (
    tester,
  ) async {
    final fake = NotificationFake()..denied = true;
    await mountNotifications(tester, fake);
    await tester.pumpAndSettle();
    await tapText(tester, 'Sipariş hazırlanıyor');
    expect(find.textContaining('İşlem tamamlanamadı'), findsOneWidget);
    await tapText(tester, 'Okundu işaretle');
    expect(fake.reads, 1);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Hesabım'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
