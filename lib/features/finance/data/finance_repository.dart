import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/networking/supabase_bootstrap.dart';

class FinanceRejected implements Exception {
  const FinanceRejected();
}

abstract interface class FinanceRepository {
  Future<List<Map<String, dynamic>>> read(String section);
  Future<Map<String, dynamic>?> pending();
  Future<void> perform(String action, Map<String, dynamic> params);
}

class SupabaseFinanceRepository implements FinanceRepository {
  SupabaseFinanceRepository(this.client);
  final SupabaseClient client;
  final _storage = const FlutterSecureStorage();
  String get _key =>
      'finance:${client.rest.url}:${client.auth.currentUser!.id}';

  @override
  Future<List<Map<String, dynamic>>> read(String section) async =>
      (await client.rpc(
        'finance_workspace',
        params: {'section': section},
      ) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();

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
      'record_payment',
      'verify_payment',
      'set_customer_credit_limit',
      'decide_credit_approval',
    }.contains(action)) {
      throw const FinanceRejected();
    }
    final request = {'action': action, 'params': params};
    final existing = await pending();
    if (existing != null && jsonEncode(existing) != jsonEncode(request)) {
      throw StateError('Resolve pending finance operation first');
    }
    // Actor/project scoped encrypted recovery. No offline financial operation.
    final storageKey = _key;
    await _storage.write(key: storageKey, value: jsonEncode(request));
    try {
      await client.rpc(action, params: params);
    } on PostgrestException catch (error) {
      if (const {
        '22023',
        '22003',
        '22P02',
        '42501',
        '23514',
        '40001',
        '40P01',
      }.contains(error.code)) {
        await _storage.delete(key: storageKey);
        throw const FinanceRejected();
      }
      rethrow;
    }
    await _storage.delete(key: storageKey);
  }
}

final financeRepositoryProvider = FutureProvider<FinanceRepository>((
  ref,
) async {
  final client = await ref.watch(supabaseClientProvider.future);
  if (client == null) throw StateError('Backend unavailable');
  return SupabaseFinanceRepository(client);
});
