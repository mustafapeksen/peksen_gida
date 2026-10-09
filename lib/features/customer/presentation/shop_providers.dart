import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/networking/supabase_bootstrap.dart';
import '../../auth/domain/account_repository.dart';
import '../../auth/presentation/auth_providers.dart';
import '../domain/shop_repository.dart';
import '../data/supabase_shop_repository.dart';

final shopAudienceProvider = Provider<AccountRole>(
  (_) => AccountRole.customer,
  dependencies: [],
);
final shopPathProvider = Provider<String>(
  (_) => '/account/shop',
  dependencies: [],
);

final shopRepositoryProvider = FutureProvider<ShopRepository>((ref) async {
  final client = await ref.watch(supabaseClientProvider.future);
  if (client == null) throw StateError('Backend unavailable');
  return SupabaseShopRepository(client);
});
final shopCustomerProvider = FutureProvider.autoDispose<String>(
  dependencies: [],
  retry: (_, _) => null,
  (ref) async {
    final p = await ref.watch(accountProfileProvider.future);
    if (p == null || p.role != AccountRole.customer) {
      throw const AccountAccessException();
    }
    return (await ref.watch(shopRepositoryProvider.future)).customerId(p.id);
  },
);
final catalogProvider = FutureProvider.autoDispose<List<CatalogProduct>>(
  dependencies: [shopCustomerProvider],
  retry: (_, _) => null,
  (ref) async {
    final customer = await ref.watch(shopCustomerProvider.future);
    return (await ref.watch(shopRepositoryProvider.future)).catalog(customer);
  },
);

final cartProvider = NotifierProvider<CartController, List<CartLine>>(
  CartController.new,
  dependencies: [shopAudienceProvider],
);

class CartController extends Notifier<List<CartLine>> {
  @override
  List<CartLine> build() {
    // A cart is session memory, never shared across accounts or offline orders.
    ref.watch(authSessionProvider.select((s) => s.asData?.value.userId));
    ref.listen(accountProfileProvider, (_, next) {
      if (next.hasError ||
          (next.hasValue &&
              next.value?.role != ref.read(shopAudienceProvider))) {
        state = [];
      }
    });
    return [];
  }

  void setLine(CartLine line) {
    if (line.quantity <= 0 || line.quantity > 2147483647) {
      throw ArgumentError('Positive integer quantity required');
    }
    state = [...state.where((p) => p.unitId != line.unitId), line];
  }

  void remove(String unitId) =>
      state = state.where((p) => p.unitId != unitId).toList();
  void clear() => state = [];
}
