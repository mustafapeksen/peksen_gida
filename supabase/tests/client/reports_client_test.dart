// Real local Auth/PostgREST. Storage alone uses the in-memory plugin fake.
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:peksen_gida/features/reports/data/report_repository.dart';
import 'package:peksen_gida/features/products/presentation/price_page.dart'
    show newOperationKey;

class _LocalHttp extends HttpOverrides {}

void main() {
  final url = Platform.environment['PEKSEN_AUTH_TEST_URL'];
  final key = Platform.environment['PEKSEN_AUTH_TEST_KEY'];
  final password = Platform.environment['PEKSEN_AUTH_TEST_INPUT'];
  if (url == null ||
      key == null ||
      password == null ||
      Uri.parse(url).host != '127.0.0.1') {
    throw StateError('Use the local auth check runner.');
  }
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Real SDK report, Owner salary exact amount/replay and Manager denial',
    () => HttpOverrides.runWithHttpOverrides(() async {
      // Host test lives under supabase/tests, outside analyzer's test/ path.
      // Only native storage is substituted; Auth and PostgREST stay real.
      // ignore: invalid_use_of_visible_for_testing_member
      FlutterSecureStorage.setMockInitialValues({});
      final client = SupabaseClient(
        url,
        key,
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      addTearDown(client.dispose);
      final repo = SupabaseReportRepository(client);
      try {
        await client.auth.signInWithPassword(
          email: 'manager@peksen.invalid',
          password: password,
        );
        final report = await repo.report('2026-10-01', '2026-10-31');
        expect(report['inventory'], isA<List>());
        await expectLater(
          repo.salaries('2026-10-01'),
          throwsA(isA<PostgrestException>()),
        );
        await expectLater(
          repo.audit(null, null),
          throwsA(isA<PostgrestException>()),
        );
        await client.auth.signOut(scope: SignOutScope.local);
        await client.auth.signInWithPassword(
          email: 'owner@peksen.invalid',
          password: password,
        );
        final params = <String, dynamic>{
          'target_employee': '30000000-0000-4000-8000-000000000002',
          'target_month': '2098-01-01',
          'salary_kurus': '9007199254740993',
          'bonus_kurus': '0',
          'reason': 'Synthetic SDK exact money',
          'expected_revision': -1,
          'request_key': newOperationKey(),
        };
        await repo.saveSalary(params);
        await SupabaseReportRepository(client).saveSalary(params);
        expect(await repo.pending(), isNull);
        final workspace = await repo.salaries('2098-01-01');
        expect(
          (workspace['records'] as List).single['salary_kurus'],
          '9007199254740993',
        );
        expect((workspace['history'] as List).length, 1);
        await expectLater(
          repo.saveSalary({...params, 'request_key': newOperationKey()}),
          throwsA(isA<SalaryRejected>()),
        );
        expect(await repo.pending(), isNull);
        final audit = await repo.audit(null, null);
        expect(audit.any((r) => r.containsKey('new_data')), isFalse);
        await client.auth.signOut(scope: SignOutScope.local);
        await expectLater(
          repo.report('2026-10-01', '2026-10-31'),
          throwsA(isA<PostgrestException>()),
        );
      } catch (_) {
        throw TestFailure(
          'Local reports SDK check failed; sensitive details suppressed.',
        );
      }
    }, _LocalHttp()),
  );
}
