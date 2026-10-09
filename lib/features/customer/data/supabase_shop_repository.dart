import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/shop_repository.dart';

class SupabaseShopRepository implements ShopRepository {
  SupabaseShopRepository(this.client);
  final SupabaseClient client;
  final _storage = const FlutterSecureStorage();
  String _pendingKey(String customerId) =>
      'checkout:${client.rest.url}:${client.auth.currentUser!.id}:$customerId';
  @override
  Future<Map<String, dynamic>?> pendingCheckout(String customerId) async {
    final value = await _storage.read(key: _pendingKey(customerId));
    return value == null
        ? null
        : Map<String, dynamic>.from(jsonDecode(value) as Map);
  }

  @override
  Future<List<Map<String, dynamic>>> orders(String customerId) async =>
      await client
          .from('orders')
          .select(
            'id,status,total_kurus,credit_check_state,created_at,order_items(unit,quantity,conversion_to_base_snapshot,line_total_kurus,exact_final_price_kurus_snapshot)',
          )
          .eq('customer_id', customerId)
          .order('created_at', ascending: false);
  @override
  Future<String> customerId(String userId) async {
    final row = await client
        .from('customer_users')
        .select('customer_id')
        .eq('user_id', userId)
        .eq('active', true)
        .single();
    return row['customer_id'] as String;
  }

  @override
  Future<List<CatalogProduct>> catalog(String customerId) async =>
      (await client.rpc(
            'customer_catalog',
            params: {'target_customer': customerId},
          ) as List)
          .map(
            (p) => CatalogProduct.fromJson(Map<String, dynamic>.from(p as Map)),
          )
          .toList();
  @override
  Future<Map<String, dynamic>> quote(
    String customerId,
    List<CartLine> lines,
  ) async => Map<String, dynamic>.from(
    await client.rpc(
      'quote_cart',
      params: {
        'target_customer': customerId,
        'items': lines.map((l) => l.toJson()).toList(),
      },
    ) as Map,
  );

  @override
  Future<void> saveDraft(String customerId, List<CartLine> lines) async {
    await client.rpc(
      'save_cart_draft',
      params: {
        'target_customer': customerId,
        'items': lines.map((l) => l.toJson()).toList(),
      },
    );
  }

  @override
  Future<List<Map<String, dynamic>>?> loadDraft(String customerId) async {
    final value = await client.rpc(
      'load_cart_draft',
      params: {'target_customer': customerId},
    );
    return (value as List?)
        ?.map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  @override
  Future<Map<String, dynamic>> checkout(
    String customerId,
    List<CartLine> lines,
    Map<String, dynamic> quote,
    String key,
  ) async {
    // Persist the retry identity before sending, including process termination.
    // This is recovery of an online request, not offline order submission.
    final storageKey = _pendingKey(customerId);
    final request = {
      'key': key,
      'quote': quote,
      'lines': [
        for (final l in lines)
          {
            ...l.toJson(),
            'product_name': l.productName,
            'unit_name': l.unitName,
          },
      ],
    };
    final existing = await pendingCheckout(customerId);
    if (existing != null && jsonEncode(existing) != jsonEncode(request)) {
      throw StateError('Resolve the pending checkout first');
    }
    await _storage.write(key: storageKey, value: jsonEncode(request));
    Map<String, dynamic> result;
    try {
      result = Map<String, dynamic>.from(
        await client.rpc(
          'checkout_cart',
          params: {
            'target_customer': customerId,
            'items': lines.map((l) => l.toJson()).toList(),
            'accepted_quote': quote,
            'request_key': key,
          },
        ) as Map,
      );
    } on PostgrestException catch (error) {
      // Known SQL failures mean the transaction rolled back, unlike a timeout.
      if ({
        '22023',
        '22003',
        '22P02',
        '42501',
        '23514',
        '40001',
        '40P01',
      }.contains(error.code)) {
        await _storage.delete(key: storageKey);
        throw const CheckoutRejected();
      }
      rethrow;
    }
    if (result['outcome'] == 'changed' || result['outcome'] == 'created') {
      await _storage.delete(key: storageKey);
    }
    return result;
  }
}
