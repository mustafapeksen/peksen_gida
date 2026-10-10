import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/networking/supabase_bootstrap.dart';

abstract interface class InventoryRepository {
  Future<List<Map<String, dynamic>>> read(String section);
  Future<void> orderAction(
    String order,
    String action,
    String? item,
    int? quantity,
    String key,
  );
  Future<void> receive(String unit, String quantity, String note, String key);
  Future<void> count(String product, String quantity, String note, String key);
  Future<void> approveCount(String count, String key);
}

class SupabaseInventoryRepository implements InventoryRepository {
  SupabaseInventoryRepository(this.client);
  final SupabaseClient client;
  @override
  Future<List<Map<String, dynamic>>> read(String section) async =>
      (await client.rpc(
        'warehouse_workspace',
        params: {'section': section},
      ) as List).map((row) => Map<String, dynamic>.from(row as Map)).toList();
  @override
  Future<void> orderAction(
    String order,
    String action,
    String? item,
    int? quantity,
    String key,
  ) async {
    await client.rpc(
      'warehouse_order_action',
      params: {
        'target_order': order,
        'action': action,
        'target_item': item,
        'pick_quantity': quantity,
        'request_key': key,
      },
    );
  }

  @override
  Future<void> receive(
    String unit,
    String quantity,
    String note,
    String key,
  ) async {
    await client.rpc(
      'receive_inventory',
      params: {
        'target_unit': unit,
        'quantity': quantity,
        'document_note': note,
        'request_key': key,
      },
    );
  }

  @override
  Future<void> count(
    String product,
    String quantity,
    String note,
    String key,
  ) async {
    await client.rpc(
      'submit_stock_count',
      params: {
        'items': [
          {'product_id': product, 'counted_qty': quantity},
        ],
        'count_note': note,
        'request_key': key,
      },
    );
  }

  @override
  Future<void> approveCount(String count, String key) async {
    await client.rpc(
      'approve_stock_count',
      params: {'target_count': count, 'request_key': key},
    );
  }
}

final inventoryRepositoryProvider = FutureProvider<InventoryRepository>((
  ref,
) async {
  final client = await ref.watch(supabaseClientProvider.future);
  if (client == null) throw StateError('Backend unavailable');
  return SupabaseInventoryRepository(client);
});
