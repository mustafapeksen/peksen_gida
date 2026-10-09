import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/presentation/auth_providers.dart';
import '../domain/product_repository.dart';
import 'product_providers.dart';

class ProductsPage extends ConsumerWidget {
  const ProductsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(accountProfileProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Ürünler ve birimler')),
      body: SafeArea(
        child: account.when(
          skipLoadingOnRefresh: false,
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) =>
              const Center(child: Text('Hesap erişimi doğrulanamadı.')),
          data: (profile) {
            if (profile == null || !canReadProducts(profile.role)) {
              return const Center(
                child: Text('Bu ekrana erişim yetkiniz yok.'),
              );
            }
            return ref
                .watch(productsProvider)
                .when(
                  skipLoadingOnRefresh: false,
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, _) => Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Ürünler yüklenemedi.'),
                        TextButton(
                          onPressed: () => ref.invalidate(productsProvider),
                          child: const Text('Yeniden dene'),
                        ),
                      ],
                    ),
                  ),
                  data: (products) => RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(productsProvider);
                      try {
                        await ref.read(productsProvider.future);
                      } catch (_) {
                        // The provider's error branch presents the retry action.
                      }
                    },
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        FilledButton(
                          onPressed: () =>
                              context.push('/account/products/new'),
                          child: const Text('Ürün oluştur'),
                        ),
                        if (products.isEmpty) const Text('Henüz ürün yok.'),
                        for (final p in products)
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p.name,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge,
                                  ),
                                  Text(
                                    '${p.sku} · ${p.active ? 'Aktif' : 'Satışa kapalı'}',
                                  ),
                                  if (p.packageLabel != null)
                                    Text(p.packageLabel!),
                                  Text('Taban birim: ${p.baseUnit}'),
                                  if (p.category != null)
                                    Text('Kategori: ${p.category}'),
                                  if (p.minimum != null)
                                    Text('Minimum: ${p.minimum} ${p.baseUnit}'),
                                  for (final u in p.units)
                                    Text(
                                      '1 ${u.name} = ${u.conversion} ${p.baseUnit}${u.orderable ? '' : ' · Siparişe kapalı'}',
                                    ),
                                  if (canManagePrices(profile.role)) ...[
                                    Text(
                                      p.priceKurus == null
                                          ? 'Fiyat belirlenmedi'
                                          : 'Liste fiyatı: ${formatKurus(p.priceKurus!)} / ${p.baseUnit}',
                                    ),
                                    TextButton(
                                      onPressed: () => context.push(
                                        '/account/products/${p.id}/price',
                                      ),
                                      child: const Text('Fiyat ve geçmiş'),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
          },
        ),
      ),
    );
  }
}
