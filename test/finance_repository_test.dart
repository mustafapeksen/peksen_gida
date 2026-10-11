import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:peksen_gida/features/finance/data/finance_repository.dart';

class _LocalHttp extends HttpOverrides {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Finance SDK preserves large exact cents and durable retry identity across repository recreation',
    () => HttpOverrides.runWithHttpOverrides(() async {
      FlutterSecureStorage.setMockInitialValues({});
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      var fail = true;
      String? sqlFailure;
      var calls = 0;
      Map<String, dynamic>? body;
      server.listen((r) async {
        calls++;
        body = jsonDecode(
          await utf8.decoder.bind(r).join(),
        ) as Map<String, dynamic>;
        r.response.headers.contentType = ContentType.json;
        if (fail) {
          r.response.statusCode = 503;
          r.response.write(
            jsonEncode({'message': 'Synthetic network uncertainty'}),
          );
        } else if (sqlFailure != null) {
          r.response.statusCode = 400;
          r.response.write(
            jsonEncode({
              'code': sqlFailure,
              'message': 'Synthetic SQL rejection',
            }),
          );
        } else {
          r.response.write(
            jsonEncode({'outcome': 'created', 'order_id': 'synthetic-order'}),
          );
        }
        await r.response.close();
      });
      final client = SupabaseClient(
        'http://127.0.0.1:${server.port}',
        'synthetic-public-placeholder',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      Future<void> actor(String id) async {
        final payload = base64Url
            .encode(
              utf8.encode(
                jsonEncode({
                  'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
                }),
              ),
            )
            .replaceAll('=', '');
        await client.auth.setInitialSession(
          jsonEncode({
            'access_token': 'e30.$payload.synthetic',
            'refresh_token': 'synthetic',
            'token_type': 'bearer',
            'user': {
              'id': id,
              'app_metadata': {},
              'user_metadata': {},
              'aud': 'authenticated',
              'created_at': '2026-10-09T00:00:00Z',
            },
          }),
        );
      }

      addTearDown(() async {
        await client.dispose();
        await server.close(force: true);
      });
      await actor('actor-a');
      final repo = SupabaseFinanceRepository(client);
      final params = {
        'target_order': 'order',
        'amount_kurus': '9007199254740993',
        'payment_method': 'cash',
        'payment_note': '',
        'request_key': 'request-a',
      };
      await expectLater(
        repo.perform('record_payment', params),
        throwsA(isA<PostgrestException>()),
      );
      expect(
        (await SupabaseFinanceRepository(client)
            .pending())!['params']['request_key'],
        'request-a',
      );
      await actor('actor-b');
      expect(await repo.pending(), isNull);
      await actor('actor-a');
      await expectLater(
        repo.perform('record_payment', {...params, 'request_key': 'other-key'}),
        throwsStateError,
      );
      expect(calls, 1, reason: 'Conflicting retry must never reach network');
      fail = false;
      await repo.perform('record_payment', params);
      expect(body!['request_key'], 'request-a');
      expect(
        body!['amount_kurus'],
        '9007199254740993',
        reason: 'Never convert exact money to double',
      );
      expect(await repo.pending(), isNull);
      sqlFailure = '22023';
      await expectLater(
        repo.perform('record_payment', {...params, 'request_key': 'request-b'}),
        throwsA(isA<FinanceRejected>()),
      );
      expect(
        await repo.pending(),
        isNull,
        reason:
            'Definitive rollback allows correction instead of endless retry',
      );
    }, _LocalHttp()),
  );
}
