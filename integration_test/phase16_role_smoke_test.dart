// One Android run exercises existing screens for all seven roles. These UI
// fixtures do not pretend to be real Auth/RLS; seven_role_e2e_test covers that.
// On a personal device pass --no-uninstall, then restore the saved same-signed
// APK with adb install -r. An APK backup alone cannot restore app/session data.
import 'customer_checkout_smoke_test.dart' as customer;
import 'sales_checkout_smoke_test.dart' as sales;
import 'inventory_smoke_test.dart' as warehouse;
import 'finance_smoke_test.dart' as finance;
import 'dispatch_smoke_test.dart' as driver;
import 'delivery_smoke_test.dart' as delivery;
import 'reports_smoke_test.dart' as management;
import 'notifications_smoke_test.dart' as notifications;

void main() {
  customer.main();
  sales.main();
  warehouse.main();
  finance.main();
  driver.main();
  delivery.main();
  management.main();
  notifications.main();
}
