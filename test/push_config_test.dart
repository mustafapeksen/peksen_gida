import 'package:flutter_test/flutter_test.dart';
import 'package:peksen_gida/core/config/push_config.dart';

void main() {
  test('Empty Firebase config does not require a project for preview', () {
    expect(
      PushConfig.fromValues(apiKey: '', appId: '', senderId: '', projectId: ''),
      isNull,
    );
  });
  test('Incomplete or server credential shaped config is rejected', () {
    for (final key in ['', '-----BEGIN PRIVATE KEY-----', 'service_role']) {
      expect(
        () => PushConfig.fromValues(
          apiKey: key,
          appId: '1:123:android:abcd',
          senderId: '123',
          projectId: 'synthetic-project',
        ),
        throwsA(isA<PushConfigurationException>()),
      );
    }
  });
  test('Android app and sender IDs must agree, diagnostics redact values', () {
    final key = 'AIza${List.filled(35, 'x').join()}';
    final config = PushConfig.fromValues(
      apiKey: key,
      appId: '1:123:android:abcd',
      senderId: '123',
      projectId: 'synthetic-project',
    );
    expect(config!.options.messagingSenderId, '123');
    expect(config.toString(), isNot(contains(key)));
    expect(
      () => PushConfig.fromValues(
        apiKey: key,
        appId: '1:456:android:abcd',
        senderId: '123',
        projectId: 'synthetic-project',
      ),
      throwsA(isA<PushConfigurationException>()),
    );
  });
}
