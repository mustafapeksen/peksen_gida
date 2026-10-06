enum AccountRole {
  customer('customer', 'Müşteri'),
  salesOperator('sales_operator', 'Saha satış'),
  warehouse('warehouse', 'Depo'),
  accounting('accounting', 'Muhasebe'),
  driver('driver', 'Sürücü'),
  manager('manager', 'Yönetici'),
  owner('owner', 'İşletme sahibi');

  const AccountRole(this.id, this.label);
  final String id;
  final String label;
}

/// A database profile, never a preview selection or user metadata role.
final class AccountProfile {
  const AccountProfile({
    required this.id,
    required this.name,
    required this.role,
  });
  final String id;
  final String name;
  final AccountRole role;

  factory AccountProfile.fromJson(Map<String, dynamic> row, String expectedId) {
    final role = AccountRole.values
        .where((r) => r.id == row['role'])
        .firstOrNull;
    if (role == null ||
        row['id'] != expectedId ||
        row['active'] != true ||
        row['name'] is! String) {
      throw const AccountAccessException();
    }
    return AccountProfile(
      id: expectedId,
      name: row['name'] as String,
      role: role,
    );
  }
}

abstract interface class AccountRepository {
  Future<void> signIn(String email, String password);
  Future<void> signOut();
  Future<AccountProfile> loadProfile(String userId);
}

final class AccountAccessException implements Exception {
  const AccountAccessException();
  @override
  String toString() =>
      'Hesap erişimi doğrulanamadı. Hesabınızın ve müşteri üyeliğinizin etkin olduğunu kontrol edin.';
}

final class SignInException implements Exception {
  const SignInException();
  @override
  String toString() =>
      'Giriş yapılamadı. E-posta, parola ve bağlantınızı kontrol edin.';
}

final class SignOutException implements Exception {
  const SignOutException();
  @override
  String toString() =>
      'Çıkış tamamlanamadı. Bağlantınızı kontrol edip tekrar deneyin.';
}
