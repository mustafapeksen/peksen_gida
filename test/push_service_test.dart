import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:peksen_gida/core/notifications/push_service.dart';

class _Network extends HttpOverrides {}

class _Messaging extends Fake implements FirebaseMessaging {
  AuthorizationStatus status = AuthorizationStatus.denied;
  String? token = 'synthetic-local-token';
  Completer<String?>? waiting;
  int permissions = 0, deletes = 0;
  @override
  Future<NotificationSettings> requestPermission({
    bool alert = true,
    bool announcement = false,
    bool badge = true,
    bool carPlay = false,
    bool criticalAlert = false,
    bool provisional = false,
    bool sound = true,
    bool providesAppNotificationSettings = false,
  }) async {
    permissions++;
    return NotificationSettings(
      alert: AppleNotificationSetting.notSupported,
      announcement: AppleNotificationSetting.notSupported,
      authorizationStatus: status,
      badge: AppleNotificationSetting.notSupported,
      carPlay: AppleNotificationSetting.notSupported,
      criticalAlert: AppleNotificationSetting.notSupported,
      lockScreen: AppleNotificationSetting.notSupported,
      notificationCenter: AppleNotificationSetting.notSupported,
      showPreviews: AppleShowPreviewSetting.notSupported,
      timeSensitive: AppleNotificationSetting.notSupported,
      sound: AppleNotificationSetting.notSupported,
      providesAppNotificationSettings: AppleNotificationSetting.notSupported,
    );
  }

  @override
  Future<String?> getToken({
    String? vapidKey,
    String? serviceWorkerScriptPath,
  }) async => waiting == null ? token : waiting!.future;
  @override
  Future<void> deleteToken() async {
    deletes++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Explicit permission, denied/no token handling, session switch and logout binding',
    () => HttpOverrides.runWithHttpOverrides(() async {
      FlutterSecureStorage.setMockInitialValues({});
      final calls = <String>[];
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((r) async {
        await utf8.decoder.bind(r).join();
        calls.add(r.uri.path);
        r.response.headers.contentType = ContentType.json;
        r.response.write('null');
        await r.response.close();
      });
      final client = SupabaseClient(
        'http://127.0.0.1:${server.port}',
        'synthetic-public',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      Future<void> actor(String id) async {
        final payload = base64Url
            .encode(
              utf8.encode(
                jsonEncode({
                  'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
                }),
              ),
            )
            .replaceAll('=', '');
        await client.auth.setInitialSession(
          jsonEncode({
            'access_token': 'e30.$payload.synthetic',
            'refresh_token': 'synthetic',
            'token_type': 'bearer',
            'user': {
              'id': id,
              'app_metadata': {},
              'user_metadata': {},
              'aud': 'authenticated',
              'created_at': '2026-10-13T00:00:00Z',
            },
          }),
        );
      }

      final messaging = _Messaging();
      final service = PushService(client, messaging, (_) {}, () {});
      addTearDown(() async {
        service.dispose();
        await client.dispose();
        await server.close(force: true);
      });
      await actor('user-a');
      expect(messaging.permissions, 0);
      expect(await service.enable(), contains('izni verilmedi'));
      expect(calls, isEmpty);
      messaging.status = AuthorizationStatus.authorized;
      messaging.token = null;
      await expectLater(service.enable(), throwsStateError);
      expect(calls, isEmpty);
      messaging.token = 'synthetic-local-token';
      await service.enable();
      expect(calls.single, endsWith('/register_push_device'));
      messaging.waiting = Completer<String?>();
      final pending = service.enable();
      await Future<void>.delayed(Duration.zero);
      await actor('user-b');
      messaging.waiting!.complete('synthetic-local-token');
      await expectLater(pending, throwsStateError);
      expect(
        calls.length,
        1,
        reason: 'A late token must not bind the wrong session',
      );
      await service.disconnect();
      expect(calls.last, endsWith('/unregister_push_device'));
      expect(messaging.deletes, 1);
    }, _Network()),
  );
}
