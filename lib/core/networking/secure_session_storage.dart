import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Only encrypted platform storage; no preferences/plaintext fallback.
class SecureSessionStorage extends LocalStorage {
  SecureSessionStorage(String url, {FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage(),
      _key = 'peksen.auth.${Uri.encodeComponent(url)}';
  final FlutterSecureStorage _storage;
  final String _key;
  Future<void> _pending = Future.value();

  @override
  Future<void> initialize() async {
    await _storage.containsKey(key: _key);
  }

  @override
  Future<String?> accessToken() async {
    await _pending;
    return _storage.read(key: _key);
  }

  @override
  Future<bool> hasAccessToken() async => await accessToken() != null;

  Future<void> _queue(Future<void> Function() operation) {
    final result = _pending.then(
      (_) => operation(),
      onError: (_) => operation(),
    );
    _pending = result;
    return result;
  }

  @override
  Future<void> persistSession(String persistSessionString) =>
      _queue(() => _storage.write(key: _key, value: persistSessionString));

  @override
  Future<void> removePersistedSession() =>
      _queue(() => _storage.delete(key: _key));
}

/// PKCE verifier storage uses the same encrypted platform store and project
/// isolation as sessions. Email codes are entered in-app; URI detection is off.
class SecurePkceStorage extends GotrueAsyncStorage {
  SecurePkceStorage(String url, {FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage(),
      _prefix = 'peksen.pkce.${Uri.encodeComponent(url)}.';
  final FlutterSecureStorage _storage;
  final String _prefix;

  @override
  Future<String?> getItem({required String key}) =>
      _storage.read(key: '$_prefix$key');
  @override
  Future<void> setItem({required String key, required String value}) =>
      _storage.write(key: '$_prefix$key', value: value);
  @override
  Future<void> removeItem({required String key}) =>
      _storage.delete(key: '$_prefix$key');
}
