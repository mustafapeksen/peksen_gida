import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';

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

Future<SupabaseClient> initializeSupabaseClient(SupabaseConfig config) async {
  final supabase = await Supabase.initialize(
    url: config.url,
    publishableKey: config.clientKey,
    debug: false,
    authOptions: const FlutterAuthClientOptions(
      localStorage: EmptyLocalStorage(),
      persistSession: false,
      autoRefreshToken: false,
      detectSessionInUri: false,
      pkceAsyncStorage: _DisabledPkceStorage(),
    ),
  );
  return supabase.client;
}

// Phase 3 has no OAuth/code exchange. Avoid the SDK's eager preferences store
// even when session persistence is disabled. Phase 4 must choose secure storage.
final class _DisabledPkceStorage extends GotrueAsyncStorage {
  const _DisabledPkceStorage();

  @override
  Future<String?> getItem({required String key}) async => null;

  @override
  Future<void> setItem({required String key, required String value}) async {
    throw const BackendInitializationException();
  }

  @override
  Future<void> removeItem({required String key}) async {}
}

final class BackendInitializationException implements Exception {
  const BackendInitializationException();

  @override
  String toString() => 'Bağlantı hazırlığı tamamlanamadı.';
}
