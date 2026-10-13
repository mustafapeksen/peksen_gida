import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/notification_repository.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../products/presentation/product_providers.dart';

class NotificationCampaignPage extends ConsumerStatefulWidget {
  const NotificationCampaignPage({super.key});
  @override
  ConsumerState<NotificationCampaignPage> createState() => _CampaignState();
}

class _CampaignState extends ConsumerState<NotificationCampaignPage> {
  final _reason = TextEditingController();
  final _customers = <String>{};
  String? _product, _message;
  Map<String, dynamic>? _pending;
  bool _busy = false, _loaded = false;
  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    try {
      final repository = await ref.read(notificationRepositoryProvider.future);
      final pending = await repository.pendingCampaign();
      if (mounted) {
        setState(() {
          _pending = pending;
          _loaded = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _message = 'Önceki istek okunamadı. Ekranı yeniden açın.',
        );
      }
    }
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final request =
        _pending ??
        {
          'product': _product,
          'customers': (_customers.toList()..sort()),
          'reason': _reason.text.trim(),
          'request_key': notificationRequestId(),
        };
    setState(() {
      _busy = true;
      _pending = request;
      _message = null;
    });
    try {
      final repo = await ref.read(notificationRepositoryProvider.future);
      await repo.campaign(request);
      if (mounted) {
        setState(() {
          _pending = null;
          _message =
              'Bildirim isteği kaydedildi. Fiyat ve iskonto değiştirilmedi.';
          _customers.clear();
          _reason.clear();
        });
      }
    } catch (_) {
      final repo = await ref.read(notificationRepositoryProvider.future);
      final pending = await repo.pendingCampaign();
      if (mounted) {
        setState(() {
          _pending = pending;
          _message = 'İstek tamamlanamadı. Aktif ürün, müşteri ve erişimi kontrol edin. Belirsiz sonuçta aynı isteği tekrar deneyin.';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(accountProfileProvider).asData?.value?.role;
    if (role == null || !canManagePrices(role)) {
      return Scaffold(
        appBar: AppBar(title: const Text('Bildirim oluştur')),
        body: const Center(
          child: Text('Bu işlem yalnız Manager/Owner içindir.'),
        ),
      );
    }
    final products = ref.watch(productsProvider);
    final customers = ref.watch(pricingCustomersProvider);
    final locked = _busy || !_loaded || _pending != null;
    return Scaffold(
      appBar: AppBar(title: const Text('Büyük indirim bildirimi')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Mevcut ürün ve açıkça seçilen aktif müşteriler için duyuru oluşturur. Fiyat veya iskonto değişmez.',
            ),
            if (_pending != null)
              const Text(
                'Sonucu belirsiz bir istek var. Yeni duyurudan önce aynı isteği tekrar gönderin.',
              ),
            products.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, _) => const Text('Ürünler yüklenemedi.'),
              data: (rows) => DropdownButtonFormField<String>(
                initialValue: _product,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Ürün'),
                items: rows
                    .where((p) => p.active)
                    .map(
                      (p) => DropdownMenuItem(
                        value: p.id,
                        child: Text(p.name, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: locked
                    ? null
                    : (value) => setState(() => _product = value),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Bildirim alacak müşteriler'),
            customers.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, _) => const Text('Müşteriler yüklenemedi.'),
              data: (rows) => Column(
                children: [
                  for (final row in rows)
                    CheckboxListTile(
                      value: _customers.contains(row['id']),
                      title: Text(
                        '${row['name'] ?? row['company_name'] ?? row['id']}',
                      ),
                      onChanged: locked
                          ? null
                          : (value) => setState(() {
                              if (value == true) {
                                _customers.add(row['id'] as String);
                              } else {
                                _customers.remove(row['id']);
                              }
                            }),
                    ),
                ],
              ),
            ),
            TextField(
              controller: _reason,
              enabled: !locked,
              maxLength: 2000,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(labelText: 'Gerekçe'),
              onChanged: (_) => setState(() {}),
            ),
            if (_message != null) Text(_message!),
            FilledButton(
              onPressed:
                  _busy ||
                      !_loaded ||
                      (_pending == null &&
                          (_product == null ||
                              _customers.isEmpty ||
                              _reason.text.trim().isEmpty))
                  ? null
                  : _send,
              child: Text(
                _busy
                    ? 'Kaydediliyor…'
                    : _pending != null
                    ? 'Aynı isteği tekrar dene'
                    : 'Bildirimi oluştur',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
