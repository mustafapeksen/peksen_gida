import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/presentation/auth_providers.dart';
import '../domain/product_repository.dart';
import 'product_providers.dart';

String newOperationKey() {
  final random = Random.secure();
  final bytes = List.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final s = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${s.substring(0, 8)}-${s.substring(8, 12)}-${s.substring(12, 16)}-${s.substring(16, 20)}-${s.substring(20)}';
}

class PricePage extends ConsumerStatefulWidget {
  const PricePage({super.key, required this.productId});
  final String productId;
  @override
  ConsumerState<PricePage> createState() => _PricePageState();
}

class _PricePageState extends ConsumerState<PricePage> {
  final _price = TextEditingController(), _reason = TextEditingController();
  bool _busy = false;
  String? _message, _payload, _key;
  @override
  void dispose() {
    _price.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _save(Product p) async {
    final amount = parseMoney(_price.text);
    if (amount == null || _reason.text.trim().isEmpty) {
      setState(
        () => _message = 'Geçerli TL tutarı ve değişiklik gerekçesi girin.',
      );
      return;
    }
    final payload = '${p.id}|${p.priceKurus}|$amount|${_reason.text.trim()}';
    if (_payload != payload) {
      _payload = payload;
      _key = newOperationKey();
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final repo = await ref.read(productRepositoryProvider.future);
      await repo.changePrice(
        productId: p.id,
        expectedPrice: p.priceKurus,
        newPrice: amount,
        reason: _reason.text.trim(),
        operationKey: _key!,
      );
      ref.invalidate(productsProvider);
      ref.invalidate(priceHistoryProvider(p.id));
      if (mounted) {
        setState(() {
          _message = 'Fiyat güncellendi.';
          _price.clear();
          _reason.clear();
          _payload = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _message = 'Fiyat değiştirilemedi. Yetki veya güncel fiyat değişmiş olabilir; yenileyin.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _activate(Product p) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await (await ref.read(productRepositoryProvider.future))
          .activate(p.id, p.priceKurus!);
      ref.invalidate(productsProvider);
      if (mounted) setState(() => _message = 'Ürün satışa açıldı.');
    } catch (_) {
      if (mounted) {
        setState(
          () => _message =
              'Satışa açılamadı. Güncel fiyatı ve erişiminizi kontrol edin.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(accountProfileProvider);
    final allowed = profile.asData?.value;
    return Scaffold(
      appBar: AppBar(title: const Text('Fiyat ve geçmiş')),
      body: SafeArea(
        child: profile.isLoading
            ? const Center(child: CircularProgressIndicator())
            : allowed == null || !canManagePrices(allowed.role)
            ? const Center(child: Text('Fiyat yönetimi yetkiniz yok.'))
            : ref
                  .watch(productsProvider)
                  .when(
                    skipLoadingOnRefresh: false,
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (_, _) => Center(
                      child: TextButton(
                        onPressed: () => ref.invalidate(productsProvider),
                        child: const Text('Ürünleri yeniden yükle'),
                      ),
                    ),
                    data: (products) {
                      final p = products
                          .where((p) => p.id == widget.productId)
                          .firstOrNull;
                      if (p == null) {
                        return const Center(child: Text('Ürün bulunamadı.'));
                      }
                      return ListView(
                        padding: const EdgeInsets.all(24),
                        children: [
                          Text(
                            p.name,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          Text(
                            p.priceKurus == null
                                ? 'Fiyat belirlenmedi'
                                : 'Güncel: ${formatKurus(p.priceKurus!)} / ${p.baseUnit}',
                          ),
                          TextField(
                            controller: _price,
                            enabled: !_busy,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Yeni liste fiyatı (TL)',
                            ),
                          ),
                          TextField(
                            controller: _reason,
                            enabled: !_busy,
                            decoration: const InputDecoration(
                              labelText: 'Değişiklik gerekçesi',
                            ),
                          ),
                          if (_message != null) Text(_message!),
                          FilledButton(
                            onPressed: _busy ? null : () => _save(p),
                            child: Text(
                              _busy ? 'Kaydediliyor…' : 'Fiyatı kaydet',
                            ),
                          ),
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () {
                                    ref.invalidate(productsProvider);
                                    ref.invalidate(priceHistoryProvider(p.id));
                                  },
                            child: const Text('Güncel fiyatı yenile'),
                          ),
                          if (!p.active && p.priceKurus != null)
                            FilledButton(
                              onPressed: _busy ? null : () => _activate(p),
                              child: const Text('Bu fiyatla satışa aç'),
                            ),
                          const SizedBox(height: 24),
                          TextButton(
                            onPressed: () =>
                                context.push('/account/products/${p.id}/quote'),
                            child: const Text('Müşteri fiyatı hesapla'),
                          ),
                          const Text('Fiyat geçmişi'),
                          ref
                              .watch(priceHistoryProvider(p.id))
                              .when(
                                loading: () => const LinearProgressIndicator(),
                                error: (_, _) => TextButton(
                                  onPressed: () => ref.invalidate(
                                    priceHistoryProvider(p.id),
                                  ),
                                  child: const Text(
                                    'Geçmiş yüklenemedi; yeniden dene',
                                  ),
                                ),
                                data: (events) => Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (events.isEmpty)
                                      const Text(
                                        'Henüz fiyat değişikliği yok.',
                                      ),
                                    for (final e in events)
                                      ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        title: Text(
                                          '${e['old_price'] == null ? 'Belirlenmedi' : formatKurus(e['old_price'] as String)} → ${formatKurus(e['new_price'] as String)}',
                                        ),
                                        subtitle: Text(
                                          '${e['actor']} · ${e['at']}\n${e['reason']}',
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                        ],
                      );
                    },
                  ),
      ),
    );
  }
}
