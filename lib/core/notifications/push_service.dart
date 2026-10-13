import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/push_config.dart';
import '../networking/supabase_bootstrap.dart';
import '../routing/app_router.dart';
import '../../features/notifications/data/notification_repository.dart';

/// A push carries identity only. Its recipient must match the current session;
/// destination RPC still checks the live role, assignment and entity state.
String? notificationFromPush(Map<String, dynamic> data, String? user) {
  final id = data['notification_id'];
  return user != null &&
          data['user_id'] == user &&
          id is String &&
          validNotificationId(id)
      ? id
      : null;
}

class PushService {
  PushService(this.client, this.messaging, this.onOpened, this.onChanged);
  final SupabaseClient client;
  final FirebaseMessaging messaging;
  final void Function(String) onOpened;
  final void Function() onChanged;
  final _storage = const FlutterSecureStorage();
  final _subscriptions = <StreamSubscription<dynamic>>[];
  Future<void> _serial = Future.value();
  bool _disposed = false;
  String? _user;
  Future<void> _enqueue(Future<void> Function() action) {
    final next = _serial.then((_) async {
      if (!_disposed) await action();
    });
    _serial = next.catchError((Object _) {});
    return next;
  }

  Future<String> _device() async {
    const key = 'push-installation-id';
    final existing = await _storage.read(key: key);
    if (existing != null) return existing;
    final id = notificationRequestId();
    await _storage.write(key: key, value: id);
    return id;
  }

  Future<void> _bind() async {
    final session = client.auth.currentSession;
    if (session == null || _disposed) {
      throw StateError('Active session required');
    }
    final token = await messaging.getToken();
    final device = await _device();
    if (token == null || _disposed || client.auth.currentSession != session) {
      throw StateError('Device registration unavailable');
    }
    await client.rpc(
      'register_push_device',
      params: {'device_id': device, 'device_token': token},
    );
  }

  Future<void> start() async {
    _user = client.auth.currentUser?.id;
    _subscriptions.add(
      client.auth.onAuthStateChange.listen((event) {
        final nextUser = event.session?.user.id;
        final changed = nextUser != _user;
        _user = nextUser;
        unawaited(
          _enqueue(() async {
            if (changed) await messaging.deleteToken();
            if ((await messaging.getNotificationSettings())
                    .authorizationStatus ==
                AuthorizationStatus.authorized) {
              await _bind();
            }
          }).catchError((Object _) {}),
        );
      }),
    );
    _subscriptions.add(
      messaging.onTokenRefresh.listen((_) {
        unawaited(_enqueue(_bind).catchError((Object _) {}));
      }),
    );
    _subscriptions.add(
      FirebaseMessaging.onMessage.listen((message) {
        if (notificationFromPush(message.data, client.auth.currentUser?.id) !=
            null) {
          onChanged();
        }
      }),
    );
    _subscriptions.add(
      FirebaseMessaging.onMessageOpenedApp.listen(
        (message) => unawaited(_open(message)),
      ),
    );
    final initial = await messaging.getInitialMessage();
    if (initial != null) await _open(initial);
    if ((await messaging.getNotificationSettings()).authorizationStatus ==
        AuthorizationStatus.authorized) {
      await _enqueue(_bind);
    }
  }

  Future<void> _open(RemoteMessage message) async {
    final user = client.auth.currentUser?.id;
    final id = notificationFromPush(message.data, user);
    if (id == null || _disposed) return;
    try {
      final route = await SupabaseNotificationRepository(client)
          .destination(id);
      if (!_disposed && user == client.auth.currentUser?.id) {
        onChanged();
        onOpened(route);
      }
    } catch (_) {
      if (!_disposed) onOpened('/account/notifications');
    }
  }

  Future<String> enable() async {
    if (client.auth.currentSession == null) return 'Önce oturum açın.';
    final settings = await messaging.requestPermission();
    if (settings.authorizationStatus != AuthorizationStatus.authorized) {
      return 'Bildirim izni verilmedi. Geçmişi uygulamadan okuyabilirsiniz; izni Android ayarlarından değiştirebilirsiniz.';
    }
    await _enqueue(_bind);
    return 'Bu cihaz için bildirim kaydı tamamlandı.';
  }

  Future<void> disconnect() => _enqueue(() async {
    try {
      await client.rpc(
        'unregister_push_device',
        params: {'device_id': await _device()},
      );
    } finally {
      await messaging.deleteToken();
    }
  });
  void dispose() {
    _disposed = true;
    for (final sub in _subscriptions) {
      unawaited(sub.cancel());
    }
  }
}

final pushServiceProvider = FutureProvider<PushService?>(
  retry: (_, _) => null,
  (ref) async {
    final config = ref.watch(pushConfigProvider);
    if (config == null) return null;
    final client = await ref.watch(supabaseClientProvider.future);
    if (client == null) return null;
    await Firebase.initializeApp(options: config.options);
    if (!ref.mounted) return null;
    final service = PushService(
      client,
      FirebaseMessaging.instance,
      (route) {
        if (ref.mounted) ref.read(appRouterProvider).go(route);
      },
      () {
        if (ref.mounted) ref.invalidate(notificationInboxProvider);
      },
    );
    ref.onDispose(service.dispose);
    await service.start();
    return service;
  },
);
