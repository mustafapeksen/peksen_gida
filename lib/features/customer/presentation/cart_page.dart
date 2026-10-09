import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../products/domain/product_repository.dart' show formatKurus;
import '../domain/shop_repository.dart';
import 'catalog_page.dart';
import 'shop_providers.dart';
import '../../products/presentation/price_page.dart' show newOperationKey;
import '../../auth/presentation/auth_providers.dart';

class CartPage extends ConsumerStatefulWidget {
  const CartPage({super.key});
  @override
  ConsumerState<CartPage> createState() => _CartPageState();
}

class _CartPageState extends ConsumerState<CartPage> {
  Map<String, dynamic>? _quote;
  String? _error;
  bool _busy = true;
  int _generation = 0;
  String? _requestKey, _notice;
  Map<String, dynamic>? _previousQuote;
  bool _uncertain = false;
  bool _recoveryFailed = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_recover);
  }

  Future<void> _recover() async {
    setState(() {
      _busy = true;
      _recoveryFailed = false;
    });
    try {
      final actor = (await ref.read(accountProfileProvider.future))?.id;
      final customer = await ref.read(shopCustomerProvider.future);
      final pending = await (await ref.read(shopRepositoryProvider.future))
          .pendingCheckout(customer);
      if (!mounted ||
          ref.read(accountProfileProvider).asData?.value?.id != actor) {
        return;
      }
      if (pending != null) {
        ref.read(cartProvider.notifier).clear();
        for (final l in pending['lines'] as List) {
          ref
              .read(cartProvider.notifier)
              .setLine(
                CartLine(
                  productName: l['product_name'] as String,
                  unitId: l['unit_id'] as String,
                  unitName: l['unit_name'] as String,
                  quantity: l['quantity'] as int,
                ),
              );
        }
        setState(() {
          _quote = Map<String, dynamic>.from(pending['quote'] as Map);
          _requestKey = pending['key'] as String;
          _uncertain = true;
          _notice = 'Önceki gönderimin sonucu bekleniyor. Aynı istekle güvenli biçimde tekrar deneyin.';
        });
      }
      setState(() => _busy = false);
    } catch (_) {
      if (mounted) {
        setState(() {
          _recoveryFailed = true;
          _error = 'Bekleyen gönderim kontrol edilemedi.';
        });
      }
    }
  }

  Future<void> _draft(bool load) async {
    final actor = ref.read(accountProfileProvider).asData?.value?.id;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final customer = await ref.read(shopCustomerProvider.future);
      final repo = await ref.read(shopRepositoryProvider.future);
      if (load) {
        final saved = await repo.loadDraft(customer);
        final products = await ref.read(catalogProvider.future);
        if (!mounted ||
            ref.read(accountProfileProvider).asData?.value?.id != actor) {
          return;
        }
        if (saved == null) {
          setState(() => _notice = 'Kaydedilmiş taslak yok.');
          return;
        }
        final restored = <CartLine>[];
        for (final item in saved) {
          final p = products
              .where((p) => p.units.any((u) => u.id == item['unit_id']))
              .firstOrNull;
          if (p == null) throw StateError('Draft product unavailable');
          final u = p.units.firstWhere((u) => u.id == item['unit_id']);
          restored.add(
            CartLine(
              productName: p.name,
              unitId: u.id,
              unitName: u.name,
              quantity: item['quantity'] as int,
            ),
          );
        }
        ref.read(cartProvider.notifier).clear();
        for (final line in restored) {
          ref.read(cartProvider.notifier).setLine(line);
        }
        setState(
          () => _notice =
              'Taslak yüklendi. Göndermeden önce güncel fiyatı kontrol edin.',
        );
      } else {
        await repo.saveDraft(customer, ref.read(cartProvider));
        if (mounted) {
          setState(
            () => _notice =
                'Taslak kaydedildi. Fiyat sabitlenmedi, stok ayrılmadı.',
          );
        }
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Taslak işlenemedi. Ürünler değişmiş olabilir; sepetiniz korunuyor.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    if (_quote == null) return;
    final generation = ++_generation;
    final lines = List<CartLine>.of(ref.read(cartProvider));
    _requestKey ??= newOperationKey();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final customer = await ref.read(shopCustomerProvider.future);
      final result = await (await ref.read(shopRepositoryProvider.future))
          .checkout(customer, lines, _quote!, _requestKey!);
      if (!mounted || generation != _generation) return;
      if (result['outcome'] == 'changed') {
        setState(() {
          _previousQuote = _quote;
          _quote = Map<String, dynamic>.from(result['quote'] as Map);
          _requestKey = null;
          _uncertain = false;
          _notice = 'Fiyat, birim veya stok değişti. Sipariş kaydedilmedi. Güncel kalemleri yeniden onaylayın.';
        });
      } else if (result['outcome'] == 'created') {
        ref.read(cartProvider.notifier).clear();
        setState(() {
          _uncertain = false;
          _notice =
              'Sipariş kaydedildi: ${result['order_id']}\n${result['status'] == 'submitted' ? 'Gönderildi; stok ayrıldı.' : 'Stok yetersiz; yönetici onayı bekleniyor, stok ayrılmadı.'}\nCari kontrol hesaplanmadı. Borç/tahsilat kaydı oluşturulmadı.';
        });
      } else {
        throw StateError('Unknown checkout result');
      }
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(() {
          _uncertain = error is! CheckoutRejected;
          if (!_uncertain) {
            _quote = null;
            _requestKey = null;
            _previousQuote = null;
            _error = 'Sipariş kaydedilmedi. Güncel ürün, minimum miktar ve erişiminizi kontrol edip yeniden fiyatlayın.';
            return;
          }
          _error = 'Gönderim sonucu doğrulanamadı. Aynı istekle tekrar deneyin; yeni sipariş oluşturmayın.';
        });
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  Future<void> _price() async {
    final lines = ref.read(cartProvider);
    final generation = ++_generation;
    setState(() {
      _busy = true;
      _error = null;
      _quote = null;
    });
    try {
      final customer = await ref.read(shopCustomerProvider.future);
      final quote = await (await ref.read(shopRepositoryProvider.future))
          .quote(customer, lines);
      if (mounted && generation == _generation) setState(() => _quote = quote);
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(
          () => _error = 'Sepet fiyatlanamadı. Minimum miktar, satıştaki ürünler ve bağlantıyı kontrol edin.',
        );
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  Future<void> _edit(CartLine line) async {
    final value = await showDialog<int>(
      context: context,
      builder: (_) => _QuantityDialog(line.quantity),
    );
    if (value != null && mounted) {
      ref.read(cartProvider.notifier).setLine(line.withQuantity(value));
    }
  }

  @override
  Widget build(BuildContext context) {
    final lines = ref.watch(cartProvider);
    ref.listen(cartProvider, (_, next) {
      _generation++;
      setState(() {
        _quote = null;
        _previousQuote = null;
        _requestKey = null;
        _uncertain = false;
        _notice = null;
        _error = null;
        _busy = false;
      });
    });
    return Scaffold(
      appBar: AppBar(title: const Text('Sepet')),
      body: SafeArea(
        child: ShopGuard(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_notice != null)
                Text(_notice!, key: const ValueKey('cart-notice')),
              if (_recoveryFailed)
                TextButton(
                  onPressed: _recover,
                  child: const Text('Bekleyen gönderimi yeniden yükle'),
                ),
              const Text(
                'Cari limit/exposure henüz hesaplanmıyor. Gönderim borç veya tahsilat oluşturmaz.',
              ),
              TextButton(
                onPressed: _busy || _uncertain ? null : () => _draft(true),
                child: const Text('Kayıtlı taslağı yükle'),
              ),
              if (lines.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Sepetiniz boş. Katalogdan ürün ekleyin.'),
                ),
              for (final line in lines)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          line.productName,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text('${line.quantity} ${line.unitName}'),
                        Wrap(
                          children: [
                            TextButton(
                              onPressed: _busy || _uncertain
                                  ? null
                                  : () => _edit(line),
                              child: const Text('Miktarı değiştir'),
                            ),
                            TextButton(
                              onPressed: _busy || _uncertain
                                  ? null
                                  : () => ref
                                        .read(cartProvider.notifier)
                                        .remove(line.unitId),
                              child: const Text('Çıkar'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              if (lines.isNotEmpty)
                TextButton(
                  onPressed: _busy || _uncertain ? null : () => _draft(false),
                  child: const Text('Taslağı kaydet'),
                ),
              if (lines.isNotEmpty)
                FilledButton(
                  onPressed: _busy || _uncertain ? null : _price,
                  child: Text(
                    _busy ? 'Kontrol ediliyor…' : 'Güncel fiyatı kontrol et',
                  ),
                ),
              if (_error != null) Text(_error!),
              if (_quote != null) ...[
                if (_previousQuote != null) ...[
                  Text(
                    'Önceki toplam: ${formatKurus(_previousQuote!['total_kurus'] as String)}',
                  ),
                  for (final old in _previousQuote!['lines'] as List)
                    Text(
                      'Önceki: ${old['name']} · dönüşüm ${old['conversion_to_base_snapshot']} · ${formatExactKurus(old['exact_final_price_kurus_snapshot'] as String)} / ${old['unit']}',
                    ),
                ],
                for (final q in _quote!['lines'] as List)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${q['name']} · ${q['quantity']} ${q['unit']}'),
                    subtitle: Text(
                      'Dönüşüm: ${q['conversion_to_base_snapshot']} · Birim: ${formatExactKurus(q['exact_final_price_kurus_snapshot'] as String)}\nKalem toplamı: ${formatKurus(q['line_total_kurus'] as String)}',
                    ),
                  ),
                Text(
                  'Toplam: ${formatKurus(_quote!['total_kurus'] as String)}',
                  key: const ValueKey('cart-total'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: Text(
                    _uncertain
                        ? 'Aynı gönderimi tekrar dene'
                        : _previousQuote != null
                        ? 'Güncel fiyatı onayla ve gönder'
                        : 'Fiyatı onayla ve gönder',
                  ),
                ),
                if (_quote!['stock_sufficient'] != true)
                  const Text(
                    'Stok yetersiz veya henüz tanımlanmamış. Sepet stok ayırmaz.',
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _QuantityDialog extends StatefulWidget {
  const _QuantityDialog(this.value);
  final int value;
  @override
  State<_QuantityDialog> createState() => _QuantityDialogState();
}

class _QuantityDialogState extends State<_QuantityDialog> {
  late final _controller = TextEditingController(text: widget.value.toString());
  String? _error;
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Miktar'),
    content: TextField(
      controller: _controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: 'Pozitif tam sayı',
        errorText: _error,
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Vazgeç'),
      ),
      FilledButton(
        onPressed: () {
          final n = int.tryParse(_controller.text);
          if (n == null || n <= 0 || n > 2147483647) {
            setState(() => _error = 'Geçerli miktar girin.');
            return;
          }
          Navigator.pop(context, n);
        },
        child: const Text('Uygula'),
      ),
    ],
  );
}
