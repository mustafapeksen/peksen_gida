import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/notification_repository.dart';
import '../../../core/notifications/push_service.dart';
import '../../auth/domain/account_repository.dart';
import '../../auth/presentation/auth_providers.dart';

class NotificationPage extends ConsumerStatefulWidget {
  const NotificationPage({super.key});
  @override
  ConsumerState<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends ConsumerState<NotificationPage> {
  final _older = <Map<String, dynamic>>[];
  bool _busy = false, _end = false;
  String? _message;
  String? _owner;
  Future<void> _perform(Future<void> Function() operation) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await operation();
    } catch (_) {
      if (mounted) {
        setState(
          () => _message = 'İşlem tamamlanamadı. Bağlantıyı ve hesap erişimini kontrol edip tekrar deneyin.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inbox = ref.watch(notificationInboxProvider);
    final profile = ref.watch(accountProfileProvider).asData?.value;
    final role = profile?.role;
    final owner = profile?.id;
    if (_owner != owner) {
      _owner = owner;
      _older.clear();
      _end = false;
      _message = null;
    }
    final push = ref.watch(pushServiceProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bildirimler'),
        actions: [
          IconButton(
            tooltip: 'Yenile',
            icon: const Icon(Icons.refresh),
            onPressed: _busy
                ? null
                : () {
                    setState(() {
                      _older.clear();
                      _end = false;
                    });
                    ref.invalidate(notificationInboxProvider);
                  },
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (push.asData?.value == null)
              const Text(
                'Cihaz bildirimi yapılandırılmadı. Bildirim geçmişinizi buradan okuyabilirsiniz.',
              )
            else
              FilledButton.tonal(
                onPressed: _busy
                    ? null
                    : () => _perform(() async {
                        final status = await push.requireValue!.enable();
                        if (mounted) setState(() => _message = status);
                      }),
                child: const Text('Bu cihazda bildirimleri aç'),
              ),
            if (role == AccountRole.manager || role == AccountRole.owner)
              OutlinedButton(
                onPressed: () =>
                    context.push('/account/notifications/campaign'),
                child: const Text('Büyük indirim bildirimi oluştur'),
              ),
            if (_message != null) Text(_message!, semanticsLabel: _message),
            if (_busy) const LinearProgressIndicator(),
            inbox.when(
              skipLoadingOnRefresh: false,
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) =>
                  const Text('Bildirimler yüklenemedi. Yeniden deneyin.'),
              data: (first) {
                final rows = [...first, ..._older];
                if (rows.isEmpty) return const Text('Henüz bildiriminiz yok.');
                return Column(
                  children: [
                    for (final row in rows)
                      Card(
                        child: Column(
                          children: [
                            ListTile(
                              leading: Icon(
                                row['read_at'] == null
                                    ? Icons.mark_email_unread_outlined
                                    : Icons.drafts_outlined,
                              ),
                              title: Text(
                                notificationLabel(row['type'] as String),
                              ),
                              subtitle: Text(
                                '${row['body']}\n${DateTime.tryParse(row['created_at'] as String)?.toLocal() ?? ''}',
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: _busy
                                  ? null
                                  : () => _perform(() async {
                                      final repository = await ref.read(
                                        notificationRepositoryProvider.future,
                                      );
                                      final route = await repository
                                          .destination(row['id'] as String);
                                      if (!allowedNotificationRoute(route)) {
                                        throw StateError('Invalid route');
                                      }
                                      ref.invalidate(notificationInboxProvider);
                                      if (context.mounted && _owner == owner) {
                                        context.push(route);
                                      }
                                    }),
                            ),
                            if (row['read_at'] == null)
                              TextButton(
                                onPressed: _busy
                                    ? null
                                    : () => _perform(() async {
                                        await (await ref.read(
                                          notificationRepositoryProvider.future,
                                        )).markRead(row['id'] as String);
                                        setState(() {
                                          _older.clear();
                                          _end = false;
                                        });
                                        ref.invalidate(
                                          notificationInboxProvider,
                                        );
                                      }),
                                child: const Text('Okundu işaretle'),
                              ),
                          ],
                        ),
                      ),
                    if (!_end && first.length == 50)
                      OutlinedButton(
                        onPressed: _busy
                            ? null
                            : () => _perform(() async {
                                final next = await (await ref.read(
                                  notificationRepositoryProvider.future,
                                )).inbox(before: rows.last);
                                if (mounted && _owner == owner) {
                                  setState(() {
                                    _older.addAll(next);
                                    _end = next.length < 50;
                                  });
                                }
                              }),
                        child: const Text('Daha eski bildirimler'),
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

String notificationLabel(String type) => switch (type) {
  'new_order' => 'Yeni sipariş',
  'approved' => 'Sipariş onaylandı',
  'alternative' => 'Alternatif teklif',
  'preparing' => 'Sipariş hazırlanıyor',
  'ready' || 'assigned_ready' => 'Sipariş hazır',
  'departed' => 'Teslimat yola çıktı',
  'gps_problem' => 'Konum takip sorunu',
  'disputed' => 'Teslimat uyuşmazlığı',
  'delivered' => 'Teslimat tamamlandı',
  'campaign' => 'Büyük indirim duyurusu',
  'credit' => 'Cari limit incelemesi',
  _ => 'Bildirim',
};
