/// Observed SDK session state. It does not carry a role or grant access.
enum AuthSessionStatus { unavailable, signedOut, signedIn }

final class AuthSession {
  const AuthSession.unavailable()
    : status = AuthSessionStatus.unavailable,
      userId = null;
  const AuthSession.signedOut()
    : status = AuthSessionStatus.signedOut,
      userId = null;
  const AuthSession.signedIn(this.userId) : status = AuthSessionStatus.signedIn;

  final AuthSessionStatus status;
  final String? userId;
}

/// Phase 3 exposes observation only. Sign-in/registration belong to Phase 4.
abstract interface class AuthRepository {
  Stream<AuthSession> watchSession();
}

final class AuthObservationException implements Exception {
  const AuthObservationException();

  @override
  String toString() => 'Oturum durumu izlenemedi.';
}
