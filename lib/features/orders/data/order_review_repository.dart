import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/networking/supabase_bootstrap.dart';

abstract interface class OrderReviewRepository {
  Future<List<Map<String, dynamic>>> requests();
  Future<void> decide(String request, bool approve, String note, String key);
  Future<Map<String, dynamic>> alternatives(String order);
  Future<void> propose(String item, String unit, int quantity, String key);
  Future<void> respond(String offer, bool accept, String key);
}

class SupabaseOrderReviewRepository implements OrderReviewRepository {
  SupabaseOrderReviewRepository(this.client);
  final SupabaseClient client;
  @override
  Future<List<Map<String, dynamic>>> requests() async =>
      (await client.rpc('order_review_requests') as List)
          .map((r) => Map<String, dynamic>.from(r as Map))
          .toList();
  @override
  Future<void> decide(
    String request,
    bool approve,
    String note,
    String key,
  ) async {
    await client.rpc(
      'decide_order_request',
      params: {
        'target_request': request,
        'approve_request': approve,
        'decision_note': note,
        'request_key': key,
      },
    );
  }

  @override
  Future<Map<String, dynamic>> alternatives(String order) async =>
      Map<String, dynamic>.from(
        await client.rpc('order_alternatives', params: {'target_order': order})
            as Map,
      );
  @override
  Future<void> propose(
    String item,
    String unit,
    int quantity,
    String key,
  ) async {
    await client.rpc(
      'propose_order_alternative',
      params: {
        'target_item': item,
        'target_unit': unit,
        'quantity': quantity,
        'request_key': key,
      },
    );
  }

  @override
  Future<void> respond(String offer, bool accept, String key) async {
    await client.rpc(
      'respond_order_alternative',
      params: {
        'target_offer': offer,
        'accept_offer': accept,
        'request_key': key,
      },
    );
  }
}

final orderReviewRepositoryProvider = FutureProvider<OrderReviewRepository>((
  ref,
) async {
  final client = await ref.watch(supabaseClientProvider.future);
  if (client == null) throw StateError('Backend unavailable');
  return SupabaseOrderReviewRepository(client);
});
