import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/domain/account_repository.dart';
import '../../auth/presentation/auth_providers.dart';

import '../../products/presentation/price_page.dart' show newOperationKey;
import 'tracking_map.dart';
import 'tracking_providers.dart';

class TrackingPage extends ConsumerStatefulWidget {
  const TrackingPage({super.key});
  @override
  ConsumerState<TrackingPage> createState() => _TrackingPageState();
}

class _TrackingPageState extends ConsumerState<TrackingPage> {
  Timer? timer;
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) ref.invalidate(trackingDataProvider);
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> action(String run, bool start) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final publisher = await ref.read(trackingPublisherProvider.future);
      if (start) {
        await publisher.start(run, newOperationKey());
      } else {
        await publisher.stop();
      }
      ref.invalidate(trackingDataProvider);
    } catch (_) {
      error = 'Takip başlatılamadı. Yetki ve bağlantıyı kontrol edin.';
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      trackingChangesProvider,
      (_, _) => ref.invalidate(trackingDataProvider),
    );
    final data = ref.watch(trackingDataProvider);
    final isDriver =
        ref.watch(accountProfileProvider).asData?.value?.role ==
        AccountRole.driver;
    final publisher = ref.watch(trackingPublisherProvider).asData?.value;
    return Scaffold(
      appBar: AppBar(title: const Text('Canlı teslimat konumu')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Yalnız aktif teslimatın son konumu gösterilir. Rota geçmişi tutulmaz.',
            ),
            const SizedBox(height: 8),
            if (error != null) Text(error!),
            TextButton(
              onPressed: () => ref.invalidate(trackingDataProvider),
              child: const Text('Yenile'),
            ),
            data.when(
              skipLoadingOnRefresh: false,
              skipError: false,
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => const Text(
                'Konum alınamadı. Önceki konum gizlendi; bağlantı ve erişimi kontrol edin.',
              ),
              data: (rows) => rows.isEmpty
                  ? isDriver
                        ? Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const Icon(
                                    Icons.local_shipping_outlined,
                                    size: 40,
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Aktif primary seferiniz yok. Konum paylaşımı için Manager/Owner tarafından primary sürücü olarak atanmanız gerekir.',
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Atamanız varsa seferin yola çıkmış ve açık siparişin dağıtımda olması gerekir. Hazırlık aşamasında GPS izni istenmez.',
                                  ),
                                  const SizedBox(height: 16),
                                  FilledButton.icon(
                                    onPressed: () =>
                                        context.push('/account/dispatch'),
                                    icon: const Icon(
                                      Icons.local_shipping_outlined,
                                    ),
                                    label: const Text('Araç ve seferler'),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : const Text('Takip edilebilir aktif teslimat yok.')
                  : Column(
                      children: rows.map((row) {
                        final lat = row['latitude'] as num?;
                        final lon = row['longitude'] as num?;
                        final sampled = DateTime.tryParse(
                          row['sampled_at']?.toString() ?? '',
                        );
                        final stale =
                            row['stale'] == true ||
                            sampled == null ||
                            DateTime.now().toUtc().difference(sampled) >=
                                const Duration(seconds: 60);
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text('Araç: ${row['plate']}'),
                                if (isDriver && row['can_publish'] != true) ...[
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Assistant sürücü haritayı görüntüleyebilir; konum paylaşımı bu fazda primary sürücüye aittir.',
                                  ),
                                  const SizedBox(height: 8),
                                ],
                                Text(switch (row['status']) {
                                  'live' =>
                                    stale
                                        ? 'Eski konum — 60 saniyedir güncellenmedi.'
                                        : 'Konum güncel',
                                  'permission_denied' => 'Takip sorunu: konum/bildirim izni verilmedi.',
                                  'gps_disabled' => 'Takip sorunu: GPS kapalı.',
                                  'starting' => 'İlk konum bekleniyor.',
                                  _ => 'Konum paylaşımı kapalı.',
                                }),
                                if (sampled != null)
                                  Text('Son ölçüm: ${sampled.toLocal()}'),
                                if (row['can_publish'] == true) ...[
                                  if (publisher != null)
                                    ListenableBuilder(
                                      listenable: publisher,
                                      builder: (_, _) => Semantics(
                                        liveRegion: true,
                                        child: Text(
                                          publisher.message,
                                          key: const ValueKey(
                                            'tracking-status',
                                          ),
                                        ),
                                      ),
                                    ),

                                  const Text(
                                    'Primary sürücü olarak atanmışsınız. Başlat düğmesine dokunduğunuzda gerekli Android konum ve bildirim izinleri istenir. Bildirim açık kalır; uygulamayı kapatırsanız yeniden başlatmanız gerekir.',
                                  ),
                                  Wrap(
                                    spacing: 8,
                                    children: [
                                      FilledButton(
                                        onPressed: busy
                                            ? null
                                            : () => action(
                                                row['id'] as String,
                                                true,
                                              ),
                                        child: const Text(
                                          'Konum paylaşımını başlat',
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: busy
                                            ? null
                                            : () => action(
                                                row['id'] as String,
                                                false,
                                              ),
                                        child: const Text('Paylaşımı durdur'),
                                      ),
                                    ],
                                  ),
                                ],
                                if (lat != null && lon != null) ...[
                                  const Text('Haritadaki yeşil işaret: araç'),
                                  SizedBox(
                                    height: 260,
                                    child: ref.watch(
                                      trackingMapBuilderProvider,
                                    )(lat.toDouble(), lon.toDouble()),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
