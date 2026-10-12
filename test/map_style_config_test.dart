import 'package:flutter_test/flutter_test.dart';
import 'package:peksen_gida/core/config/map_style_config.dart';

void main() {
  test('Absent map configuration does not select an unapproved provider', () {
    expect(MapStyleConfig.parse(''), isNull);
    expect(MapStyleConfig.parse('  '), isNull);
  });

  test('HTTPS provider path and public query remain intact', () {
    final config = MapStyleConfig.parse(
      ' https://tiles.example.invalid/styles/main.json?variant=light ',
    );
    expect(
      config!.styleUrl,
      'https://tiles.example.invalid/styles/main.json?variant=light',
    );
  });

  for (final value in [
    'http://tiles.example.invalid/style.json',
    'file:///private/style.json',
    '/style.json',
    'https://',
    'https://bad host/style.json',
    'https://user:synthetic-value@tiles.example.invalid/style.json',
    'https://tiles.example.invalid/style.json#fragment',
  ]) {
    test('Reject unsafe or malformed map configuration: $value', () {
      expect(
        () => MapStyleConfig.parse(value),
        throwsA(isA<MapStyleConfigurationException>()),
      );
    });
  }

  test('Invalid configuration error never echoes supplied credentials', () {
    try {
      MapStyleConfig.parse('https://user:synthetic-value@example.invalid/map');
      fail('Credential-bearing URL must be rejected');
    } on MapStyleConfigurationException catch (error) {
      expect(error.toString(), isNot(contains('synthetic-value')));
      expect(error.toString(), isNot(contains('example.invalid')));
    }
  });
}
