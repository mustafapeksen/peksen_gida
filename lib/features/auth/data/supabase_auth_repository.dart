import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/auth_repository.dart';

final class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._auth);

  final GoTrueClient _auth;

  @override
  Stream<AuthSession> watchSession() {
    // Subscribe before emitting the initial snapshot; no async gap loses events.
    late StreamController<AuthSession> controller;
    StreamSubscription<AuthState>? subscription;
    controller = StreamController<AuthSession>(
      onListen: () {
        subscription = _auth.onAuthStateChange.listen(
          (state) => controller.add(_snapshot(state.session)),
          onError: (Object _, StackTrace _) {
            controller.addError(const AuthObservationException());
          },
        );
        controller.add(_snapshot(_auth.currentSession));
      },
      onCancel: () => subscription?.cancel(),
    );
    return controller.stream;
  }

  AuthSession _snapshot(Session? session) => session == null
      ? const AuthSession.signedOut()
      : AuthSession.signedIn(session.user.id);
}
