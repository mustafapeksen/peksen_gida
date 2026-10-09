import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_providers.dart';
import '../domain/product_repository.dart';
import 'product_providers.dart';

class QuotePage extends ConsumerStatefulWidget {
  const QuotePage({super.key, required this.productId});
  final String productId;
  @override
  ConsumerState<QuotePage> createState() => _QuotePageState();
}

class _QuotePageState extends ConsumerState<QuotePage> {
  final _quantity = TextEditingController(text: '1');
  String? _customer, _unit, _error;
  Map<String, dynamic>? _quote;
  bool _busy = false;
  @override
  void dispose() {
    _quantity.dispose();
    super.dispose();
  }

  void _clear() {
    setState(() {
      _quote = null;
      _error = null;
    });
  }

  Future<void> _calculate() async {
    final quantity = int.tryParse(_quantity.text);
    if (_customer == null ||
        _unit == null ||
        quantity == null ||
        quantity <= 0 ||
        quantity > 2147483647) {
      setState(
        () =>
            _error = 'Müşteri, satış birimi ve pozitif tam sayı miktar seçin.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _quote = null;
      _error = null;
    });
    try {
      final result = await (await ref.read(productRepositoryProvider.future))
          .quote(_customer!, _unit!, quantity);
      if (mounted) setState(() => _quote = result);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Fiyat hesaplanamadı. Ürünün satış durumunu, minimum miktarı ve müşteri erişimini kontrol edin.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(accountProfileProvider);
    ref.listen(accountProfileProvider, (_, next) {
      if (next.isLoading ||
          next.hasError ||
          next.asData?.value?.id != account.asData?.value?.id) {
        _quote = null;
      }
    });
    return Scaffold(
      appBar: AppBar(title: const Text('Müşteri fiyatı hesapla')),
      body: SafeArea(
        child:
            account.asData?.value == null ||
                !canManagePrices(account.asData!.value!.role)
            ? const Center(
                child: Text('Fiyat hesaplama erişimi doğrulanamadı.'),
              )
            : ref
                  .watch(productsProvider)
                  .when(
                    skipLoadingOnRefresh: false,
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (_, _) =>
                        const Center(child: Text('Ürün yüklenemedi.')),
                    data: (products) {
                      final p = products
                          .where((p) => p.id == widget.productId)
                          .firstOrNull;
                      if (p == null) {
                        return const Center(child: Text('Ürün bulunamadı.'));
                      }
                      return ref
                          .watch(pricingCustomersProvider)
                          .when(
                            loading: () => const Center(
                              child: CircularProgressIndicator(),
                            ),
                            error: (_, _) => Center(
                              child: TextButton(
                                onPressed: () =>
                                    ref.invalidate(pricingCustomersProvider),
                                child: const Text('Müşterileri yeniden yükle'),
                              ),
                            ),
                            data: (customers) => ListView(
                              padding: const EdgeInsets.all(24),
                              children: [
                                Text(
                                  p.name,
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const Text(
                                  'Bu hesap sipariş oluşturmaz, stok ayırmaz ve fiyatı sabitlemez.',
                                ),
                                if (customers.isEmpty)
                                  const Text('Erişilebilir aktif müşteri yok.'),
                                DropdownButtonFormField<String>(
                                  isExpanded: true,
                                  initialValue: _customer,
                                  decoration: const InputDecoration(
                                    labelText: 'Müşteri',
                                  ),
                                  items: customers
                                      .map(
                                        (c) => DropdownMenuItem(
                                          value: c['id'] as String,
                                          child: Text(
                                            c['company_name'] as String,
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: _busy
                                      ? null
                                      : (v) {
                                          _customer = v;
                                          _clear();
                                        },
                                ),
                                DropdownButtonFormField<String>(
                                  isExpanded: true,
                                  initialValue: _unit,
                                  decoration: const InputDecoration(
                                    labelText: 'Satış birimi',
                                  ),
                                  items: p.units
                                      .where((u) => u.orderable)
                                      .map(
                                        (u) => DropdownMenuItem(
                                          value: u.id,
                                          child: Text(u.name),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: _busy
                                      ? null
                                      : (v) {
                                          _unit = v;
                                          _clear();
                                        },
                                ),
                                TextField(
                                  controller: _quantity,
                                  enabled: !_busy,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Satış miktarı',
                                  ),
                                  onChanged: (_) => _clear(),
                                ),
                                FilledButton(
                                  onPressed: _busy ? null : _calculate,
                                  child: Text(
                                    _busy ? 'Hesaplanıyor…' : 'Hesapla',
                                  ),
                                ),
                                if (_error != null) Text(_error!),
                                if (_quote != null) ...[
                                  Text(
                                    'Taban miktar: ${_quote!['base_quantity']} ${p.baseUnit}',
                                  ),
                                  Text(
                                    'İskonto: %${formatDiscountPercent(_quote!['discount_rate_snapshot'] as String)}',
                                  ),
                                  Text(
                                    'Kesin birim fiyatı: ${_quote!['exact_final_price_kurus_snapshot']} kuruş',
                                  ),
                                  Text(
                                    'Kalem toplamı: ${formatKurus(_quote!['line_total_kurus'] as String)}',
                                    key: const ValueKey('quote-total'),
                                  ),
                                ],
                              ],
                            ),
                          );
                    },
                  ),
      ),
    );
  }
}
