import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/product_repository.dart';

class SupabaseProductRepository implements ProductRepository {
  SupabaseProductRepository(this.client);
  final SupabaseClient client;
  @override
  Future<List<Map<String, dynamic>>> pricingCustomers() => client
      .from('customers')
      .select('id,company_name')
      .eq('active', true)
      .order('company_name');
  @override
  Future<Map<String, dynamic>> quote(
    String customerId,
    String unitId,
    int quantity,
  ) async => Map<String, dynamic>.from(
    await client.rpc(
      'quote_product',
      params: {
        'target_customer': customerId,
        'target_unit': unitId,
        'sale_quantity': quantity,
      },
    ) as Map,
  );
  @override
  Future<List<Map<String, dynamic>>> categories() async =>
      (await client.rpc('product_categories') as List)
          .map((r) => Map<String, dynamic>.from(r as Map))
          .toList();
  @override
  Future<void> createDraft({
    required String id,
    required String sku,
    required String name,
    required String categoryId,
    required String baseUnit,
    required int minimum,
    required String packageLabel,
    required List<Map<String, String>> units,
  }) async {
    await client.rpc(
      'create_product_draft',
      params: {
        'product_id': id,
        'product_sku': sku,
        'product_name': name,
        'category': categoryId,
        'base_unit_name': baseUnit,
        'minimum_quantity': minimum,
        'package_text': packageLabel,
        'sales_units': units,
      },
    );
  }

  @override
  Future<void> activate(String productId, String expectedPrice) async {
    await client.rpc(
      'activate_product',
      params: {'target_product': productId, 'expected_price': expectedPrice},
    );
  }

  @override
  Future<List<Product>> list() async {
    final rows = await client.rpc('product_reference_list');
    return (rows as List)
        .map((r) => Product.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  @override
  Future<List<Map<String, dynamic>>> priceHistory(String productId) async {
    final rows = await client.rpc(
      'product_price_events',
      params: {'target_product': productId},
    );
    return (rows as List)
        .map((r) => Map<String, dynamic>.from(r as Map))
        .toList();
  }

  @override
  Future<void> changePrice({
    required String productId,
    required String? expectedPrice,
    required String newPrice,
    required String reason,
    required String operationKey,
  }) async {
    await client.rpc(
      'change_product_price',
      params: {
        'target_product': productId,
        'expected_price': expectedPrice,
        'new_price': newPrice,
        'change_reason': reason,
        'request_key': operationKey,
      },
    );
  }
}
