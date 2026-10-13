import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/domain/account_repository.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../products/domain/product_repository.dart'
    show formatKurus, parseMoney;
import '../../products/presentation/price_page.dart' show newOperationKey;
import '../data/report_repository.dart';

bool canReadReports(AccountRole role) =>
    role == AccountRole.manager || role == AccountRole.owner;
typedef ReportQuery = ({
  String section,
  String start,
  String end,
  String? beforeTime,
  String? beforeId,
});
final reportDataProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, ReportQuery>(retry: (_, _) => null, (
      ref,
      query,
    ) async {
      final profile = await ref.watch(accountProfileProvider.future);
      if (profile == null ||
          !canReadReports(profile.role) ||
          (query.section != 'reports' && profile.role != AccountRole.owner)) {
        throw const AccountAccessException();
      }
      final repository = await ref.watch(reportRepositoryProvider.future);
      return switch (query.section) {
        'reports' => repository.report(query.start, query.end),
        'salary' => {
          ...await repository.salaries('${query.start.substring(0, 7)}-01'),
          'pending': await repository.pending(),
        },
        'audit' => {
          'rows': await repository.audit(query.beforeTime, query.beforeId),
        },
        _ => throw const AccountAccessException(),
      };
    });

String reportDay(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
// Istanbul has UTC+03 year-round for the application's current operating dates.
DateTime istanbulToday() {
  final now = DateTime.now().toUtc().add(const Duration(hours: 3));
  return DateTime(now.year, now.month, now.day);
}

class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key, this.section = 'reports'});
  final String section;
  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  late DateTime end = istanbulToday();
  late DateTime start = DateTime(end.year, end.month);
  String? beforeTime, beforeId, message;
  bool busy = false;
  ReportQuery get query => (
    section: widget.section,
    start: reportDay(start),
    end: reportDay(end),
    beforeTime: beforeTime,
    beforeId: beforeId,
  );
  void refresh() => ref.invalidate(reportDataProvider);
  Future<void> pickDay(bool first) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: first ? start : end,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (selected == null || !mounted) return;
    setState(() {
      if (first) {
        start = selected;
        if (end.isBefore(start)) end = start;
      } else {
        end = selected;
        if (start.isAfter(end)) start = end;
      }
    });
  }

  Future<void> editSalary(
    Map<String, dynamic> employee,
    Map<String, dynamic>? record,
  ) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => SalaryDialog(
        employee: employee,
        record: record,
        month: '${reportDay(start).substring(0, 7)}-01',
        save: (params) async =>
            (await ref.read(reportRepositoryProvider.future))
                .saveSalary(params),
      ),
    );
    if (mounted) refresh();
  }

  Future<void> recover(Map<String, dynamic> request) async {
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await (await ref.read(reportRepositoryProvider.future))
          .saveSalary(request);
      message = 'Kayıt sonucu alındı.';
    } on SalaryRejected {
      message =
          'İşlem reddedildi. Güncel yetki ve kayıt sürümünü kontrol edin.';
    } catch (_) {
      message = 'Sonuç alınamadı. Aynı isteği yeniden deneyin.';
    } finally {
      if (mounted) {
        setState(() => busy = false);
        refresh();
      }
    }
  }

  Widget card(String title, List<Widget> children) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    ),
  );
  String money(Object? value) => formatKurus((value ?? '0').toString());
  List<Map<String, dynamic>> rows(Object? value) => (value as List? ?? [])
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();

  List<Widget> reports(Map<String, dynamic> data) => [
    const Text(
      'Günler Europe/Istanbul saat dilimindedir. Sipariş ve tahsilatlar mevcut durumlarıyla gösterilir; tutarlar kâr veya muhasebe cirosu değildir.',
    ),
    Text('Rapor zamanı: ${data['as_of']}'),
    card('Siparişler — oluşturulma tarihine göre', [
      if (rows(data['orders']).isEmpty) const Text('Bu aralıkta sipariş yok.'),
      for (final row in rows(data['orders']))
        Text('${row['status']}: ${row['count']}'),
    ]),
    card('Kesinleşmiş teslimatlar — kesinleşme tarihine göre', [
      Text('Adet: ${(data['deliveries'] as Map)['count']}'),
      Text(
        'Sipariş toplamı: ${money((data['deliveries'] as Map)['total_kurus'])}',
      ),
    ]),
    card('Tahsilatlar — tahsilat tarihine göre', [
      if (rows(data['payments']).isEmpty)
        const Text('Bu aralıkta tahsilat yok.'),
      for (final row in rows(data['payments']))
        Text(
          '${row['status'] == 'verified' ? 'Doğrulandı' : 'Kaydedildi'}: ${row['count']} kayıt / ${money(row['total_kurus'])}',
        ),
    ]),
    card('Stok — anlık, taban birim', [
      if (rows(data['inventory']).isEmpty) const Text('Stok kaydı yok.'),
      for (final row in rows(data['inventory']))
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            '${row['name']} (${row['base_unit']})\nFiziksel: ${row['physical_qty']} · Rezerve: ${row['reserved_qty']} · Kullanılabilir: ${row['available_qty']}',
          ),
        ),
    ]),
    card('Sürücü puanları — tüm zamanlar', [
      if (rows(data['ratings']).isEmpty) const Text('Henüz puan yok.'),
      for (final row in rows(data['ratings']))
        Text(
          '${row['name']}: ${row['count']} puan · Ortalama: ${row['average']}\n1★ ${row['stars_1']} · 2★ ${row['stars_2']} · 3★ ${row['stars_3']} · 4★ ${row['stars_4']} · 5★ ${row['stars_5']}',
        ),
    ]),
  ];
  List<Widget> salaries(Map<String, dynamic> data) {
    final records = rows(data['records']);
    final pending = data['pending'] as Map<String, dynamic>?;
    return [
      const Text(
        'Yalnız manuel maaş/prim kaydıdır. Bordro, ödeme veya otomatik prim hesaplanmaz.',
      ),
      Text('Ay: ${reportDay(start).substring(0, 7)}'),
      if (pending != null)
        card('Sonucu bekleyen kayıt', [
          const Text('Yeni işlem açmadan önce önceki isteğin sonucunu alın.'),
          FilledButton(
            onPressed: busy ? null : () => recover(pending),
            child: const Text('Aynı isteği yeniden dene'),
          ),
        ]),
      if (rows(data['employees']).isEmpty) const Text('Çalışan kaydı yok.'),
      for (final employee in rows(data['employees']))
        Builder(
          builder: (_) {
            final matches = records.where(
              (r) => r['employee_id'] == employee['id'],
            );
            final record = matches.isEmpty ? null : matches.first;
            return card(
              '${employee['name']}${employee['active'] == false ? ' (pasif)' : ''}',
              [
                Text(
                  record == null
                      ? 'Bu ay için kayıt yok.'
                      : 'Maaş: ${money(record['salary_kurus'])} · Prim: ${money(record['bonus_kurus'])}',
                ),
                FilledButton.tonal(
                  onPressed: pending != null || busy
                      ? null
                      : () => editSalary(employee, record),
                  child: Text(
                    record == null ? 'Kayıt oluştur' : 'Gerekçeyle düzelt',
                  ),
                ),
              ],
            );
          },
        ),
      // Retain visibility of historical records after employee→customer conversion.
      for (final record in records.where(
        (r) => !rows(data['employees']).any((e) => e['id'] == r['employee_id']),
      ))
        card('${record['name']} — geçmiş çalışan kaydı', [
          Text(
            'Maaş: ${money(record['salary_kurus'])} · Prim: ${money(record['bonus_kurus'])}',
          ),
        ]),
      card('Değişiklik geçmişi — son 100', [
        if (rows(data['history']).isEmpty)
          const Text('Bu ay için değişiklik geçmişi yok.'),
        for (final row in rows(data['history']))
          Text(
            '${row['changed_at']} · Aktör: ${row['actor_id']}\n${row['reason']}\nMaaş: ${money((row['new_record'] as Map)['salary_kurus'])} · Prim: ${money((row['new_record'] as Map)['bonus_kurus'])}',
          ),
      ]),
    ];
  }

  List<Widget> audit(Map<String, dynamic> data) {
    final entries = rows(data['rows']);
    return [
      const Text('Salt okunur olay özeti. Ham kayıt içeriği gösterilmez.'),
      if (entries.isEmpty) const Text('Bu sayfada audit kaydı yok.'),
      for (final row in entries)
        card('${row['action']}', [
          Text(
            'Aktör: ${row['actor_name']}\nZaman: ${row['created_at']}\nKayıt: ${row['entity_type']} / ${row['entity_id']}',
          ),
        ]),
      if (entries.length == 50)
        OutlinedButton(
          onPressed: () => setState(() {
            beforeTime = entries.last['created_at'] as String;
            beforeId = entries.last['id'] as String;
          }),
          child: const Text('Önceki kayıtlar'),
        ),
      if (beforeId != null)
        TextButton(
          onPressed: () => setState(() {
            beforeTime = null;
            beforeId = null;
          }),
          child: const Text('En yeni kayıtlar'),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(reportDataProvider(query));
    return Scaffold(
      appBar: AppBar(
        title: Text(switch (widget.section) {
          'salary' => 'Maaş ve prim',
          'audit' => 'Audit kayıtları',
          _ => 'Operasyon raporları',
        }),
        actions: [
          IconButton(
            onPressed: refresh,
            tooltip: 'Yenile',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (widget.section != 'audit')
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: () => pickDay(true),
                    child: Text(
                      '${widget.section == 'salary' ? 'Ay seç' : 'Başlangıç'}: ${reportDay(start)}',
                    ),
                  ),
                  if (widget.section == 'reports')
                    OutlinedButton(
                      onPressed: () => pickDay(false),
                      child: Text('Bitiş: ${reportDay(end)}'),
                    ),
                ],
              ),
            if (message != null) Text(message!),
            data.when(
              skipLoadingOnRefresh: false,
              skipLoadingOnReload: false,
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => const Text(
                'Veri alınamadı veya bu ekrana erişim yetkiniz yok. Yenileyerek tekrar deneyin.',
              ),
              data: (value) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: switch (widget.section) {
                  'salary' => salaries(value),
                  'audit' => audit(value),
                  _ => reports(value),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SalaryDialog extends StatefulWidget {
  const SalaryDialog({
    super.key,
    required this.employee,
    required this.record,
    required this.month,
    required this.save,
  });
  final Map<String, dynamic> employee;
  final Map<String, dynamic>? record;
  final String month;
  final Future<void> Function(Map<String, dynamic>) save;
  @override
  State<SalaryDialog> createState() => _SalaryDialogState();
}

class _SalaryDialogState extends State<SalaryDialog> {
  bool rejected = false;
  late final salary = TextEditingController(
    text: formatKurus((widget.record?['salary_kurus'] ?? '0').toString())
        .replaceAll(' TL', ''),
  );
  late final bonus = TextEditingController(
    text: formatKurus((widget.record?['bonus_kurus'] ?? '0').toString())
        .replaceAll(' TL', ''),
  );
  final reason = TextEditingController();
  bool busy = false;
  String? error;
  Map<String, dynamic>? request;
  @override
  void dispose() {
    salary.dispose();
    bonus.dispose();
    reason.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (request == null) {
      final s = parseMoney(salary.text), b = parseMoney(bonus.text);
      if (s == null || b == null || reason.text.trim().isEmpty) {
        setState(() => error = 'Geçerli maaş, prim ve gerekçe girin.');
        return;
      }
      request = {
        'target_employee': widget.employee['id'],
        'target_month': widget.month,
        'salary_kurus': s,
        'bonus_kurus': b,
        'reason': reason.text.trim(),
        'expected_revision': widget.record?['revision'] ?? -1,
        'request_key': newOperationKey(),
      };
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.save(request!);
      if (mounted) Navigator.pop(context);
    } on SalaryRejected {
      if (mounted) {
        setState(() {
          rejected = true;
          error =
              'İşlem reddedildi. Kapatıp güncel kayıt ve yetkiyi yenileyin.';
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
      title: Text(
        '${widget.employee['name']} · ${widget.month.substring(0, 7)}',
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: salary,
              enabled: request == null && !busy,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Maaş (TL)'),
            ),
            TextField(
              controller: bonus,
              enabled: request == null && !busy,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Prim (TL)'),
            ),
            TextField(
              controller: reason,
              enabled: request == null && !busy,
              decoration: const InputDecoration(labelText: 'Gerekçe'),
            ),
            if (error != null) Text(error!),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: const Text('Kapat'),
        ),
        FilledButton(
          onPressed: busy || rejected ? null : submit,
          child: Text(
            busy
                ? 'Kaydediliyor…'
                : request == null
                ? 'Kaydet'
                : 'Aynı isteği yeniden dene',
          ),
        ),
      ],
    ),
  );
}
