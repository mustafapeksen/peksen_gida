import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/domain/account_repository.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../customer/domain/shop_repository.dart';
import '../../customer/presentation/catalog_page.dart';
import '../../customer/presentation/shop_providers.dart';
import '../data/order_review_repository.dart';
import 'review_action_dialog.dart';

final alternativeIntentProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>(
      dependencies: [shopCustomerProvider],
      retry: (_, _) => null,
      (ref, id) async {
        await ref.watch(shopCustomerProvider.future);
        ref.watch(accountProfileProvider);
        return (await ref.watch(orderReviewRepositoryProvider.future))
            .alternatives(id);
      },
    );

class AlternativeIntentPage extends ConsumerWidget {
  const AlternativeIntentPage({super.key, required this.orderId});
  final String orderId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(accountProfileProvider).asData?.value;
    final state = ref.watch(alternativeIntentProvider(orderId));
    return Scaffold(
      appBar: AppBar(title: const Text('Alternatif teklifleri')),
      body: SafeArea(
        child: ShopGuard(
          child: state.when(
            skipLoadingOnRefresh: false,
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => Center(
              child: TextButton(
                onPressed: () =>
                    ref.invalidate(alternativeIntentProvider(orderId)),
                child: const Text('Teklifleri yeniden yükle'),
              ),
            ),
            data: (data) => ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Kabul veya ret siparişi değiştirmez. Kabul yalnız değişiklik niyetidir; yönetici kararı ve ayrı uygulama gerekir.',
                ),
                TextButton(
                  onPressed: () =>
                      ref.invalidate(alternativeIntentProvider(orderId)),
                  child: const Text('Teklifleri yenile'),
                ),
                if (data['status'] != 'submitted')
                  const Text('Bu siparişin teklif işlemleri kapalı.'),
                if (data['status'] == 'submitted' &&
                    profile?.role == AccountRole.salesOperator)
                  _ProposalForm(
                    orderId: orderId,
                    items: List<Map<String, dynamic>>.from(
                      (data['items'] as List).map(
                        (e) => Map<String, dynamic>.from(e as Map),
                      ),
                    ),
                  ),
                if ((data['offers'] as List).isEmpty)
                  const Text('Henüz alternatif teklif yok.'),
                for (final offer in data['offers'] as List)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            '${offer['name']} · ${offer['quantity']} ${offer['unit']}',
                          ),
                          Text(switch (offer['status']) {
                            'accepted' => 'Müşteri kabul etti — yalnız niyet',
                            'rejected' => 'Müşteri reddetti',
                            _ => 'Müşteri yanıtı bekliyor',
                          }),
                          if (data['status'] == 'submitted' &&
                              offer['status'] == 'pending' &&
                              profile?.role == AccountRole.customer)
                            Wrap(
                              spacing: 8,
                              children: [
                                for (final accept in [true, false])
                                  TextButton(
                                    onPressed: () async {
                                      await showDialog<bool>(
                                        context: context,
                                        builder: (_) => ReviewActionDialog(
                                          title: accept
                                              ? 'Alternatifi kabul et'
                                              : 'Alternatifi reddet',
                                          message: 'Sipariş kalemleri, tutar ve rezervasyon değişmeyecek.',
                                          send: (_, key) async {
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
                                            await repo.respond(
                                              offer['id'] as String,
                                              accept,
                                              key,
                                            );
                                          },
                                        ),
                                      );
                                      if (context.mounted) {
                                        ref.invalidate(
                                          alternativeIntentProvider(orderId),
                                        );
                                      }
                                    },
                                    child: Text(accept ? 'Kabul et' : 'Reddet'),
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
      ),
    );
  }
}

class _ProposalForm extends ConsumerStatefulWidget {
  const _ProposalForm({required this.orderId, required this.items});
  final String orderId;
  final List<Map<String, dynamic>> items;
  @override
  ConsumerState<_ProposalForm> createState() => _ProposalFormState();
}

class _ProposalFormState extends ConsumerState<_ProposalForm> {
  String? itemId, unitId, error;
  final quantity = TextEditingController(text: '1');
  @override
  void dispose() {
    quantity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ref
      .watch(catalogProvider)
      .when(
        loading: () => const LinearProgressIndicator(),
        error: (_, _) => TextButton(
          onPressed: () => ref.invalidate(catalogProvider),
          child: const Text('Ürünleri yeniden yükle'),
        ),
        data: (products) {
          final units = <String, String>{
            for (final p in products)
              for (final CatalogUnit u in p.units)
                u.id: '${p.name} / ${u.name}',
          };
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: itemId,
                decoration: const InputDecoration(
                  labelText: 'Değişmesi önerilen kalem',
                ),
                items: [
                  for (final i in widget.items)
                    DropdownMenuItem(
                      value: i['id'] as String,
                      child: Text(
                        '${i['name']} (${i['quantity']} ${i['unit']})',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (value) => setState(() => itemId = value),
              ),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: unitId,
                decoration: const InputDecoration(
                  labelText: 'Alternatif ürün / birim',
                ),
                items: [
                  for (final u in units.entries)
                    DropdownMenuItem(
                      value: u.key,
                      child: Text(u.value, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (value) => setState(() => unitId = value),
              ),
              TextField(
                controller: quantity,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Önerilen miktar'),
              ),
              if (error != null) Text(error!),
              FilledButton(
                onPressed: () async {
                  final count = int.tryParse(quantity.text);
                  if (itemId == null ||
                      unitId == null ||
                      !units.containsKey(unitId) ||
                      count == null ||
                      count <= 0 ||
                      count > 2147483647) {
                    setState(
                      () => error =
                          'Kalem, ürün/birim ve pozitif tam sayı miktar seçin.',
                    );
                    return;
                  }
                  final item = itemId!,
                      unit = unitId!,
                      actor = ref
                          .read(accountProfileProvider)
                          .asData
                          ?.value
                          ?.id;
                  await showDialog<bool>(
                    context: context,
                    builder: (_) => ReviewActionDialog(
                      title: 'Alternatif teklif gönder',
                      message:
                          '${units[unit]} · $count\nBu teklif siparişi veya fiyatını değiştirmez. Minimum miktar sunucuda doğrulanır.',
                      send: (_, key) async {
                        final repo = await ref.read(
                          orderReviewRepositoryProvider.future,
                        );
                        if (!mounted ||
                            ref
                                    .read(accountProfileProvider)
                                    .asData
                                    ?.value
                                    ?.id !=
                                actor) {
                          throw StateError('Session changed');
                        }
                        await repo.propose(item, unit, count, key);
                      },
                    ),
                  );
                  if (mounted) {
                    ref.invalidate(alternativeIntentProvider(widget.orderId));
                  }
                },
                child: const Text('Alternatif öner'),
              ),
            ],
          );
        },
      );
}
