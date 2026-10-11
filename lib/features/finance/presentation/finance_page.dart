import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/domain/account_repository.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../products/domain/product_repository.dart'
    show formatKurus, parseMoney;
import '../../products/presentation/price_page.dart' show newOperationKey;
import '../data/finance_repository.dart';

bool canUseFinance(AccountRole role) => const {
  AccountRole.salesOperator,
  AccountRole.driver,
  AccountRole.accounting,
  AccountRole.manager,
  AccountRole.owner,
}.contains(role);

final financeRowsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>(retry: (_, _) => null, (
      ref,
      section,
    ) async {
      final profile = await ref.watch(accountProfileProvider.future);
      if (profile == null || !canUseFinance(profile.role)) {
        throw const AccountAccessException();
      }
      return (await ref.watch(financeRepositoryProvider.future)).read(section);
    });
final financePendingProvider =
    FutureProvider.autoDispose<Map<String, dynamic>?>(retry: (_, _) => null, (
      ref,
    ) async {
      final profile = await ref.watch(accountProfileProvider.future);
      if (profile == null || !canUseFinance(profile.role)) {
        throw const AccountAccessException();
      }
      return (await ref.watch(financeRepositoryProvider.future)).pending();
    });

class FinancePage extends ConsumerStatefulWidget {
  const FinancePage({super.key});
  @override
  ConsumerState<FinancePage> createState() => _FinancePageState();
}

class _FinancePageState extends ConsumerState<FinancePage> {
  String section = 'orders';
  bool recovering = false;
  String? recoveryMessage;
  void refresh() {
    ref.invalidate(financeRowsProvider);
    ref.invalidate(financePendingProvider);
  }

  Future<void> recover(Map<String, dynamic> request) async {
    setState(() {
      recovering = true;
      recoveryMessage = null;
    });
    try {
      await (await ref.read(financeRepositoryProvider.future)).perform(
        request['action'] as String,
        Map<String, dynamic>.from(request['params'] as Map),
      );
      recoveryMessage = 'İşlemin sonucu alındı.';
    } on FinanceRejected {
      recoveryMessage = 'Sunucu işlemi reddetti. Güncel yetki, borç ve stok durumunu kontrol edin.';
    } catch (_) {
      recoveryMessage = 'Sonuç alınamadı. Aynı kayıtla yeniden deneyin; yeni tahsilat açmayın.';
    } finally {
      if (mounted) {
        setState(() => recovering = false);
        refresh();
      }
    }
  }

  Future<void> action(
    String title,
    String rpc,
    Map<String, dynamic> params, {
    bool money = false,
    bool positive = false,
    bool reason = false,
    bool method = false,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => FinanceDialog(
        title: title,
        money: money,
        positive: positive,
        reason: reason,
        method: method,
        send: (amount, note, selectedMethod, key) async {
          await (await ref.read(financeRepositoryProvider.future))
              .perform(rpc, {
                ...params,
                'request_key': key,
                if (money)
                  (rpc == 'record_payment' ? 'amount_kurus' : 'limit_kurus'):
                      amount,
                if (reason) 'reason': note,
                if (method) ...{
                  'payment_method': selectedMethod,
                  'payment_note': note,
                },
              });
        },
      ),
    );
    if (mounted) refresh();
  }

  String money(Object? value) =>
      value == null ? 'Hesaplanamadı' : '${formatKurus(value.toString())} TL';
  Widget row(
    Map<String, dynamic> row,
    AccountRole role,
    bool enabled,
    String selected,
  ) {
    final widgets = <Widget>[
      Text('${row['name']}', style: Theme.of(context).textTheme.titleMedium),
    ];
    if (selected == 'customers') {
      widgets.addAll([
        Text(
          'Cari limit: ${row['limit_kurus'] == null ? 'Tanımlanmamış' : money(row['limit_kurus'])}',
        ),
        Text('Exposure: ${money(row['exposure_kurus'])}'),
        TextButton(
          onPressed: enabled
              ? () => action(
                  'Cari limit belirle',
                  'set_customer_credit_limit',
                  {'target_customer': row['id']},
                  money: true,
                  reason: true,
                )
              : null,
          child: const Text('Limit belirle'),
        ),
      ]);
    } else if (selected == 'approvals') {
      widgets.addAll([
        Text('Sipariş: ${row['order_id']}'),
        Text(
          'Tutar: ${money(row['amount_kurus'])} · Limit: ${money(row['limit_kurus'])}',
        ),
        Text('Başvurudaki exposure: ${money(row['exposure_kurus'])}'),
        const Text('Onayda kayıtlı kalemlerin stoğu yeniden kontrol edilir.'),
        Wrap(
          children: [
            for (final approve in [true, false])
              TextButton(
                onPressed: enabled
                    ? () => action(
                        approve ? 'Cari aşımı onayla' : 'Cari aşımı reddet',
                        'decide_credit_approval',
                        {'target_approval': row['id'], 'approve': approve},
                        reason: true,
                      )
                    : null,
                child: Text(approve ? 'Onayla' : 'Reddet'),
              ),
          ],
        ),
      ]);
    } else {
      final balance = row['balance_kurus'];
      widgets.addAll([
        Text('Sipariş: ${row['id']}'),
        Text('Sipariş toplamı: ${money(row['amount_kurus'])}'),
        Text('Kalan borç: ${money(balance)}'),
        Text('Vade: ${row['due_date'] ?? 'Tanımlanmamış'}'),
        if (balance == null)
          const Text(
            'Teslimat veya tahsilat kayıtları inceleme gerektiriyor. İşlem kapalı.',
          ),
        if ({AccountRole.salesOperator, AccountRole.driver}.contains(role))
          TextButton(
            onPressed:
                enabled &&
                    balance != null &&
                    BigInt.parse(balance.toString()) > BigInt.zero
                ? () => action(
                    'Tahsilat kaydet',
                    'record_payment',
                    {'target_order': row['id']},
                    money: true,
                    positive: true,
                    method: true,
                  )
                : null,
            child: const Text('Tahsilat kaydet'),
          ),
        for (final p in (row['payments'] as List? ?? const [])) ...[
          const Divider(),
          Text(
            '${p['method'] == 'cash' ? 'Nakit' : 'POS'} · ${money(p['amount_kurus'])} · ${p['status'] == 'verified'
                ? 'Doğrulandı'
                : p['status'] == 'recorded'
                ? 'Doğrulama bekliyor'
                : 'İnceleme gerekli'}',
          ),
          Text('Tahsil eden: ${p['collector_id']}'),
          Text('Kayıt zamanı: ${p['collected_at']}'),
          if (role == AccountRole.accounting && p['status'] == 'recorded')
            TextButton(
              onPressed: enabled && balance != null
                  ? () => action('Tahsilatı doğrula', 'verify_payment', {
                      'target_payment': p['id'],
                    })
                  : null,
              child: const Text('Doğrula'),
            ),
        ],
      ]);
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: widgets,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Tahsilat ve cari'),
      actions: [
        IconButton(
          onPressed: recovering ? null : refresh,
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
            if (profile == null || !canUseFinance(profile.role)) {
              return const Center(
                child: Text('Bu ekrana erişim yetkiniz yok.'),
              );
            }
            final manager = {
              AccountRole.manager,
              AccountRole.owner,
            }.contains(profile.role);
            final selected = manager ? section : 'orders';
            final pending = ref.watch(financePendingProvider);
            final enabled =
                pending.hasValue && pending.value == null && !recovering;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Yalnız kesinleşmiş teslimatlarda tahsilat yapılır. Düzeltme ve iptal bu aşamada kapalıdır.',
                ),
                if (manager)
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final entry in {
                        'orders': 'Tahsilatlar',
                        'customers': 'Cari limitler',
                        'approvals': 'Cari onaylar',
                      }.entries)
                        ChoiceChip(
                          label: Text(entry.value),
                          selected: selected == entry.key,
                          onSelected: (_) =>
                              setState(() => section = entry.key),
                        ),
                    ],
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
                              'Sonucu alınmamış işlem var. Önce aynı isteği yeniden sorgulayın.',
                            ),
                            TextButton(
                              onPressed: recovering
                                  ? null
                                  : () => recover(request),
                              child: const Text('Bekleyen işlemi yeniden dene'),
                            ),
                          ],
                        ),
                ),
                if (recoveryMessage != null) Text(recoveryMessage!),
                ref
                    .watch(financeRowsProvider(selected))
                    .when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (_, _) => const Text(
                        'Kayıtlar alınamadı. Yenileyerek tekrar deneyin.',
                      ),
                      data: (rows) => rows.isEmpty
                          ? const Text('Görüntülenecek kayıt yok.')
                          : Column(
                              children: rows
                                  .map(
                                    (r) =>
                                        row(r, profile.role, enabled, selected),
                                  )
                                  .toList(),
                            ),
                    ),
              ],
            );
          },
        ),
  );
}

class FinanceDialog extends StatefulWidget {
  const FinanceDialog({
    super.key,
    required this.title,
    required this.send,
    this.money = false,
    this.positive = false,
    this.reason = false,
    this.method = false,
  });
  final String title;
  final bool money, positive, reason, method;
  final Future<void> Function(String?, String, String, String) send;
  @override
  State<FinanceDialog> createState() => _FinanceDialogState();
}

class _FinanceDialogState extends State<FinanceDialog> {
  final amount = TextEditingController(), note = TextEditingController();
  final key = newOperationKey();
  String method = 'cash';
  String? error;
  bool busy = false, uncertain = false;
  @override
  void dispose() {
    amount.dispose();
    note.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    final parsed = widget.money ? parseMoney(amount.text) : null;
    if ((widget.money &&
            (parsed == null || (widget.positive && parsed == '0'))) ||
        (widget.reason && note.text.trim().isEmpty)) {
      setState(() => error = 'Geçerli tutar ve gerekli gerekçeyi girin.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.send(parsed, note.text.trim(), method, key);
      if (mounted) Navigator.of(context).pop();
    } on FinanceRejected {
      if (mounted) {
        setState(() {
          error = 'İşlem reddedildi. Güncel yetki, borç veya stok durumunu kontrol edin.';
          uncertain = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          error = 'Sonuç alınamadı. Aynı isteği yeniden deneyin.';
          uncertain = true;
        });
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
          if (widget.money)
            TextField(
              controller: amount,
              readOnly: busy || uncertain,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Tutar (TL)'),
            ),
          if (widget.method)
            DropdownButtonFormField<String>(
              initialValue: method,
              decoration: const InputDecoration(labelText: 'Yöntem'),
              items: const [
                DropdownMenuItem(value: 'cash', child: Text('Nakit')),
                DropdownMenuItem(value: 'pos', child: Text('POS')),
              ],
              onChanged: busy || uncertain
                  ? null
                  : (value) => setState(() => method = value!),
            ),
          if (widget.method || widget.reason)
            TextField(
              controller: note,
              readOnly: busy || uncertain,
              decoration: InputDecoration(
                labelText: widget.reason ? 'Gerekçe (zorunlu)' : 'Not',
              ),
            ),
          if (!widget.money && !widget.reason)
            const Text('Bu tahsilatı doğruladığınız kaydedilecek.'),
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
                : uncertain
                ? 'Aynı isteği yeniden dene'
                : 'Kaydet',
          ),
        ),
      ],
    ),
  );
}
