import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/presentation/auth_providers.dart';
import '../../products/domain/product_repository.dart'
    show formatDiscountPercent, formatKurus;
import '../domain/shop_repository.dart';
import 'shop_providers.dart';

class ShopGuard extends ConsumerWidget {
  const ShopGuard({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(accountProfileProvider)
      .when(
        skipLoadingOnRefresh: false,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) =>
            const Center(child: Text('Müşteri erişimi doğrulanamadı.')),
        data: (p) => p?.role == ref.watch(shopAudienceProvider)
            ? child
            : const Center(child: Text('Bu ekran müşteri hesabı gerektirir.')),
      );
}

class CatalogPage extends ConsumerStatefulWidget {
  const CatalogPage({super.key});
  @override
  ConsumerState<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends ConsumerState<CatalogPage> {
  String? _category;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Katalog'),
      actions: [
        IconButton(
          tooltip: 'Siparişlerim',
          onPressed: () => context.push('${ref.read(shopPathProvider)}/orders'),
          icon: const Icon(Icons.receipt_long),
        ),
        TextButton(
          onPressed: () => context.push('${ref.read(shopPathProvider)}/cart'),
          child: const Text('Sepet'),
        ),
      ],
    ),
    body: SafeArea(
      child: ShopGuard(
        child: ref
            .watch(catalogProvider)
            .when(
              skipLoadingOnRefresh: false,
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => Center(
                child: TextButton(
                  onPressed: () {
                    ref.invalidate(shopCustomerProvider);
                    ref.invalidate(catalogProvider);
                  },
                  child: const Text('Katalog yüklenemedi. Yeniden dene'),
                ),
              ),
              data: (products) {
                final categories = {
                  for (final p in products) p.categoryId: p.category,
                };
                final visible = products
                    .where(
                      (p) => _category == null || p.categoryId == _category,
                    )
                    .toList();
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(catalogProvider);
                    try {
                      await ref.read(catalogProvider.future);
                    } catch (_) {}
                  },
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                      Wrap(
                        spacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('Tümü'),
                            selected: _category == null,
                            onSelected: (_) => setState(() => _category = null),
                          ),
                          for (final c in categories.entries)
                            ChoiceChip(
                              label: Text(c.value),
                              selected: _category == c.key,
                              onSelected: (_) =>
                                  setState(() => _category = c.key),
                            ),
                        ],
                      ),
                      if (visible.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('Bu kategoride ürün yok.'),
                        ),
                      for (final p in visible)
                        Card(
                          child: ListTile(
                            title: Text(p.name),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (p.packageLabel != null)
                                  Text(p.packageLabel!),
                                Text(
                                  '${formatKurus(p.listPrice)} / ${p.baseUnit}',
                                  style: TextStyle(
                                    decoration:
                                        formatDiscountPercent(p.discount) != '0'
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                                Text(
                                  'Size özel %${formatDiscountPercent(p.discount)} · ${formatExactKurus(p.finalPrice)} / ${p.baseUnit}',
                                ),
                                Text(
                                  p.stockState == 'empty'
                                      ? 'Stok Yok'
                                      : p.stockState == 'unknown'
                                      ? 'Stok bilgisi henüz yok'
                                      : 'Stok mevcut',
                                ),
                              ],
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => context.push(
                              '${ref.read(shopPathProvider)}/product/${p.id}',
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
      ),
    ),
  );
}
