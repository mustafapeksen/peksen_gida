import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final supabaseConfigProvider = Provider<SupabaseConfig?>((ref) {
  return SupabaseConfig.fromValues(
    url: const String.fromEnvironment('SUPABASE_URL'),
    publishableKey: const String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
    anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
    allowLocalHttp: kDebugMode,
  );
});

/// Build-time public client configuration; never a source of authorization.
final class SupabaseConfig {
  const SupabaseConfig._(this.url, this.clientKey);

  final String url;
  final String clientKey;

  /// No configuration keeps the demo usable without a backend or network.
  static SupabaseConfig? fromValues({
    required String url,
    String publishableKey = '',
    String anonKey = '',
    bool allowLocalHttp = false,
  }) {
    final endpoint = url.trim();
    final publicKey = publishableKey.trim();
    final legacyKey = anonKey.trim();
    if (endpoint.isEmpty && publicKey.isEmpty && legacyKey.isEmpty) return null;
    if (endpoint.isEmpty || (publicKey.isEmpty && legacyKey.isEmpty)) {
      throw const SupabaseConfigurationException();
    }
    if (publicKey.isNotEmpty && legacyKey.isNotEmpty) {
      throw const SupabaseConfigurationException();
    }
    final uri = Uri.tryParse(endpoint);
    const localHosts = {'localhost', '127.0.0.1', '::1', '10.0.2.2'};
    if (uri == null ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/') ||
        !(uri.scheme == 'https' ||
            (allowLocalHttp &&
                uri.scheme == 'http' &&
                localHosts.contains(uri.host)))) {
      throw const SupabaseConfigurationException();
    }
    final key = publicKey.isNotEmpty ? publicKey : legacyKey;
    if (!_isPublicClientKey(key)) {
      throw const SupabaseConfigurationException();
    }
    return SupabaseConfig._(endpoint.replaceFirst(RegExp(r'/$'), ''), key);
  }

  static bool _isPublicClientKey(String key) {
    if (RegExp(r'^sb_publishable_[A-Za-z0-9_-]+$').hasMatch(key)) return true;
    // Reject accidental privileged keys, without claiming JWT verification.
    final parts = key.split('.');
    if (parts.length != 3 || parts.any((part) => part.isEmpty)) return false;
    try {
      final payload = jsonDecode(utf8.decode(base64Url.decode(parts[1])));
      return payload is Map<String, dynamic> && payload['role'] == 'anon';
    } on FormatException {
      return false;
    }
  }

  @override
  String toString() => 'SupabaseConfig(<redacted>)';
}

final class SupabaseConfigurationException implements Exception {
  const SupabaseConfigurationException();

  @override
  String toString() => 'Supabase istemci yapılandırması geçersiz veya eksik.';
}
