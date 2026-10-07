import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/account_lifecycle.dart';
import '../domain/account_repository.dart';

class SupabaseAccountLifecycle implements AccountLifecycle {
  SupabaseAccountLifecycle(this.client);
  final SupabaseClient client;

  Future<T> _safe<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (_) {
      throw const AccountLifecycleException();
    }
  }

  @override
  Future<void> register(
    String name,
    String company,
    String email,
    String password,
  ) => _safe(() async {
    if (!validNewPassword(password)) throw const AccountLifecycleException();
    await client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {
        'signup_type': 'customer',
        'name': name.trim(),
        'company': company.trim(),
      },
    );
  });
  @override
  Future<void> resend(String email, EmailCodePurpose purpose) =>
      _safe(() async {
        if (purpose == EmailCodePurpose.recovery) {
          await client.auth.resetPasswordForEmail(email.trim());
        } else if (purpose == EmailCodePurpose.signup) {
          await client.auth.resend(type: OtpType.signup, email: email.trim());
        } else {
          // Invite resending is an administrator action; never create an account here.
          throw const AccountLifecycleException();
        }
      });
  @override
  Future<void> verify(
    String email,
    String code,
    EmailCodePurpose purpose,
    String password,
  ) => _safe(() async {
    // A verified invite session may survive a failed password/RPC step or restart.
    // Retrying completion never trusts metadata and SQL still checks the invite.
    final verifiedInvite =
        purpose == EmailCodePurpose.invite &&
        client.auth.currentSession != null &&
        client.auth.currentUser?.email?.toLowerCase() ==
            email.trim().toLowerCase() &&
        client.auth.currentUser?.emailConfirmedAt != null;
    if (verifiedInvite) {
      if (await client.rpc('account_invitation_accepted') == true) {
        return;
      }
    }
    // Validate before consuming a one-time code, so the user can correct input.
    if (purpose != EmailCodePurpose.signup && !validNewPassword(password)) {
      throw const AccountLifecycleException();
    }
    if (!verifiedInvite) {
      await client.auth.verifyOTP(
        email: email.trim(),
        token: code.trim(),
        type: switch (purpose) {
          EmailCodePurpose.signup => OtpType.signup,
          EmailCodePurpose.invite => OtpType.invite,
          EmailCodePurpose.recovery => OtpType.recovery,
        },
      );
    }
    if (purpose != EmailCodePurpose.signup) {
      try {
        await client.auth.updateUser(UserAttributes(password: password));
      } on AuthException catch (error) {
        // A previous attempt may have saved the credential but failed before
        // the DB acceptance. Only this exact invite retry may continue.
        if (purpose != EmailCodePurpose.invite ||
            error.code != 'same_password') {
          rethrow;
        }
      }
    }
    if (purpose == EmailCodePurpose.invite) {
      await client.rpc('accept_account_invitation');
    }
    if (purpose == EmailCodePurpose.recovery) {
      await client.auth.signOut(scope: SignOutScope.global);
    }
  });
  @override
  Future<void> invite(
    String name,
    String email,
    AccountRole role,
    String? customerId,
  ) => _safe(() async {
    final response = await client.functions.invoke(
      'invite-account',
      body: {
        'name': name.trim(),
        'email': email.trim(),
        'role': role.id,
        'customer_id': customerId,
      },
    );
    if (response.status != 200 ||
        response.data is! Map ||
        response.data['ok'] != true) {
      throw const AccountLifecycleException();
    }
  });
  @override
  Future<List<Map<String, dynamic>>> accounts() => _safe(
    () async => client
        .from('profiles')
        .select('id,name,role,active,email')
        .order('name'),
  );
  @override
  Future<List<Map<String, dynamic>>> invitations() => _safe(
    () async => List<Map<String, dynamic>>.from(
      await client.rpc('account_invitations'),
    ),
  );
  @override
  Future<void> revokeInvitation(String id) => _safe(() async {
    await client.rpc(
      'revoke_account_invitation',
      params: {'invitation_id': id},
    );
  });
  @override
  Future<void> setActive(String userId, bool active) => _safe(() async {
    await client.rpc(
      'set_account_active',
      params: {'target_user': userId, 'enabled': active},
    );
  });
  @override
  Future<void> changePassword(String currentPassword, String newPassword) =>
      _safe(() async {
        if (!validNewPassword(newPassword)) {
          throw const AccountLifecycleException();
        }
        final email = client.auth.currentUser?.email;
        if (email == null) throw const AccountLifecycleException();
        await client.auth.signInWithPassword(
          email: email,
          password: currentPassword,
        );
        await client.auth.updateUser(UserAttributes(password: newPassword));
        await client.auth.signOut(scope: SignOutScope.global);
      });
}
