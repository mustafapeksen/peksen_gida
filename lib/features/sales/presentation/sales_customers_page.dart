import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/networking/supabase_bootstrap.dart';
import '../../auth/domain/account_repository.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../customer/presentation/shop_providers.dart';
import '../domain/sales_repository.dart';
import '../data/supabase_sales_repository.dart';

final salesRepositoryProvider = FutureProvider<SalesRepository>((ref) async {
  final client = await ref.watch(supabaseClientProvider.future);
  if (client == null) throw const AccountAccessException();
  return SupabaseSalesRepository(client);
});

final salesCustomersProvider = FutureProvider.autoDispose<List<SalesCustomer>>(
  retry: (_, _) => null,
  (ref) async {
    final profile = await ref.watch(accountProfileProvider.future);
    if (profile?.role != AccountRole.salesOperator) {
      throw const AccountAccessException();
    }
    return (await ref.watch(salesRepositoryProvider.future))
        .assignedCustomers();
  },
);

class SalesCustomersPage extends ConsumerWidget {
  const SalesCustomersPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Atanmış müşteriler')),
    body: SafeArea(
      child: ref
          .watch(salesCustomersProvider)
          .when(
            skipLoadingOnRefresh: false,
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => Center(
              child: TextButton(
                onPressed: () => ref.invalidate(salesCustomersProvider),
                child: const Text(
                  'Müşteri erişimi doğrulanamadı. Yeniden dene',
                ),
              ),
            ),
            data: (customers) => ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Yalnız size atanmış aktif müşteriler. Müşteri adına verilen siparişte işlemi yapan kişi siz olarak kaydedilirsiniz.',
                ),
                TextButton(
                  onPressed: () => ref.invalidate(salesCustomersProvider),
                  child: const Text('Listeyi yenile'),
                ),
                if (customers.isEmpty)
                  const Text('Size atanmış aktif müşteri yok.'),
                for (final c in customers)
                  Card(
                    child: ListTile(
                      title: Text(c.companyName),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/account/sales/${c.id}'),
                    ),
                  ),
              ],
            ),
          ),
    ),
  );
}

// A distinct scope per actor/customer also owns its cart, quotes and providers.
// Leaving the customer disposes memory state; saved drafts and uncertain sends
// remain actor/customer scoped in the existing Phase 6 repository.
class SalesShopScope extends ConsumerWidget {
  const SalesShopScope({
    super.key,
    required this.customerId,
    required this.child,
  });
  final String customerId;
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(accountProfileProvider);
    final customers = ref.watch(salesCustomersProvider);
    Widget denied(String text) => Scaffold(
      appBar: AppBar(title: const Text('Müşteri seçimi')),
      body: Center(child: Text(text)),
    );
    if (profile.asData?.value?.role != AccountRole.salesOperator) {
      return denied('Bu ekran satış operasyonu hesabı gerektirir.');
    }
    return customers.when(
      skipLoadingOnRefresh: false,
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, _) => denied(
        'Müşteri erişimi doğrulanamadı. Listeye dönüp yeniden deneyin.',
      ),
      data: (list) {
        final selected = list.where((c) => c.id == customerId).firstOrNull;
        if (selected == null) {
          return denied('Bu müşteri aktif atamalarınızda değil.');
        }
        return ProviderScope(
          key: ValueKey('${profile.asData!.value!.id}:$customerId'),
          overrides: [
            shopAudienceProvider.overrideWithValue(AccountRole.salesOperator),
            shopPathProvider.overrideWithValue('/account/sales/$customerId'),
            shopCustomerProvider.overrideWith((_) async => customerId),
            cartProvider.overrideWith(CartController.new),
          ],
          child: Column(
            children: [
              Material(
                color: Theme.of(context).colorScheme.secondaryContainer,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Müşteri adına: ${selected.companyName}\nKaydedilmeyen sepet, müşteriden çıkınca temizlenir.',
                          ),
                        ),
                        IconButton(
                          tooltip: 'Atamayı yenile',
                          onPressed: () =>
                              ref.invalidate(salesCustomersProvider),
                          icon: const Icon(Icons.refresh),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(child: child),
            ],
          ),
        );
      },
    );
  }
}
