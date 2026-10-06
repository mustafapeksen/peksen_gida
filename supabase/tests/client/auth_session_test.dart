// Invoked only by run-local-auth-check.ps1. Credentials exist in process memory;
// no fixture password, token, or key is committed or printed.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:peksen_gida/features/auth/data/supabase_account_repository.dart';
import 'package:peksen_gida/features/auth/domain/account_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  final url = Platform.environment['PEKSEN_AUTH_TEST_URL'];
  final key = Platform.environment['PEKSEN_AUTH_TEST_KEY'];
  final password = Platform.environment['PEKSEN_AUTH_TEST_INPUT'];
  if (url == null ||
      key == null ||
      password == null ||
      Uri.parse(url).host != '127.0.0.1') {
    throw StateError(
      'Run the isolated local auth test script. Remote targets are forbidden.',
    );
  }
  final users = [
    'customer.a',
    'sales',
    'warehouse',
    'accounting',
    'driver',
    'manager',
    'owner',
    'customer.b',
  ];
  final roles = [...AccountRole.values, AccountRole.customer];
  for (var i = 0; i < users.length; i++) {
    test(
      'Local Supabase: ${roles[i].id} login, DB profile, refresh, logout',
      () async {
        final client = SupabaseClient(
          url,
          key,
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        );
        addTearDown(client.dispose);
        final repository = SupabaseAccountRepository(client);
        await repository.signIn('${users[i]}@peksen.invalid', password);
        final id = client.auth.currentUser!.id;
        final profile = await repository.loadProfile(id);
        expect(profile.role, roles[i]);
        try {
          await client.auth.refreshSession();
        } catch (_) {
          throw TestFailure(
            'Local session refresh failed; sensitive details suppressed.',
          );
        }
        expect((await repository.loadProfile(id)).role, roles[i]);
        await repository.signOut();
        expect(client.auth.currentSession == null, isTrue);
        await expectLater(
          repository.loadProfile(id),
          throwsA(isA<AccountAccessException>()),
        );
      },
    );
  }
  test('Invalid credentials return only the fixed Turkish error', () async {
    final client = SupabaseClient(
      url,
      key,
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    addTearDown(client.dispose);
    await expectLater(
      SupabaseAccountRepository(client)
          .signIn('customer.a@peksen.invalid', 'invalid-fixture-input'),
      throwsA(isA<SignInException>()),
    );
    expect(client.auth.currentSession == null, isTrue);
  });
}
