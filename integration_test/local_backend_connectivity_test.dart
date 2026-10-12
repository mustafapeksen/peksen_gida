// Explicit opt-in physical-device local check. No credentials/URLs printed.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:peksen_gida/core/config/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Physical Android local config, Auth HTTP and Supabase SDK reachability',
    (tester) async {
      final config = SupabaseConfig.fromValues(
        url: const String.fromEnvironment('SUPABASE_URL'),
        publishableKey: const String.fromEnvironment(
          'SUPABASE_PUBLISHABLE_KEY',
        ),
        anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
        allowLocalHttp: true,
      );
      if (config == null || config.url != 'http://192.168.0.100:55321') {
        throw TestFailure(
          'This check requires the configured local LAN endpoint.',
        );
      }
      final http = HttpClient()
        ..connectionTimeout = const Duration(seconds: 15);
      addTearDown(() => http.close(force: true));
      final client = SupabaseClient(
        config.url,
        config.clientKey,
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      addTearDown(client.dispose);
      try {
        final request = await http.getUrl(
          Uri.parse('${config.url}/auth/v1/settings'),
        );
        request.headers.set('apikey', config.clientKey);
        final response = await request.close().timeout(
          const Duration(seconds: 15),
        );
        expect(response.statusCode, 200);
        final body = jsonDecode(await response.transform(utf8.decoder).join());
        expect(body is Map && body['external'] is Map, true);
        // Public SDK key accepted by gateway; RPC must deny this anonymous session.
        try {
          await client
              .rpc('tracking_workspace')
              .timeout(const Duration(seconds: 15));
          throw TestFailure('Anonymous tracking unexpectedly succeeded.');
        } on PostgrestException catch (error) {
          expect(error.code, '42501');
        }
      } catch (_) {
        throw TestFailure(
          'Local backend check failed; request details suppressed.',
        );
      }
    },
  );
}
