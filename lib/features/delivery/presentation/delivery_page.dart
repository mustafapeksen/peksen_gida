import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/domain/account_repository.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../products/presentation/price_page.dart' show newOperationKey;
import '../data/delivery_repository.dart';

bool canUseDelivery(AccountRole role) => const {
  AccountRole.customer,
  AccountRole.driver,
  AccountRole.manager,
  AccountRole.owner,
}.contains(role);

final deliveryDataProvider = FutureProvider.autoDispose<Map<String, dynamic>>(
  retry: (_, _) => null,
  (ref) async {
    final account = await ref.watch(accountProfileProvider.future);
    if (account == null || !canUseDelivery(account.role)) {
      throw const AccountAccessException();
    }
    return (await ref.watch(deliveryRepositoryProvider.future)).read();
  },
);
final deliveryPendingProvider =
    FutureProvider.autoDispose<Map<String, dynamic>?>(retry: (_, _) => null, (
      ref,
    ) async {
      final account = await ref.watch(accountProfileProvider.future);
      if (account == null || !canUseDelivery(account.role)) {
        throw const AccountAccessException();
      }
      return (await ref.watch(deliveryRepositoryProvider.future)).pending();
    });

class DeliveryPage extends ConsumerStatefulWidget {
  const DeliveryPage({super.key});
  @override
  ConsumerState<DeliveryPage> createState() => _DeliveryPageState();
}

class _DeliveryPageState extends ConsumerState<DeliveryPage> {
  bool busy = false;
  String? message;
  void refresh() {
    ref.invalidate(deliveryDataProvider);
    ref.invalidate(deliveryPendingProvider);
  }

  Future<void> send(String action, Map<String, dynamic> params) async {
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await (await ref.read(deliveryRepositoryProvider.future))
          .perform(action, params);
      message = action == 'evidence'
          ? 'Yükleme hazırlığı alındı. Dosyanız gönderilmediyse yeniden seçin.'
          : 'İşlem kaydedildi.';
    } on DeliveryRejected {
      message =
          'İşlem reddedildi. Yetki ve güncel teslimat durumunu kontrol edin.';
    } catch (_) {
      message =
          'Sonuç alınamadı. Yeni işlem açmadan aynı isteği yeniden deneyin.';
    } finally {
      if (mounted) {
        setState(() => busy = false);
        refresh();
      }
    }
  }

  Future<void> confirm(String action, String orderId, String title) async {
    final reason = TextEditingController();
    final comment = TextEditingController();
    final form = GlobalKey<FormState>();
    var score = 5;
    final reasons = <String>{};
    final needsReason = action == 'dispute' || action == 'resolve';
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    action == 'driver_confirm'
                        ? 'Bu işlem müşteri onayını beklemeye alır; teslimatı tek başına kesinleştirmez.'
                        : action == 'resolve'
                        ? 'Teslimat yönetici kararıyla kesinleşir ve durak kapanır.'
                        : action == 'rate'
                        ? 'Teslimatı başlatan sürücüyü bir kez puanlayabilirsiniz. Puan değiştirilemez.'
                        : 'Yalnız bu sipariş için onay veriyorsunuz.',
                  ),
                  if (needsReason)
                    TextFormField(
                      controller: reason,
                      maxLength: 2000,
                      decoration: const InputDecoration(labelText: 'Gerekçe'),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Gerekçe gerekli.'
                          : null,
                    ),
                  if (action == 'rate') ...[
                    DropdownButtonFormField<int>(
                      initialValue: score,
                      decoration: const InputDecoration(labelText: 'Puan'),
                      items: [
                        for (var i = 1; i <= 5; i++)
                          DropdownMenuItem(value: i, child: Text('$i yıldız')),
                      ],
                      onChanged: (value) => update(() => score = value!),
                    ),
                    for (final entry in const {
                      'late': 'Geç geldi',
                      'behavior': 'Davranış',
                      'missing_product': 'Ürün eksikliği',
                      'damage': 'Hasar',
                      'other': 'Diğer',
                    }.entries)
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(entry.value),
                        value: reasons.contains(entry.key),
                        onChanged: (value) => update(() {
                          if (value == true) {
                            reasons.add(entry.key);
                          } else {
                            reasons.remove(entry.key);
                          }
                        }),
                      ),
                    TextField(
                      controller: comment,
                      maxLength: 2000,
                      decoration: const InputDecoration(
                        labelText: 'Yorum (isteğe bağlı)',
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () {
                if (form.currentState!.validate()) Navigator.pop(context, true);
              },
              child: const Text('Onayla'),
            ),
          ],
        ),
      ),
    );
    final data = <String, dynamic>{
      'order_id': orderId,
      if (needsReason) 'reason': reason.text.trim(),
      if (action == 'rate') ...{
        'score': score,
        'reasons': reasons.toList(),
        'comment': comment.text.trim(),
      },
    };
    // The route transition may still use the controllers during its last frame.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    reason.dispose();
    comment.dispose();
    if (accepted == true && mounted) {
      await send(action, {'data': data, 'request_key': newOperationKey()});
    }
  }

  Future<void> upload(String orderId) async {
    setState(() {
      busy = true;
      message = null;
    });
    try {
      final file = await openFile(
        acceptedTypeGroups: const [
          XTypeGroup(
            label: 'JPEG/PNG',
            extensions: ['jpg', 'jpeg', 'png'],
            mimeTypes: ['image/jpeg', 'image/png'],
          ),
        ],
      );
      if (file == null) return;
      if (await file.length() > 5242880) throw const DeliveryRejected();
      final bytes = await file.readAsBytes();
      final mime = evidenceMime(bytes);
      if (mime == null) throw const DeliveryRejected();
      final repo = await ref.read(deliveryRepositoryProvider.future);
      final result = await repo.perform('evidence', {
        'data': {'order_id': orderId, 'mime_type': mime},
        'request_key': newOperationKey(),
      });
      await repo.upload(result['object_name'] as String, bytes, mime);
      message = 'Kanıt yüklendi. Yalnız siz ve Manager/Owner okuyabilir.';
    } on DeliveryRejected {
      message = 'Kanıt yüklenemedi. Uyuşmazlık, atama ve JPEG/PNG 5 MB sınırını kontrol edin.';
    } catch (_) {
      message = 'Yükleme sonucu alınamadı. Listeyi yenileyin; bekleyen isteği çözmeden yeniden yüklemeyin.';
    } finally {
      if (mounted) {
        setState(() => busy = false);
        refresh();
      }
    }
  }

  Future<void> viewEvidence(String path) async {
    setState(() => busy = true);
    try {
      final bytes = await (await ref.read(deliveryRepositoryProvider.future))
          .download(path);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Uyuşmazlık kanıtı'),
          content: Image.memory(
            bytes,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const Text('Görsel açılamadı.'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Kapat'),
            ),
          ],
        ),
      );
    } catch (_) {
      message = 'Kanıt okunamadı veya erişim sona erdi.';
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(accountProfileProvider).asData?.value?.role;
    final data = ref.watch(deliveryDataProvider);
    final pending = ref.watch(deliveryPendingProvider);
    final ready = !busy && pending.hasValue && pending.value == null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Teslimat ve puanlama'),
        actions: [
          IconButton(
            onPressed: busy ? null : refresh,
            tooltip: 'Yenile',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (message != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(message!),
              ),
            if (busy) const LinearProgressIndicator(),
            if (pending.hasError)
              const Text('Bekleyen işlem kontrol edilemedi. Yenileyin.'),
            if (pending.asData?.value case final saved?) ...[
              const Text(
                'Önceki işlemin sonucu belirsiz. Aynı isteği yeniden gönderin.',
              ),
              FilledButton(
                onPressed: busy
                    ? null
                    : () => send(
                        saved['action'] as String,
                        Map<String, dynamic>.from(saved['params'] as Map),
                      ),
                child: const Text('Aynı isteği yeniden dene'),
              ),
            ],
            data.when(
              skipLoadingOnRefresh: false,
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => const Text(
                'Teslimatlar okunamadı. Bağlantınızı ve yetkinizi kontrol edip yenileyin.',
              ),
              data: (value) {
                final orders = (value['orders'] as List? ?? []).cast<Map>();
                if (orders.isEmpty) {
                  return const Text('Bu kapsamda teslimatınız yok.');
                }
                return Column(
                  children: [
                    for (final order in orders)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (order['dispute_reason'] != null)
                                Text('Uyuşmazlık gerekçesi: ${order['dispute_reason']}'),
                              Text(
                                'Sipariş ${order['number']}',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(
                                const {
                                      'out_for_delivery': 'Dağıtımda',
                                      'delivery_pending_confirmation':
                                          'Müşteri onayı bekliyor',
                                      'delivery_disputed':
                                          'Teslimat uyuşmazlığı',
                                      'delivered': 'Teslim edildi',
                                    }[order['status']] ??
                                    'Durum',
                              ),
                              if (role == AccountRole.driver &&
                                  order['status'] == 'out_for_delivery')
                                FilledButton(
                                  onPressed: ready
                                      ? () => confirm(
                                          'driver_confirm',
                                          order['id'] as String,
                                          'Teslimatı bildir',
                                        )
                                      : null,
                                  child: const Text('Teslimatı bildir'),
                                ),
                              if (role == AccountRole.customer &&
                                  order['status'] ==
                                      'delivery_pending_confirmation') ...[
                                FilledButton(
                                  onPressed: ready
                                      ? () => confirm(
                                          'customer_confirm',
                                          order['id'] as String,
                                          'Teslim aldım',
                                        )
                                      : null,
                                  child: const Text('Teslim aldım'),
                                ),
                                OutlinedButton(
                                  onPressed: ready
                                      ? () => confirm(
                                          'dispute',
                                          order['id'] as String,
                                          'Teslim almadım',
                                        )
                                      : null,
                                  child: const Text('Teslim almadım'),
                                ),
                              ],
                              if ((role == AccountRole.manager ||
                                      role == AccountRole.owner) &&
                                  const [
                                    'delivery_pending_confirmation',
                                    'delivery_disputed',
                                  ].contains(order['status']))
                                FilledButton(
                                  onPressed: ready
                                      ? () => confirm(
                                          'resolve',
                                          order['id'] as String,
                                          'Teslimatı kesinleştir',
                                        )
                                      : null,
                                  child: const Text(
                                    'Gerekçeli teslimat çözümü',
                                  ),
                                ),
                              if (role == AccountRole.driver &&
                                  order['status'] == 'delivery_disputed')
                                OutlinedButton(
                                  onPressed: ready
                                      ? () => upload(order['id'] as String)
                                      : null,
                                  child: const Text(
                                    'Kanıt ekle (JPEG/PNG, en çok 5 MB)',
                                  ),
                                ),
                              for (final evidence
                                  in (order['evidence'] as List? ?? []))
                                OutlinedButton(
                                  onPressed: busy
                                      ? null
                                      : () => viewEvidence(
                                          evidence['object_name'] as String,
                                        ),
                                  child: const Text('Kanıtı görüntüle'),
                                ),
                              if (role == AccountRole.customer &&
                                  order['can_rate'] == true)
                                FilledButton(
                                  onPressed: ready
                                      ? () => confirm(
                                          'rate',
                                          order['id'] as String,
                                          'Sürücüyü puanla',
                                        )
                                      : null,
                                  child: const Text('Sürücüyü puanla'),
                                ),
                              if (order['score'] != null)
                                Text('Puan: ${order['score']}/5'),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
