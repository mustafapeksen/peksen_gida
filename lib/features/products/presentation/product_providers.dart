import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/networking/supabase_bootstrap.dart';
import '../../auth/domain/account_repository.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/supabase_product_repository.dart';
import '../domain/product_repository.dart';

bool canReadProducts(AccountRole role) => const {
  AccountRole.warehouse,
  AccountRole.manager,
  AccountRole.owner,
}.contains(role);
bool canManagePrices(AccountRole role) =>
    role == AccountRole.manager || role == AccountRole.owner;

final pricingCustomersProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>(
      retry: (_, _) => null,
      (ref) async {
        final p = await ref.watch(accountProfileProvider.future);
        if (p == null || !canManagePrices(p.role)) {
          throw const AccountAccessException();
        }
        return (await ref.watch(productRepositoryProvider.future))
            .pricingCustomers();
      },
    );

final productRepositoryProvider = FutureProvider<ProductRepository>((
  ref,
) async {
  final client = await ref.watch(supabaseClientProvider.future);
  if (client == null) throw StateError('Backend unavailable');
  return SupabaseProductRepository(client);
});
final productCategoriesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>(
      retry: (_, _) => null,
      (ref) async {
        final account = await ref.watch(accountProfileProvider.future);
        if (account == null || !canReadProducts(account.role)) {
          throw const AccountAccessException();
        }
        return (await ref.watch(productRepositoryProvider.future)).categories();
      },
    );
final productsProvider = FutureProvider.autoDispose<List<Product>>(
  retry: (_, _) => null,
  (ref) async {
    final account = await ref.watch(accountProfileProvider.future);
    if (account == null || !canReadProducts(account.role)) {
      throw const AccountAccessException();
    }
    return (await ref.watch(productRepositoryProvider.future)).list();
  },
);

final priceHistoryProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>(retry: (_, _) => null, (
      ref,
      id,
    ) async {
      final profile = await ref.watch(accountProfileProvider.future);
      if (profile == null || !canManagePrices(profile.role)) {
        throw const AccountAccessException();
      }
      return (await ref.watch(productRepositoryProvider.future))
          .priceHistory(id);
    });
