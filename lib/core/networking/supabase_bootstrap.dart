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
      autoRefreshToken: true,
      detectSessionInUri: false,
      pkceAsyncStorage: _DisabledPkceStorage(),
    ),
  );
  return supabase.client;
}

// Password auth uses an in-memory session. Persistent storage, invitation links
// and recovery deep links await the account lifecycle decision (F4-03).
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
