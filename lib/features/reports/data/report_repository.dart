import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/networking/supabase_bootstrap.dart';

class SalaryRejected implements Exception {
  const SalaryRejected();
}

abstract interface class ReportRepository {
  Future<Map<String, dynamic>> report(String start, String end);
  Future<Map<String, dynamic>> salaries(String month);
  Future<List<Map<String, dynamic>>> audit(
    String? beforeTime,
    String? beforeId,
  );
  Future<Map<String, dynamic>?> pending();
  Future<void> saveSalary(Map<String, dynamic> params);
}

class SupabaseReportRepository implements ReportRepository {
  SupabaseReportRepository(this.client);
  final SupabaseClient client;
  final _storage = const FlutterSecureStorage();
  String get _key => 'salary:${client.rest.url}:${client.auth.currentUser!.id}';

  @override
  Future<Map<String, dynamic>> report(String start, String end) async =>
      Map<String, dynamic>.from(
        await client.rpc(
          'management_report',
          params: {'start_day': start, 'end_day': end},
        ) as Map,
      );

  @override
  Future<Map<String, dynamic>> salaries(String month) async =>
      Map<String, dynamic>.from(
        await client.rpc(
          'owner_salary_workspace',
          params: {'target_month': month},
        ) as Map,
      );

  @override
  Future<List<Map<String, dynamic>>> audit(
    String? beforeTime,
    String? beforeId,
  ) async => (await client.rpc(
    'owner_audit_page',
    params: {'before_time': beforeTime, 'before_id': beforeId},
  ) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();

  @override
  Future<Map<String, dynamic>?> pending() async {
    final value = await _storage.read(key: _key);
    return value == null
        ? null
        : Map<String, dynamic>.from(jsonDecode(value) as Map);
  }

  @override
  Future<void> saveSalary(Map<String, dynamic> params) async {
    final existing = await pending();
    if (existing != null && jsonEncode(existing) != jsonEncode(params)) {
      throw StateError('Resolve pending salary request first');
    }
    final storageKey = _key;
    await _storage.write(key: storageKey, value: jsonEncode(params));
    try {
      await client.rpc('save_salary', params: params);
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
        throw const SalaryRejected();
      }
      rethrow;
    }
    await _storage.delete(key: storageKey);
  }
}

final reportRepositoryProvider = FutureProvider<ReportRepository>((ref) async {
  final client = await ref.watch(supabaseClientProvider.future);
  if (client == null) throw StateError('Backend unavailable');
  return SupabaseReportRepository(client);
});
