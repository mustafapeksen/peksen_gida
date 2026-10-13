import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/networking/supabase_bootstrap.dart';
import '../../auth/presentation/auth_providers.dart';

String notificationRequestId() {
  final random = Random.secure();
  final bytes = List.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final h = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}

bool validNotificationId(String value) => RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
).hasMatch(value);

/// Never navigate to URLs supplied in a push payload or the legacy deep_link field.
bool allowedNotificationRoute(String route) {
  if (route.contains('?')) {
    final uri = Uri.tryParse(route);
    if (uri == null ||
        uri.hasScheme ||
        uri.hasAuthority ||
        uri.hasFragment ||
        !route.startsWith('/account/') ||
        uri.queryParametersAll.length != 1 ||
        uri.queryParametersAll['order']?.length != 1 ||
        !validNotificationId(uri.queryParameters['order'] ?? '')) {
      return false;
    }
    final parts = uri.path.split('/');
    return uri.path == '/account/shop/orders' ||
        uri.path == '/account/inventory' ||
        (parts.length == 5 &&
            parts[1] == 'account' &&
            parts[2] == 'sales' &&
            validNotificationId(parts[3]) &&
            parts[4] == 'orders' &&
            !uri.hasAuthority &&
            !uri.hasScheme);
  }
  if (const {
    '/account/deliveries',
    '/account/tracking',
    '/account/dispatch',
    '/account/inventory',
    '/account/finance',
    '/account/shop/orders',
  }.contains(route)) {
    return true;
  }
  final parts = route.split('/');
  return (parts.length == 5 &&
          parts[1] == 'account' &&
          parts[2] == 'shop' &&
          parts[3] == 'product' &&
          validNotificationId(parts[4])) ||
      (parts.length == 6 &&
          parts[1] == 'account' &&
          parts[2] == 'shop' &&
          parts[3] == 'orders' &&
          validNotificationId(parts[4]) &&
          parts[5] == 'alternatives') ||
      (parts.length == 5 &&
          parts[1] == 'account' &&
          parts[2] == 'sales' &&
          validNotificationId(parts[3]) &&
          parts[4] == 'orders');
}

abstract interface class NotificationRepository {
  Future<List<Map<String, dynamic>>> inbox({Map<String, dynamic>? before});
  Future<void> markRead(String id);
  Future<String> destination(String id);
  Future<Map<String, dynamic>?> pendingCampaign();
  Future<void> campaign(Map<String, dynamic> params);
}

class SupabaseNotificationRepository implements NotificationRepository {
  SupabaseNotificationRepository(this.client);
  final SupabaseClient client;
  final _storage = const FlutterSecureStorage();
  String get _key =>
      'notification-campaign:${client.rest.url}:${client.auth.currentUser!.id}';
  @override
  Future<List<Map<String, dynamic>>> inbox({
    Map<String, dynamic>? before,
  }) async => (await client.rpc(
    'notification_inbox',
    params: {'before_time': before?['created_at'], 'before_id': before?['id']},
  ) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  @override
  Future<void> markRead(String id) async {
    await client.rpc('read_notification', params: {'notification_id': id});
  }

  @override
  Future<String> destination(String id) async {
    if (!validNotificationId(id)) throw StateError('Invalid notification');
    final result = await client.rpc(
      'notification_destination',
      params: {'notification_id': id},
    );
    final route = (result as Map)['route'] as String;
    if (!allowedNotificationRoute(route)) {
      throw StateError('Invalid destination');
    }
    return route;
  }

  @override
  Future<Map<String, dynamic>?> pendingCampaign() async {
    final saved = await _storage.read(key: _key);
    return saved == null
        ? null
        : Map<String, dynamic>.from(jsonDecode(saved) as Map);
  }

  @override
  Future<void> campaign(Map<String, dynamic> params) async {
    final key = _key;
    final previous = await pendingCampaign();
    if (previous != null && jsonEncode(previous) != jsonEncode(params)) {
      throw StateError('Pending request must be resolved first');
    }
    await _storage.write(key: key, value: jsonEncode(params));
    try {
      await client.rpc('create_notification_campaign', params: params);
    } on PostgrestException catch (e) {
      if (const {'22023', '42501', '23514', '22P02'}.contains(e.code)) {
        await _storage.delete(key: key);
      }
      rethrow;
    }
    await _storage.delete(key: key);
  }
}

final notificationRepositoryProvider = FutureProvider<NotificationRepository>((
  ref,
) async {
  final client = await ref.watch(supabaseClientProvider.future);
  if (client == null) throw StateError('Backend unavailable');
  return SupabaseNotificationRepository(client);
});
final notificationInboxProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>(
      retry: (_, _) => null,
      (ref) async {
        final profile = await ref.watch(accountProfileProvider.future);
        if (profile == null) return [];
        return (await ref.watch(notificationRepositoryProvider.future)).inbox();
      },
    );
