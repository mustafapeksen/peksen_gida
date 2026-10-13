import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Public Android Firebase identifiers only. No server credential is accepted.
/// Empty configuration leaves the application and notification inbox usable.
class PushConfig {
  const PushConfig._(this.options);
  final FirebaseOptions options;

  static PushConfig? fromValues({
    required String apiKey,
    required String appId,
    required String senderId,
    required String projectId,
  }) {
    if ([apiKey, appId, senderId, projectId].every((value) => value.isEmpty)) {
      return null;
    }
    if (!RegExp(r'^AIza[A-Za-z0-9_-]{35}$').hasMatch(apiKey) ||
        !RegExp(r'^[0-9]+$').hasMatch(senderId) ||
        !RegExp(r'^[a-z][a-z0-9-]{4,28}[a-z0-9]$').hasMatch(projectId) ||
        !RegExp('^1:$senderId:android:[a-fA-F0-9]+\$').hasMatch(appId)) {
      throw const PushConfigurationException();
    }
    return PushConfig._(
      FirebaseOptions(
        apiKey: apiKey,
        appId: appId,
        messagingSenderId: senderId,
        projectId: projectId,
      ),
    );
  }

  @override
  String toString() => 'PushConfig(<redacted>)';
}

class PushConfigurationException implements Exception {
  const PushConfigurationException();
  @override
  String toString() => 'Bildirim yapılandırması eksik veya geçersiz.';
}

final pushConfigProvider = Provider<PushConfig?>(
  (ref) => PushConfig.fromValues(
    apiKey: const String.fromEnvironment('FIREBASE_API_KEY'),
    appId: const String.fromEnvironment('FIREBASE_APP_ID'),
    senderId: const String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID'),
    projectId: const String.fromEnvironment('FIREBASE_PROJECT_ID'),
  ),
);
