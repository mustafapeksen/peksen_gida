import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/sales_repository.dart';

class SupabaseSalesRepository implements SalesRepository {
  const SupabaseSalesRepository(this.client);
  final SupabaseClient client;
  @override
  Future<List<SalesCustomer>> assignedCustomers() async =>
      (await client.rpc('sales_checkout_customers') as List)
          .map(
            (row) => SalesCustomer(
              row['id'] as String,
              row['company_name'] as String,
            ),
          )
          .toList();
}
