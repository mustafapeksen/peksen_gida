import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../products/domain/product_repository.dart' show formatKurus;
import 'catalog_page.dart';
import 'shop_providers.dart';
import '../../orders/presentation/order_workflow_panel.dart';

final customerOrdersProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>(
      dependencies: [shopCustomerProvider],
      retry: (_, _) => null,
      (ref) async {
        final customer = await ref.watch(shopCustomerProvider.future);
        return (await ref.watch(shopRepositoryProvider.future))
            .orders(customer);
      },
    );

String orderStatusLabel(String status) => switch (status) {
  'submitted' => 'Gönderildi',
  'pending_approval' => 'Yönetici onayı bekliyor',
  'draft' => 'Taslak',
  'picking' => 'Hazırlanıyor',
  'picked' => 'Hazır',
  'assigned' => 'Sefer atandı',
  'loaded' => 'Yüklendi',
  'out_for_delivery' => 'Dağıtımda',
  'delivered' => 'Teslim edildi',
  'cancelled' => 'İptal edildi',
  'rejected' => 'Reddedildi',
  _ => 'İşlem sürüyor',
};

class CustomerOrdersPage extends ConsumerWidget {
  const CustomerOrdersPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Siparişlerim')),
    body: SafeArea(
      child: ShopGuard(
        child: ref
            .watch(customerOrdersProvider)
            .when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => Center(
                child: TextButton(
                  onPressed: () => ref.invalidate(customerOrdersProvider),
                  child: const Text('Siparişleri yeniden yükle'),
                ),
              ),
              data: (orders) => RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(customerOrdersProvider);
                  try {
                    await ref.read(customerOrdersProvider.future);
                  } catch (_) {}
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    const Text(
                      'Ağ kesintisinde yeniden sipariş vermeden önce buradan kayıt durumunu kontrol edin.',
                    ),
                    if (orders.isEmpty) const Text('Henüz siparişiniz yok.'),
                    for (final o in orders)
                      Card(
                        child: ExpansionTile(
                          title: Text(orderStatusLabel(o['status'] as String)),
                          subtitle: Text(
                            '${o['id']}\n${formatKurus(o['total_kurus'].toString())}',
                          ),
                          children: [
                            OrderWorkflowPanel(
                              key: ValueKey(o['id']),
                              orderId: o['id'] as String,
                              onChanged: () =>
                                  ref.invalidate(customerOrdersProvider),
                            ),
                            if (o['credit_check_state'] == 'not_evaluated')
                              const Text(
                                'Cari kontrol hesaplanmadı; gönderim borç oluşturmaz.',
                              ),
                            for (final line in o['order_items'] as List)
                              ListTile(
                                title: Text(
                                  '${line['quantity']} ${line['unit']}',
                                ),
                                subtitle: Text(
                                  'Kayıtlı kalem tutarı: ${formatKurus(line['line_total_kurus'].toString())}',
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
      ),
    ),
  );
}
