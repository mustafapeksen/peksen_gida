import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/networking/supabase_bootstrap.dart';
import '../data/supabase_auth_repository.dart';
import '../domain/auth_repository.dart';

final authRepositoryProvider = FutureProvider<AuthRepository?>(
  retry: (_, _) => null,
  (ref) async {
    final client = await ref.watch(supabaseClientProvider.future);
    return client == null ? null : SupabaseAuthRepository(client.auth);
  },
);

final authSessionProvider = StreamProvider<AuthSession>(retry: (_, _) => null, (
  ref,
) async* {
  final repository = await ref.watch(authRepositoryProvider.future);
  if (repository == null) {
    yield const AuthSession.unavailable();
    return;
  }
  yield* repository.watchSession();
});
