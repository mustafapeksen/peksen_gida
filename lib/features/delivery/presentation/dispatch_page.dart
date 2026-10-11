import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/domain/account_repository.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../products/presentation/price_page.dart' show newOperationKey;
import '../data/dispatch_repository.dart';

bool canUseDispatch(AccountRole role) => const {
  AccountRole.manager,
  AccountRole.owner,
  AccountRole.driver,
}.contains(role);

final dispatchDataProvider = FutureProvider.autoDispose<Map<String, dynamic>>(
  retry: (_, _) => null,
  (ref) async {
    final profile = await ref.watch(accountProfileProvider.future);
    if (profile == null || !canUseDispatch(profile.role)) {
      throw const AccountAccessException();
    }
    return (await ref.watch(dispatchRepositoryProvider.future)).read();
  },
);
final dispatchPendingProvider =
    FutureProvider.autoDispose<Map<String, dynamic>?>(retry: (_, _) => null, (
      ref,
    ) async {
      final profile = await ref.watch(accountProfileProvider.future);
      if (profile == null || !canUseDispatch(profile.role)) {
        throw const AccountAccessException();
      }
      return (await ref.watch(dispatchRepositoryProvider.future)).pending();
    });

List<Map<String, dynamic>> dispatchRows(
  Map<String, dynamic> data,
  String key,
) => (data[key] as List? ?? [])
    .map((e) => Map<String, dynamic>.from(e as Map))
    .toList();

String dispatchStatus(Object? status) =>
    const {
      'planned': 'Planlandı',
      'in_progress': 'Yolda',
      'completed': 'Tamamlandı',
      'cancelled': 'İptal edildi',
      'picked': 'Toplandı',
      'loaded': 'Yüklendi',
      'out_for_delivery': 'Dağıtımda',
      'delivered': 'Teslim edildi',
      'rejected': 'Reddedildi',
    }[status] ??
    'Tarihsel kayıt';

class DispatchPage extends ConsumerStatefulWidget {
  const DispatchPage({super.key});
  @override
  ConsumerState<DispatchPage> createState() => _DispatchPageState();
}

class _DispatchPageState extends ConsumerState<DispatchPage> {
  bool busy = false;
  String? message;
  Timer? timer;
  @override
  void initState() {
    super.initState();
    // Narrow dispatch polling; no GPS, location permission or Phase 12 service.
    timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!busy && ModalRoute.of(context)?.isCurrent == true) {
        ref.invalidate(dispatchDataProvider);
      }
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  void refresh() {
    ref.invalidate(dispatchDataProvider);
    ref.invalidate(dispatchPendingProvider);
  }

  Future<void> recover(Map<String, dynamic> pending) async {
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await (await ref.read(dispatchRepositoryProvider.future)).perform(
        pending['action'] as String,
        Map<String, dynamic>.from(pending['params'] as Map),
      );
      message = 'İşlemin sonucu alındı.';
    } on DispatchRejected {
      message = 'İşlem reddedildi. Güncel atama ve durumları kontrol edin.';
    } catch (_) {
      message = 'Sonuç alınamadı. Aynı isteği yeniden deneyin.';
    } finally {
      if (mounted) {
        setState(() => busy = false);
        refresh();
      }
    }
  }

  Future<void> edit(
    String title,
    String action,
    Map<String, dynamic> data, {
    Map<String, List<Map<String, dynamic>>> choices = const {},
    Map<String, String> labels = const {},
    Set<String> optional = const {},
    bool vehicle = false,
    bool reason = false,
  }) async {
    setState(() => busy = true);
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DispatchDialog(
        title: title,
        initial: data,
        choices: choices,
        labels: labels,
        optional: optional,
        vehicle: vehicle,
        reason: reason,
        send: (payload, key) async =>
            (await ref.read(dispatchRepositoryProvider.future))
                .perform(action, {'data': payload, 'request_key': key}),
      ),
    );
    if (mounted) {
      setState(() => busy = false);
      refresh();
    }
  }

  Widget runCard(Map<String, dynamic> run, bool manager, bool enabled) {
    final stops = dispatchRows(run, 'stops');
    final movable = stops
        .where((s) => s['closed_at'] == null && s['completed_at'] == null)
        .toList();
    final open = run['managed'] == true && run['ended_at'] == null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${run['plate']} · ${dispatchStatus(run['status'])}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text('Sefer: ${run['id']}'),
            if (stops.isEmpty) const Text('Henüz durak yok.'),
            for (final stop in stops)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${stop['sequence']}. Sipariş ${stop['number']}'),
                    Text(
                      stop['closed_at'] != null
                          ? 'Atama kapalı (geçmiş)'
                          : dispatchStatus(stop['order_status']),
                    ),
                if (!manager && open && movable.indexOf(stop) > 0)
                      TextButton(
                        onPressed: enabled
                            ? () {
                                final ids = movable
                                    .map((s) => s['id'])
                                    .toList();
                                final index = movable.indexOf(stop);
                                final previous = ids[index - 1];
                                ids[index - 1] = ids[index];
                                ids[index] = previous;
                                edit('Durak sırasını değiştir', 'reorder', {
                                  'run_id': run['id'],
                                  'stop_ids': ids,
                                });
                              }
                            : null,
                        child: const Text('Bir sıra yukarı'),
                      ),
                  ],
                ),
              ),
            if (open)
              Wrap(
                spacing: 8,
                children: [
                  if (!manager && run['status'] == 'planned')
                    FilledButton(
                      onPressed: enabled
                          ? () => edit('Yola çıkışı başlat', 'depart', {
                              'run_id': run['id'],
                            })
                          : null,
                      child: const Text('Yola çık'),
                    ),
                  if (manager)
                    TextButton(
                      onPressed: enabled
                          ? () => edit(
                              run['status'] == 'planned'
                                  ? 'Başlamamış seferi iptal et'
                                  : 'Seferi kapat',
                              run['status'] == 'planned'
                                  ? 'cancel'
                                  : 'complete',
                              {'run_id': run['id']},
                            )
                          : null,
                      child: Text(
                        run['status'] == 'planned'
                            ? 'Seferi iptal et'
                            : 'Seferi kapat',
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget workspace(Map<String, dynamic> data, bool manager, bool enabled) {
    final vehicles = dispatchRows(data, 'vehicles');
    final runs = dispatchRows(data, 'runs');
    final drivers = dispatchRows(data, 'drivers');
    final availableVehicles = vehicles
        .where(
          (v) =>
              v['active'] == true &&
              !runs.any(
                (r) => r['ended_at'] == null && r['vehicle_id'] == v['id'],
              ),
        )
        .map((v) => {'id': v['id'], 'name': v['plate']})
        .toList();
    final availableDrivers = drivers
        .where(
          (d) => !runs.any(
            (r) =>
                r['ended_at'] == null &&
                (r['primary_id'] == d['id'] || r['assistant_id'] == d['id']),
          ),
        )
        .toList();
    final planned = runs
        .where(
          (r) =>
              r['managed'] == true &&
              r['status'] == 'planned' &&
              r['ended_at'] == null,
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (manager) ...[
          Wrap(
            spacing: 8,
            children: [
              FilledButton(
                onPressed: enabled
                    ? () => edit('Araç oluştur', 'vehicle', {
                        'active': true,
                      }, vehicle: true)
                    : null,
                child: const Text('Araç ekle'),
              ),
              FilledButton(
                onPressed:
                    enabled &&
                        availableVehicles.isNotEmpty &&
                        availableDrivers.isNotEmpty
                    ? () => edit(
                        'Sefer oluştur',
                        'create_run',
                        {},
                        choices: {
                          'vehicle_id': availableVehicles,
                          'primary_id': availableDrivers,
                          'assistant_id': availableDrivers,
                        },
                        labels: {
                          'vehicle_id': 'Araç',
                          'primary_id': 'Birincil sürücü',
                          'assistant_id': 'Yardımcı sürücü',
                        },
                        optional: {'assistant_id'},
                      )
                    : null,
                child: const Text('Sefer oluştur'),
              ),
            ],
          ),
          for (final vehicle in vehicles)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${vehicle['plate']}'),
              subtitle: Text(
                vehicle['active'] == true ? 'Aktif araç' : 'Pasif araç',
              ),
              trailing: IconButton(
                tooltip: 'Aracı düzenle',
                onPressed: enabled
                    ? () => edit(
                        'Aracı düzenle',
                        'vehicle',
                        vehicle,
                        vehicle: true,
                      )
                    : null,
                icon: const Icon(Icons.edit_outlined),
              ),
            ),
          const Divider(),
          const Text('Tamamen toplanmış siparişler'),
          for (final order in dispatchRows(data, 'orders'))
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Sipariş ${order['number']}'),
              subtitle: Text(
                order['run_id'] == null
                    ? 'Atama bekliyor'
                    : 'Atanmış; değişiklik gerekçe ister',
              ),
              trailing: TextButton(
                onPressed:
                    enabled && planned.any((r) => r['id'] != order['run_id'])
                    ? () => edit(
                        'Sipariş ata',
                        'assign',
                        {'order_id': order['id']},
                        choices: {
                          'run_id': planned
                              .where((r) => r['id'] != order['run_id'])
                              .map(
                                (r) => {
                                  'id': r['id'],
                                  'name': '${r['plate']} · ${r['id']}',
                                },
                              )
                              .toList(),
                        },
                        labels: {'run_id': 'Hedef sefer'},
                        reason: order['run_id'] != null,
                      )
                    : null,
                child: const Text('Ata'),
              ),
            ),
          const Divider(),
        ],
        if (runs.isEmpty) const Text('Görüntülenecek sefer yok.'),
        for (final run in runs) runCard(run, manager, enabled),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Araç ve seferler'),
      actions: [
        IconButton(
          onPressed: busy ? null : refresh,
          icon: const Icon(Icons.refresh),
          tooltip: 'Yenile',
        ),
      ],
    ),
    body: ref
        .watch(accountProfileProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) =>
              const Center(child: Text('Hesap bilgisi alınamadı.')),
          data: (profile) {
            if (profile == null || !canUseDispatch(profile.role)) {
              return const Center(
                child: Text('Bu ekrana erişim yetkiniz yok.'),
              );
            }
            final pending = ref.watch(dispatchPendingProvider);
            final enabled = !busy && pending.hasValue && pending.value == null;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Sıra ve atamalar bu ekran açıkken 5 saniyede yenilenir. Yola çıkış için tüm açık siparişler yüklü olmalıdır. Teslimat onayı ve GPS bu ekranda yoktur.',
                ),
                pending.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (_, _) => const Text(
                    'Bekleyen işlem kontrol edilemedi. Yenileyin.',
                  ),
                  data: (request) => request == null
                      ? const SizedBox.shrink()
                      : Column(
                          children: [
                            const Text(
                              'Sonucu alınmamış işlem var. Yeni işlemden önce aynı isteği yeniden deneyin.',
                            ),
                            TextButton(
                              onPressed: busy ? null : () => recover(request),
                              child: const Text('Bekleyen işlemi yeniden dene'),
                            ),
                          ],
                        ),
                ),
                if (message != null) Text(message!),
                ref
                    .watch(dispatchDataProvider)
                    .when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (_, _) => const Text(
                        'Seferler alınamadı. Yenileyerek tekrar deneyin.',
                      ),
                      data: (data) => workspace(
                        data,
                        profile.role != AccountRole.driver,
                        enabled,
                      ),
                    ),
              ],
            );
          },
        ),
  );
}

class DispatchDialog extends StatefulWidget {
  const DispatchDialog({
    super.key,
    required this.title,
    required this.initial,
    required this.send,
    this.choices = const {},
    this.labels = const {},
    this.optional = const {},
    this.vehicle = false,
    this.reason = false,
  });
  final String title;
  final Map<String, dynamic> initial;
  final Map<String, List<Map<String, dynamic>>> choices;
  final Map<String, String> labels;
  final Set<String> optional;
  final bool vehicle, reason;
  final Future<void> Function(Map<String, dynamic>, String) send;
  @override
  State<DispatchDialog> createState() => _DispatchDialogState();
}

class _DispatchDialogState extends State<DispatchDialog> {
  late final plate = TextEditingController(
    text: widget.initial['plate'] as String?,
  );
  late final description = TextEditingController(
    text: widget.initial['description'] as String?,
  );
  final reason = TextEditingController();
  late bool active = widget.initial['active'] != false;
  final selected = <String, String?>{};
  String key = newOperationKey();
  Map<String, dynamic>? frozen;
  String? error;
  bool busy = false;
  @override
  void dispose() {
    plate.dispose();
    description.dispose();
    reason.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (frozen == null &&
        ((widget.vehicle && plate.text.trim().isEmpty) ||
            (widget.reason && reason.text.trim().isEmpty) ||
            widget.choices.keys.any(
              (k) => !widget.optional.contains(k) && selected[k] == null,
            ) ||
            (selected['assistant_id'] != null &&
                selected['primary_id'] == selected['assistant_id']))) {
      setState(
        () => error = 'Zorunlu alanları doldurun; sürücüler farklı olmalıdır.',
      );
      return;
    }
    final payload =
        frozen ??
        {
          ...widget.initial,
          ...selected,
          if (widget.vehicle) ...{
            'plate': plate.text.trim(),
            'description': description.text.trim(),
            'active': active,
          },
          if (widget.reason) 'reason': reason.text.trim(),
        };
    setState(() {
      busy = true;
      error = null;
      frozen = payload;
    });
    try {
      await widget.send(payload, key);
      if (mounted) Navigator.of(context).pop();
    } on DispatchRejected {
      if (mounted) {
        setState(() {
          error = 'İşlem reddedildi. Güncel atama, yetki ve durumları kontrol edin.';
          frozen = null;
          key = newOperationKey();
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Sonuç alınamadı. Aynı isteği yeniden deneyin.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: AlertDialog(
      title: Text(widget.title),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.vehicle) ...[
            TextField(
              controller: plate,
              readOnly: frozen != null,
              decoration: const InputDecoration(labelText: 'Plaka'),
            ),
            TextField(
              controller: description,
              readOnly: frozen != null,
              decoration: const InputDecoration(labelText: 'Açıklama'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Aktif'),
              value: active,
              onChanged: frozen != null
                  ? null
                  : (v) => setState(() => active = v),
            ),
          ],
          for (final entry in widget.choices.entries)
            DropdownButtonFormField<String>(
              isExpanded: true,
              decoration: InputDecoration(labelText: widget.labels[entry.key]),
              items: [
                if (widget.optional.contains(entry.key))
                  const DropdownMenuItem(value: '', child: Text('Yok')),
                for (final row in entry.value)
                  DropdownMenuItem(
                    value: row['id'] as String,
                    child: Text(
                      '${row['name']}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: frozen != null
                  ? null
                  : (v) => setState(
                      () => selected[entry.key] = v == '' ? null : v,
                    ),
            ),
          if (widget.reason)
            TextField(
              controller: reason,
              readOnly: frozen != null,
              decoration: const InputDecoration(labelText: 'Gerekçe (zorunlu)'),
            ),
          if (!widget.vehicle && widget.choices.isEmpty && !widget.reason)
            const Text(
              'İşlem güncel yetki ve durumlarla sunucuda kontrol edilecek.',
            ),
          if (error != null) Text(error!),
        ],
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Kapat'),
        ),
        FilledButton(
          onPressed: busy ? null : submit,
          child: Text(
            busy
                ? 'Kaydediliyor…'
                : frozen != null
                ? 'Aynı isteği yeniden dene'
                : 'Kaydet',
          ),
        ),
      ],
    ),
  );
}
