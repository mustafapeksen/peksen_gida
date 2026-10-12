import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

/// Public map configuration, independent of the location sharing policy.
/// Never use a server secret in a style URL: build-time values are extractable.
final class MapStyleConfig {
  const MapStyleConfig._(this.styleUrl);
  final String styleUrl;

  static MapStyleConfig? parse(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    final uri = Uri.tryParse(trimmed);
    if (uri == null ||
        trimmed.contains(RegExp(r'\s')) ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.host.contains(RegExp(r'\s')) ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment) {
      throw const MapStyleConfigurationException();
    }
    return MapStyleConfig._(uri.toString());
  }
}

final class MapStyleConfigurationException implements Exception {
  const MapStyleConfigurationException();
  @override
  String toString() =>
      'Harita stili yapılandırılamadı. Geçerli bir HTTPS adresi gerekir.';
}

final mapStyleConfigProvider = Provider<MapStyleConfig?>((ref) {
  const configured = String.fromEnvironment('MAP_STYLE_URL');
  return MapStyleConfig.parse(
    configured.isEmpty && kDebugMode
        ? 'https://demotiles.maplibre.org/style.json'
        : configured,
  );
});
