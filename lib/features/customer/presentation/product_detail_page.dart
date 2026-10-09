import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/presentation/auth_providers.dart';
import '../domain/shop_repository.dart';
import 'catalog_page.dart';
import 'shop_providers.dart';

class ProductDetailPage extends ConsumerStatefulWidget {
  const ProductDetailPage({super.key, required this.productId});
  final String productId;
  @override
  ConsumerState<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends ConsumerState<ProductDetailPage> {
  final _quantity = TextEditingController(text: '1');
  String? _unit, _error;
  bool _busy = false;
  @override
  void dispose() {
    _quantity.dispose();
    super.dispose();
  }

  Future<void> _add(CatalogProduct p) async {
    final quantity = int.tryParse(_quantity.text);
    if (_unit == null ||
        quantity == null ||
        quantity <= 0 ||
        quantity > 2147483647) {
      setState(() => _error = 'Satış birimi ve pozitif tam sayı miktar girin.');
      return;
    }
    final u = p.units.where((u) => u.id == _unit).firstOrNull;
    if (u == null) {
      setState(() => _error = 'Satış birimi değişti. Ürünü yeniden yükleyin.');
      return;
    }
    final actor = ref.read(accountProfileProvider).asData?.value?.id;
    final line = CartLine(
      productName: p.name,
      unitId: u.id,
      unitName: u.name,
      quantity: quantity,
    );
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final customer = await ref.read(shopCustomerProvider.future);
      await (await ref.read(shopRepositoryProvider.future))
          .quote(customer, [line]);
      if (!mounted ||
          ref.read(accountProfileProvider).asData?.value?.id != actor) {
        return;
      }
      ref.read(cartProvider.notifier).setLine(line);
      context.push('${ref.read(shopPathProvider)}/cart');
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Eklenemedi. Minimum taban miktarı, güncel ürün ve bağlantıyı kontrol edin.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Ürün detayı')),
    body: SafeArea(
      child: ShopGuard(
        child: ref
            .watch(catalogProvider)
            .when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => Center(
                child: TextButton(
                  onPressed: () => ref.invalidate(catalogProvider),
                  child: const Text('Ürünü yeniden yükle'),
                ),
              ),
              data: (products) {
                final p = products
                    .where((p) => p.id == widget.productId)
                    .firstOrNull;
                if (p == null) {
                  return const Center(child: Text('Ürün artık satışta değil.'));
                }
                return ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    Text(
                      p.name,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    if (p.description != null) Text(p.description!),
                    if (p.packageLabel != null) Text(p.packageLabel!),
                    Text('Minimum: ${p.minimum} ${p.baseUnit}'),
                    if (p.stockState != 'available')
                      const Text(
                        'Stok yeterliliği henüz sağlanmıyor. Sepet stok rezervasyonu yapmaz.',
                      ),
                    DropdownButtonFormField<String>(
                      key: ValueKey(p.units.map((u) => u.id).join(',')),
                      initialValue: p.units.any((u) => u.id == _unit)
                          ? _unit
                          : null,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Satış birimi',
                      ),
                      items: p.units
                          .map(
                            (u) => DropdownMenuItem(
                              value: u.id,
                              child: Text(
                                '${u.name} (${u.conversion} ${p.baseUnit})',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: _busy
                          ? null
                          : (v) => setState(() => _unit = v),
                    ),
                    TextField(
                      controller: _quantity,
                      enabled: !_busy,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Miktar'),
                    ),
                    const Text(
                      'Aynı satış birimi sepette varsa miktarı bu değerle değiştirilir.',
                    ),
                    if (_error != null) Text(_error!),
                    FilledButton(
                      onPressed: _busy || p.units.isEmpty
                          ? null
                          : () => _add(p),
                      child: Text(_busy ? 'Kontrol ediliyor…' : 'Sepete ekle'),
                    ),
                  ],
                );
              },
            ),
      ),
    ),
  );
}
