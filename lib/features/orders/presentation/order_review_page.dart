import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/domain/account_repository.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../customer/presentation/orders_page.dart' show orderStatusLabel;
import '../data/order_review_repository.dart';
import 'review_action_dialog.dart';

final orderReviewRequestsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>(
      retry: (_, _) => null,
      (ref) async {
        final p = await ref.watch(accountProfileProvider.future);
        if (p?.role != AccountRole.manager && p?.role != AccountRole.owner) {
          throw const AccountAccessException();
        }
        return (await ref.watch(orderReviewRepositoryProvider.future))
            .requests();
      },
    );

class OrderReviewPage extends ConsumerWidget {
  const OrderReviewPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(accountProfileProvider).asData?.value;
    final permitted =
        profile?.role == AccountRole.manager ||
        profile?.role == AccountRole.owner;
    return Scaffold(
      appBar: AppBar(title: const Text('Sipariş talepleri')),
      body: SafeArea(
        child: !permitted
            ? const Center(
                child: Text(
                  'Bu ekran yönetici veya işletme sahibi hesabı gerektirir.',
                ),
              )
            : ref
                  .watch(orderReviewRequestsProvider)
                  .when(
                    skipLoadingOnRefresh: false,
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (_, _) => Center(
                      child: TextButton(
                        onPressed: () =>
                            ref.invalidate(orderReviewRequestsProvider),
                        child: const Text('Talepleri yeniden yükle'),
                      ),
                    ),
                    data: (requests) => ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        const Text(
                          'Karar yalnız talebi sonuçlandırır. Sipariş kalemi, fiyat ve stok uygulaması yapılmaz. Yalnız gönderilmiş siparişlerde bekleyen talepler karara bağlanabilir.',
                        ),
                        TextButton(
                          onPressed: () =>
                              ref.invalidate(orderReviewRequestsProvider),
                          child: const Text('Talepleri yenile'),
                        ),
                        if (requests.isEmpty)
                          const Text('Henüz sipariş talebi yok.'),
                        for (final r in requests)
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    '${r['customer']} · ${r['type'] == 'cancel' ? 'İptal' : 'Değişiklik'}',
                                  ),
                                  Text(
                                    'Sipariş: ${r['order_id']} · ${orderStatusLabel(r['order_status'] as String)}',
                                  ),
                                  Text(r['reason'] as String),
                                  if (r['alternative'] != null)
                                    Text(
                                      'Alternatif niyeti: ${r['alternative']['name']} · ${r['alternative']['quantity']} ${r['alternative']['unit']}',
                                    ),
                                  Text(switch (r['status']) {
                                    'approved' =>
                                      'Talep onaylandı; siparişe uygulanmadı',
                                    'rejected' => 'Talep reddedildi',
                                    _ => 'Karar bekliyor',
                                  }),
                                  if (r['decision_note'] != null)
                                    Text('Karar notu: ${r['decision_note']}'),
                                  if (r['status'] == 'pending' &&
                                      r['order_status'] == 'submitted')
                                    Wrap(
                                      spacing: 8,
                                      children: [
                                        for (final approve in [true, false])
                                          TextButton(
                                            onPressed: () async {
                                              await showDialog<bool>(
                                                context: context,
                                                builder: (_) => ReviewActionDialog(
                                                  title: approve
                                                      ? 'Talebi onayla'
                                                      : 'Talebi reddet',
                                                  requireNote: true,
                                                  message: 'Karar ve notunuz kaydedilir. Sipariş ve rezervasyon aynı kalır.',
                                                  send: (note, key) async {
                                                    final repo = await ref.read(
                                                      orderReviewRepositoryProvider
                                                          .future,
                                                    );
                                                    if (!context.mounted ||
                                                        ref
                                                                .read(
                                                                  accountProfileProvider,
                                                                )
                                                                .asData
                                                                ?.value
                                                                ?.id !=
                                                            profile?.id) {
                                                      throw StateError(
                                                        'Session changed',
                                                      );
                                                    }
                                                    await repo.decide(
                                                      r['id'] as String,
                                                      approve,
                                                      note,
                                                      key,
                                                    );
                                                  },
                                                ),
                                              );
                                              if (context.mounted) {
                                                ref.invalidate(
                                                  orderReviewRequestsProvider,
                                                );
                                              }
                                            },
                                            child: Text(
                                              approve
                                                  ? 'Talebi onayla'
                                                  : 'Talebi reddet',
                                            ),
                                          ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
      ),
    );
  }
}
