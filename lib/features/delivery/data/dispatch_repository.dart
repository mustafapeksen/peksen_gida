import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/networking/supabase_bootstrap.dart';

class DispatchRejected implements Exception {
  const DispatchRejected();
}

abstract interface class DispatchRepository {
  Future<Map<String, dynamic>> read();
  Future<Map<String, dynamic>?> pending();
  Future<void> perform(String action, Map<String, dynamic> params);
}

class SupabaseDispatchRepository implements DispatchRepository {
  SupabaseDispatchRepository(this.client);
  final SupabaseClient client;
  final _storage = const FlutterSecureStorage();
  String get _key =>
      'dispatch:${client.rest.url}:${client.auth.currentUser!.id}';

  @override
  Future<Map<String, dynamic>> read() async =>
      Map<String, dynamic>.from(await client.rpc('dispatch_workspace') as Map);

  @override
  Future<Map<String, dynamic>?> pending() async {
    final value = await _storage.read(key: _key);
    return value == null
        ? null
        : Map<String, dynamic>.from(jsonDecode(value) as Map);
  }

  @override
  Future<void> perform(String action, Map<String, dynamic> params) async {
    if (!const {
      'vehicle',
      'create_run',
      'assign',
      'reorder',
      'depart',
      'complete',
      'cancel',
    }.contains(action)) {
      throw const DispatchRejected();
    }
    final request = {'action': action, 'params': params};
    final existing = await pending();
    if (existing != null && jsonEncode(existing) != jsonEncode(request)) {
      throw StateError('Resolve pending dispatch operation first');
    }
    // Actor/project scoped encrypted recovery. No offline dispatch operation.
    final storageKey = _key;
    await _storage.write(key: storageKey, value: jsonEncode(request));
    try {
      await client.rpc(
        'dispatch_action',
        params: {'action': action, ...params},
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
        throw const DispatchRejected();
      }
      rethrow;
    }
    await _storage.delete(key: storageKey);
  }
}

final dispatchRepositoryProvider = FutureProvider<DispatchRepository>((
  ref,
) async {
  final client = await ref.watch(supabaseClientProvider.future);
  if (client == null) throw StateError('Backend unavailable');
  return SupabaseDispatchRepository(client);
});
