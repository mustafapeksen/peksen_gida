import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:peksen_gida/core/config/supabase_config.dart';

String syntheticJwt(String role) {
  final header = base64Url.encode(utf8.encode('{"alg":"HS256"}'));
  final payload = base64Url.encode(utf8.encode(jsonEncode({'role': role})));
  return '$header.$payload.synthetic_signature';
}

void main() {
  test('Boş yapılandırma ağsız önizleme için kapalıdır', () {
    expect(SupabaseConfig.fromValues(url: '  '), isNull);
  });

  test('Public key ve HTTPS kabul edilir, tanılama değerleri gizler', () {
    final config = SupabaseConfig.fromValues(
      url: ' https://test.supabase.co/ ',
      publishableKey: 'sb_publishable_synthetic_test',
    )!;
    expect(config.url, 'https://test.supabase.co');
    expect(config.clientKey, 'sb_publishable_synthetic_test');
    expect(config.toString(), isNot(contains(config.clientKey)));
    expect(config.toString(), isNot(contains(config.url)));
  });

  test(
    'Legacy anon JWT kabul edilir; server tarafından doğrulanmış sayılmaz',
    () {
      expect(
        SupabaseConfig.fromValues(
          url: 'https://test.supabase.co',
          anonKey: syntheticJwt('anon'),
        ),
        isNotNull,
      );
    },
  );

  for (final key in [
    'sb_secret_synthetic_test',
    syntheticJwt('service_role'),
    syntheticJwt('authenticated'),
    'not-a-key',
    'header.invalid.signature',
  ]) {
    test(
      'Yetkili/bozuk anahtar reddedilir: ${key.startsWith('sb_') ? 'secret' : key.length}',
      () {
        expect(
          () => SupabaseConfig.fromValues(
            url: 'https://test.supabase.co',
            anonKey: key,
          ),
          throwsA(isA<SupabaseConfigurationException>()),
        );
        expect(
          const SupabaseConfigurationException().toString(),
          isNot(contains(key)),
        );
      },
    );
  }

  test('Eksik veya çakışan yapılandırma sessizce kapatılmaz', () {
    for (final values in [
      ('https://test.supabase.co', '', ''),
      ('', 'sb_publishable_test', ''),
      ('https://test.supabase.co', 'sb_publishable_test', syntheticJwt('anon')),
    ]) {
      expect(
        () => SupabaseConfig.fromValues(
          url: values.$1,
          publishableKey: values.$2,
          anonKey: values.$3,
        ),
        throwsA(isA<SupabaseConfigurationException>()),
      );
    }
  });

  for (final url in [
    'http://test.supabase.co',
    'https://user:password@test.supabase.co',
    'https://test.supabase.co?key=hidden',
    'https://test.supabase.co#hidden',
    'https://test.supabase.co/rest/v1',
    'not a url',
  ]) {
    test('Güvensiz veya geçersiz URL reddedilir: $url', () {
      expect(
        () => SupabaseConfig.fromValues(
          url: url,
          publishableKey: 'sb_publishable_test',
          allowLocalHttp: true,
        ),
        throwsA(isA<SupabaseConfigurationException>()),
      );
    });
  }

  test('Yerel HTTP yalnız debug izniyle kabul edilir', () {
    for (final host in ['localhost', '127.0.0.1', '10.0.2.2', '[::1]']) {
      final url = 'http://$host:54321';
      expect(
        SupabaseConfig.fromValues(
          url: url,
          publishableKey: 'sb_publishable_test',
          allowLocalHttp: true,
        ),
        isNotNull,
      );
      expect(
        () => SupabaseConfig.fromValues(
          url: url,
          publishableKey: 'sb_publishable_test',
        ),
        throwsA(isA<SupabaseConfigurationException>()),
      );
    }
  });
}
