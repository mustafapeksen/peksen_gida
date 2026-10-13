import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/networking/supabase_bootstrap.dart';

class DeliveryRejected implements Exception {
  const DeliveryRejected();
}

abstract interface class DeliveryRepository {
  Future<Map<String, dynamic>> read();
  Future<Map<String, dynamic>?> pending();
  Future<Map<String, dynamic>> perform(
    String action,
    Map<String, dynamic> params,
  );
  Future<void> upload(String path, Uint8List bytes, String mime);
  Future<Uint8List> download(String path);
}

class SupabaseDeliveryRepository implements DeliveryRepository {
  SupabaseDeliveryRepository(this.client);
  final SupabaseClient client;
  final _storage = const FlutterSecureStorage();
  String get _key =>
      'delivery:${client.rest.url}:${client.auth.currentUser!.id}';

  @override
  Future<void> upload(String path, Uint8List bytes, String mime) async {
    if (bytes.isEmpty ||
        bytes.length > 5242880 ||
        evidenceMime(bytes) != mime) {
      throw const DeliveryRejected();
    }
    await client.storage
        .from('delivery-evidence')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: mime, upsert: false),
        );
  }

  @override
  Future<Uint8List> download(String path) =>
      client.storage.from('delivery-evidence').download(path);

  @override
  Future<Map<String, dynamic>> read() async =>
      Map<String, dynamic>.from(await client.rpc('delivery_workspace') as Map);

  @override
  Future<Map<String, dynamic>?> pending() async {
    final value = await _storage.read(key: _key);
    return value == null
        ? null
        : Map<String, dynamic>.from(jsonDecode(value) as Map);
  }

  @override
  Future<Map<String, dynamic>> perform(
    String action,
    Map<String, dynamic> params,
  ) async {
    if (!const {
      'driver_confirm',
      'customer_confirm',
      'dispute',
      'resolve',
      'rate',
      'evidence',
    }.contains(action)) {
      throw const DeliveryRejected();
    }
    final request = {'action': action, 'params': params};
    final existing = await pending();
    if (existing != null && jsonEncode(existing) != jsonEncode(request)) {
      throw StateError('Resolve pending delivery operation first');
    }
    // Actor/project scoped encrypted recovery. No offline delivery operation.
    final storageKey = _key;
    await _storage.write(key: storageKey, value: jsonEncode(request));
    late final Map<String, dynamic> response;
    try {
      response = Map<String, dynamic>.from(
        await client.rpc(
          'delivery_action',
          params: {'action': action, ...params},
        ) as Map,
      );
    } on PostgrestException catch (error) {
      if (const {
        '22023',
        '22003',
        '22P02',
        '42501',
        '23514',
        '23505',
        '40001',
        '40P01',
      }.contains(error.code)) {
        await _storage.delete(key: storageKey);
        throw const DeliveryRejected();
      }
      rethrow;
    }
    await _storage.delete(key: storageKey);
    return response;
  }
}

final deliveryRepositoryProvider = FutureProvider<DeliveryRepository>((
  ref,
) async {
  final client = await ref.watch(supabaseClientProvider.future);
  if (client == null) throw StateError('Backend unavailable');
  return SupabaseDeliveryRepository(client);
});

// Extension/MIME supplied by a file picker is not trusted for UI validation.
String? evidenceMime(Uint8List bytes) {
  if (bytes.length >= 8 &&
      bytes.take(8).join(',') == '137,80,78,71,13,10,26,10') {
    return 'image/png';
  }
  if (bytes.length >= 3 &&
      bytes[0] == 255 &&
      bytes[1] == 216 &&
      bytes[2] == 255) {
    return 'image/jpeg';
  }
  return null;
}
