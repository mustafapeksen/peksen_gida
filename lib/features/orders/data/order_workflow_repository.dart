import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/networking/supabase_bootstrap.dart';

abstract interface class OrderWorkflowRepository {
  Future<Map<String, dynamic>> state(String orderId);
  Future<void> act(String orderId, String action, String reason, String key);
}

class SupabaseOrderWorkflowRepository implements OrderWorkflowRepository {
  SupabaseOrderWorkflowRepository(this.client);
  final SupabaseClient client;

  @override
  Future<Map<String, dynamic>> state(String orderId) async =>
      Map<String, dynamic>.from(
        await client.rpc(
          'order_workflow_state',
          params: {'target_order': orderId},
        ) as Map,
      );

  @override
  Future<void> act(
    String orderId,
    String action,
    String reason,
    String key,
  ) async {
    await client.rpc(
      'request_order_action',
      params: {
        'target_order': orderId,
        'requested_action': action,
        'request_reason': reason,
        'request_key': key,
      },
    );
  }
}

final orderWorkflowRepositoryProvider = FutureProvider<OrderWorkflowRepository>(
  (ref) async {
    final client = await ref.watch(supabaseClientProvider.future);
    if (client == null) throw StateError('Backend unavailable');
    return SupabaseOrderWorkflowRepository(client);
  },
);
