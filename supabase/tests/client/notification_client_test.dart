// Real local Auth/PostgREST session, using transient runner credentials.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  test('Real Auth session binds device, isolates history, blocks worker and removes registration', () async {
    final client = SupabaseClient(
      url,
      key,
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    addTearDown(client.dispose);
    const id = '14000000-0000-4000-8000-000000000099';
    try {
      await client.auth.signInWithPassword(
        email: 'customer.a@peksen.invalid',
        password: password,
      );
      await client.rpc(
        'register_push_device',
        params: {
          'device_id': id,
          'device_token': 'synthetic-local-sdk-no-real-fcm-token',
        },
      );
      await client.auth.refreshSession();
      await client.rpc(
        'register_push_device',
        params: {
          'device_id': id,
          'device_token': 'synthetic-local-sdk-no-real-fcm-token',
        },
      );
      expect(await client.rpc('notification_inbox'), isA<List>());
      await expectLater(
        client.rpc('collect_notifications'),
        throwsA(isA<PostgrestException>()),
      );
      await expectLater(
        client.rpc('claim_push_jobs'),
        throwsA(isA<PostgrestException>()),
      );
      await client.rpc('unregister_push_device', params: {'device_id': id});
      await client.auth.signOut(scope: SignOutScope.local);
      await expectLater(
        client.rpc('notification_inbox'),
        throwsA(isA<PostgrestException>()),
      );
    } catch (_) {
      throw TestFailure(
        'Local notification SDK validation failed; sensitive details suppressed.',
      );
    }
  });
}
