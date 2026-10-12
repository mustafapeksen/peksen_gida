// Local-only SDK/Realtime authorization; generated credentials remain in memory.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> sql(String input) async {
  final process = await Process.start('docker', [
    'exec',
    '-i',
    'supabase_db_peksen_gida_phase3_local',
    'psql',
    '-X',
    '-q',
    '-v',
    'ON_ERROR_STOP=1',
    '-U',
    'postgres',
    '-d',
    'postgres',
  ]);
  final output = process.stdout.drain<void>();
  final error = process.stderr.drain<void>();
  process.stdin.write(input);
  await process.stdin.close();
  final code = await process.exitCode;
  await output;
  await error;
  if (code != 0) throw TestFailure('Local SQL failed; output suppressed.');
}

void main() {
  test(
    'Local SDK private channel auth and coordinate-free invalidation',
    () async {
      final url = Platform.environment['PEKSEN_AUTH_TEST_URL'];
      final key = Platform.environment['PEKSEN_AUTH_TEST_KEY'];
      final password = Platform.environment['PEKSEN_AUTH_TEST_INPUT'];
      if (url == null || url != 'http://127.0.0.1:55321' || key == null || password == null) {
        throw TestFailure(
          'Use run-local-auth-check.ps1 with the local fixture.',
        );
      }
      final client = SupabaseClient(
        url,
        key,
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      addTearDown(client.dispose);
      try {
        await client.auth.signInWithPassword(
          email: 'customer.a@peksen.invalid',
          password: password,
        );
      } catch (_) {
        throw TestFailure('Local login failed; sensitive details suppressed.');
      }
      final id = client.auth.currentUser!.id;
      await client.rpc('tracking_workspace');
      final joined = Completer<void>();
      final received = Completer<Map<String, dynamic>>();
      final own = client.channel(
        'tracking:$id',
        opts: const RealtimeChannelConfig(private: true),
      );
      own.onBroadcast(
        event: 'changed',
        callback: (payload) {
          if (!received.isCompleted) received.complete(payload);
        },
      );
      own.subscribe((status, error) {
        if (status == RealtimeSubscribeStatus.subscribed && !joined.isCompleted) {
          joined.complete();
        }
      });
      await joined.future.timeout(
        const Duration(seconds: 20),
        onTimeout: () =>
            throw TestFailure('Private subscription did not become ready.'),
      );
      // Calling the real database helper proves database → private WebSocket delivery.
      await sql('select private.signal_tracking();');
      final payload = await received.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw TestFailure('No private invalidation received.'),
      );
      expect(payload['event'], 'changed');
      final body = Map<String, dynamic>.from(payload['payload'] as Map);
      expect(body['changed'], true);
      // Realtime adds its own message UUID; no application IDs or coordinates.
      expect(body.keys.toSet(), {'id', 'changed'});
      expect(jsonEncode(payload).contains('latitude'), false);
      final foreignDone = Completer<RealtimeSubscribeStatus>();
      final foreign = client.channel(
        'tracking:30000000-0000-4000-8000-000000000008',
        opts: const RealtimeChannelConfig(private: true),
      );
      foreign.subscribe((status, error) {
        if (!foreignDone.isCompleted &&
            (status == RealtimeSubscribeStatus.subscribed ||
                status == RealtimeSubscribeStatus.channelError)) {
          foreignDone.complete(status);
        }
      });
      final foreignStatus = await foreignDone.future.timeout(
        const Duration(seconds: 20),
        onTimeout: () =>
            throw TestFailure('Foreign authorization produced no result.'),
      );
      expect(foreignStatus, RealtimeSubscribeStatus.channelError);
      await client.removeChannel(foreign);
      await client.removeChannel(own);
    },
  );
}
