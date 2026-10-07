import 'dart:convert';

import 'account_repository.dart';

String? newPasswordError(String value) {
  if (value.runes.length < 8) return 'Parola en az 8 karakter olmalıdır.';
  if (utf8.encode(value).length > 72) {
    return 'Parola çok uzun. Daha kısa bir parola seçin.';
  }
  return null;
}

bool validNewPassword(String value) => newPasswordError(value) == null;

enum EmailCodePurpose { signup, invite, recovery }

abstract interface class AccountLifecycle {
  Future<void> register(
    String name,
    String company,
    String email,
    String password,
  );
  Future<void> resend(String email, EmailCodePurpose purpose);
  Future<void> verify(
    String email,
    String code,
    EmailCodePurpose purpose,
    String password,
  );
  Future<void> invite(
    String name,
    String email,
    AccountRole role,
    String? customerId,
  );
  Future<List<Map<String, dynamic>>> accounts();
  Future<List<Map<String, dynamic>>> invitations();
  Future<void> revokeInvitation(String id);
  Future<void> setActive(String userId, bool active);
  Future<void> changePassword(String currentPassword, String newPassword);
}

class AccountLifecycleException implements Exception {
  const AccountLifecycleException();
  @override
  String toString() =>
      'İşlem tamamlanamadı. Bilgileri, kodun süresini ve hesap yetkinizi kontrol edin.';
}
