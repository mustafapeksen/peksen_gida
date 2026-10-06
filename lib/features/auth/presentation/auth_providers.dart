import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/networking/supabase_bootstrap.dart';
import '../data/supabase_auth_repository.dart';
import '../domain/auth_repository.dart';
import '../domain/account_repository.dart';
import '../data/supabase_account_repository.dart';

final accountRepositoryProvider = FutureProvider<AccountRepository?>(
  retry: (_, _) => null,
  (ref) async {
    final client = await ref.watch(supabaseClientProvider.future);
    return client == null ? null : SupabaseAccountRepository(client);
  },
);

final accountProfileProvider = FutureProvider.autoDispose<AccountProfile?>(
  retry: (_, _) => null,
  (ref) async {
    // Reading the AsyncValue avoids carrying the previous user's profile through
    // sign-out, token errors or account switches. RLS still authorizes each read.
    final session = ref.watch(authSessionProvider).asData?.value;
    if (session?.status != AuthSessionStatus.signedIn) return null;
    final repository = await ref.watch(accountRepositoryProvider.future);
    if (repository == null) return null;
    return repository.loadProfile(session!.userId!);
  },
);

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
