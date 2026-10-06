import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/account_repository.dart';

final class SupabaseAccountRepository implements AccountRepository {
  SupabaseAccountRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<void> signIn(String email, String password) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      if (response.session == null) throw const SignInException();
    } catch (_) {
      // Never return server diagnostics, credentials or account-existence hints.
      throw const SignInException();
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _client.auth.signOut(scope: SignOutScope.local);
    } catch (_) {
      throw const SignOutException();
    }
  }

  @override
  Future<AccountProfile> loadProfile(String userId) async {
    try {
      if (_client.auth.currentUser?.id != userId) {
        throw const AccountAccessException();
      }
      final row = await _client
          .from('profiles')
          .select('id,name,role,active')
          .eq('id', userId)
          .single();
      return AccountProfile.fromJson(row, userId);
    } catch (_) {
      throw const AccountAccessException();
    }
  }
}
