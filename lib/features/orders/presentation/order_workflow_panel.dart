import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/presentation/auth_providers.dart';
import '../../customer/presentation/orders_page.dart';
import '../../customer/presentation/shop_providers.dart';
import '../../products/presentation/price_page.dart' show newOperationKey;
import '../data/order_workflow_repository.dart';

class OrderWorkflowPanel extends ConsumerStatefulWidget {
  const OrderWorkflowPanel({
    super.key,
    required this.orderId,
    required this.onChanged,
  });
  final String orderId;
  final VoidCallback onChanged;

  @override
  ConsumerState<OrderWorkflowPanel> createState() => _OrderWorkflowPanelState();
}

class _OrderWorkflowPanelState extends ConsumerState<OrderWorkflowPanel> {
  late Future<Map<String, dynamic>> _state;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _state = ref
        .read(orderWorkflowRepositoryProvider.future)
        .then((repo) => repo.state(widget.orderId));
  }

  Future<void> _act(String action, String title) async {
    final actor = ref.read(accountProfileProvider).asData?.value?.id;
    if (actor == null) return;
    final completed = await showDialog<bool>(
      context: context,
      builder: (_) => _ActionDialog(
        title: title,
        action: action,
        send: (reason, key) async {
          final repo = await ref.read(orderWorkflowRepositoryProvider.future);
          if (!mounted ||
              ref.read(accountProfileProvider).asData?.value?.id != actor) {
            throw StateError('Session changed');
          }
          await repo.act(widget.orderId, action, reason, key);
        },
      ),
    );
    if (!mounted ||
        ref.read(accountProfileProvider).asData?.value?.id != actor) {
      return;
    }
    // Even an uncertain result may have committed; refresh from the server.
    setState(_load);
    if (completed == true) widget.onChanged();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
    future: _state,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(),
        );
      }
      if (snapshot.hasError) {
        return TextButton(
          onPressed: () => setState(_load),
          child: const Text('Sipariş işlemlerini yeniden yükle'),
        );
      }
      final data = snapshot.data!;
      final status = data['status'] as String;
      final canRequest = {
        'submitted',
        'picking',
        'picked',
        'assigned',
        'loaded',
        'out_for_delivery',
      }.contains(status);
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Güncel durum: ${orderStatusLabel(status)}'),
            TextButton(
              onPressed: () => context.push(
                '${ref.read(shopPathProvider)}/orders/${widget.orderId}/alternatives',
              ),
              child: const Text('Alternatif teklifleri'),
            ),
            if (status == 'submitted')
              OutlinedButton(
                onPressed: () => _act('cancel_submitted', 'Siparişi iptal et'),
                child: const Text('Siparişi iptal et'),
              ),
            if (canRequest) ...[
              TextButton(
                onPressed: () => _act('request_change', 'Değişiklik talebi'),
                child: const Text('Değişiklik talebi oluştur'),
              ),
              if (status != 'submitted')
                TextButton(
                  onPressed: () => _act('request_cancel', 'İptal talebi'),
                  child: const Text('İptal talebi oluştur'),
                ),
              const Text(
                'Talep siparişi değiştirmez. Karar yetkisi yönetici veya işletme sahibindedir. Karar, kalem ve stok değişikliğini otomatik uygulamaz.',
              ),
            ],
            const SizedBox(height: 12),
            const Text('Talepler'),
            if ((data['requests'] as List).isEmpty)
              const Text('Henüz talep yok.'),
            for (final r in data['requests'] as List)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  '${r['type'] == 'cancel' ? 'İptal' : 'Değişiklik'} · ${switch (r['status']) {
                    'approved' => 'Onaylandı',
                    'rejected' => 'Reddedildi',
                    _ => 'Bekliyor',
                  }}',
                ),
                subtitle: Text(
                  '${r['reason']}${r['decision_note'] == null ? '' : '\nKarar notu: ${r['decision_note']}'}',
                ),
              ),
            const Text('Durum geçmişi'),
            for (final h in data['history'] as List)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  h['event_type'] == 'request_decided'
                      ? 'Talep ${h['request_decision'] == 'approved' ? 'onaylandı' : 'reddedildi'} — siparişe uygulanmadı'
                      : orderStatusLabel(h['to_status'] as String),
                ),
                subtitle: Text('${h['created_at']}\n${h['reason'] ?? ''}'),
              ),
          ],
        ),
      );
    },
  );
}

class _ActionDialog extends StatefulWidget {
  const _ActionDialog({
    required this.title,
    required this.action,
    required this.send,
  });
  final String title, action;
  final Future<void> Function(String reason, String key) send;
  @override
  State<_ActionDialog> createState() => _ActionDialogState();
}

class _ActionDialogState extends State<_ActionDialog> {
  final _reason = TextEditingController();
  final _key = newOperationKey();
  bool _busy = false, _sent = false;
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_reason.text.trim().isEmpty) {
      setState(() => _error = 'Gerekçe yazın.');
      return;
    }
    setState(() {
      _busy = true;
      _sent = true;
      _error = null;
    });
    try {
      await widget.send(_reason.text.trim(), _key);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'İşlem doğrulanamadı. Aynı istekle yeniden deneyin veya kapatıp güncel durumu kontrol edin.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: Text(widget.title),
      scrollable: true,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.action == 'cancel_submitted'
                ? 'Sipariş iptal edilir ve ayrılan stok serbest bırakılır. Kayıtlar silinmez.'
                : 'Talep kaydedilir; sipariş, fiyat ve stok aynı kalır.',
          ),
          TextField(
            controller: _reason,
            readOnly: _sent,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Gerekçe'),
          ),
          if (_error != null) Text(_error!),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: Text(
            _busy
                ? 'İşleniyor…'
                : _sent
                ? 'Aynı isteği yeniden dene'
                : 'Onayla',
          ),
        ),
      ],
    ),
  );
}
