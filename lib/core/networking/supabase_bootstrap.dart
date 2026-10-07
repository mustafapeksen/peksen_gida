import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import 'secure_session_storage.dart';

typedef SupabaseInitializer = Future<SupabaseClient> Function(SupabaseConfig);

final supabaseInitializerProvider = Provider<SupabaseInitializer>(
  (ref) => initializeSupabaseClient,
);

/// The app-scoped future runs once; routes never initialize a second client.
final supabaseClientProvider = FutureProvider<SupabaseClient?>(
  retry: (_, _) => null,
  (ref) async {
    try {
      final config = ref.watch(supabaseConfigProvider);
      if (config == null) return null;
      return await ref.watch(supabaseInitializerProvider)(config);
    } catch (_) {
      // SDK errors can carry request details. Do not expose them to UI/logs.
      throw const BackendInitializationException();
    }
  },
);

Future<SupabaseClient> initializeSupabaseClient(
  SupabaseConfig config, {
  LocalStorage? sessionStorage,
}) async {
  final supabase = await Supabase.initialize(
    url: config.url,
    publishableKey: config.clientKey,
    debug: false,
    authOptions: FlutterAuthClientOptions(
      localStorage: sessionStorage ?? SecureSessionStorage(config.url),
      persistSession: true,
      autoRefreshToken: true,
      detectSessionInUri: false,
      authFlowType: AuthFlowType.pkce,
      pkceAsyncStorage: SecurePkceStorage(config.url),
    ),
  );
  return supabase.client;
}

final class BackendInitializationException implements Exception {
  const BackendInitializationException();

  @override
  String toString() => 'Bağlantı hazırlığı tamamlanamadı.';
}
