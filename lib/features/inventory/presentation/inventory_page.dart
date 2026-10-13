import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/domain/account_repository.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../products/presentation/price_page.dart' show newOperationKey;
import '../data/inventory_repository.dart';

bool canUseInventory(AccountRole role) => const {
  AccountRole.warehouse,
  AccountRole.manager,
  AccountRole.owner,
}.contains(role);

final inventoryRowsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>(retry: (_, _) => null, (
      ref,
      section,
    ) async {
      final profile = await ref.watch(accountProfileProvider.future);
      if (profile == null || !canUseInventory(profile.role)) {
        throw const AccountAccessException();
      }
      return (await ref.watch(inventoryRepositoryProvider.future))
          .read(section);
    });

String inventoryLabel(String value) =>
    const {
      'submitted': 'Gönderildi',
      'picking': 'Toplanıyor',
      'picked': 'Toplandı',
      'pending': 'Onay bekliyor',
      'approved': 'Onaylandı',
      'rejected': 'Reddedildi',
      'received': 'Mal kabulü',
      'reserved': 'Rezervasyon',
      'released': 'Rezervasyon çözümü',
      'returned': 'Depoya dönüş',
      'count_adjustment': 'Sayım farkı',
      'compensation': 'Telafi',
    }[value] ??
    value;

class InventoryPage extends ConsumerStatefulWidget {
  const InventoryPage({super.key, this.orderId});
  final String? orderId;
  @override
  ConsumerState<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends ConsumerState<InventoryPage> {
  static const sections = ['stock', 'preparation', 'counts', 'movements'];
  int index = 0;
  @override
  void initState() {
    super.initState();
    if (widget.orderId != null) index = 1;
  }

  @override
  void didUpdateWidget(covariant InventoryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.orderId != widget.orderId && widget.orderId != null) {
      index = 1;
    }
  }

  Future<void> action({
    required String title,
    required String message,
    required Future<void> Function(
      InventoryRepository,
      String,
      String,
      String,
      String?,
    )
    send,
    bool quantity = false,
    bool integer = false,
    bool allowZero = false,
    List<Map<String, dynamic>> units = const [],
    bool note = false,
  }) async {
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => InventoryActionDialog(
        title: title,
        message: message,
        quantity: quantity,
        integer: integer,
        allowZero: allowZero,
        units: units,
        note: note,
        send: (amount, text, key, unit) async {
          final repo = await ref.read(inventoryRepositoryProvider.future);
          await send(repo, amount, text, key, unit);
        },
      ),
    );
    if (mounted) ref.invalidate(inventoryRowsProvider);
  }

  Widget card(Map<String, dynamic> row, AccountRole role) {
    final children = <Widget>[];
    switch (sections[index]) {
      case 'stock':
        children.addAll([
          Text(
            '${row['name']}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text('Fiziksel: ${row['physical']} ${row['unit']}'),
          Text(
            'Rezerve: ${row['reserved']} · Kullanılabilir: ${row['available']}',
          ),
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                onPressed: () => action(
                  title: 'Mal kabulü',
                  message: 'Seçilen birimde miktar girin. Dönüşüm sunucuda yuvarlamadan uygulanır.',
                  quantity: true,
                  note: true,
                  units: (row['units'] as List)
                      .map((u) => Map<String, dynamic>.from(u as Map))
                      .toList(),
                  send: (repo, qty, note, key, unit) =>
                      repo.receive(unit!, qty, note, key),
                ),
                child: const Text('Mal kabulü'),
              ),
              if (role == AccountRole.warehouse)
                TextButton(
                  onPressed: () => action(
                    title: 'Sayım gönder',
                    message:
                        'Gerçek fiziksel miktarı ${row['unit']} olarak girin. Stok ancak yönetici onayıyla değişir.',
                    quantity: true,
                    allowZero: true,
                    note: true,
                    send: (repo, qty, note, key, _) =>
                        repo.count(row['id'] as String, qty, note, key),
                  ),
                  child: const Text('Sayım gönder'),
                ),
            ],
          ),
        ]);
      case 'preparation':
        children.addAll([
          SelectableText('Sipariş: ${row['order_id']}'),
          Text(inventoryLabel(row['status'] as String)),
          for (final item in (row['items'] as List? ?? [])) ...[
            Text(
              '${item['name']} · ${item['picked']} / ${item['quantity']} ${item['unit']}',
            ),
            if (row['status'] == 'picking' &&
                (item['picked'] as int) < (item['quantity'] as int))
              TextButton(
                onPressed: () => action(
                  title: 'Kalem topla',
                  message:
                      '${item['name']}: şimdi topladığınız ilave tam ${item['unit']} miktarını girin.',
                  quantity: true,
                  integer: true,
                  send: (repo, qty, _, key, _) => repo.orderAction(
                    row['order_id'] as String,
                    'pick',
                    item['id'] as String,
                    int.parse(qty),
                    key,
                  ),
                ),
                child: const Text('Kalem topla'),
              ),
          ],
          if (row['status'] == 'submitted')
            TextButton(
              onPressed: () => action(
                title: 'Toplamayı başlat',
                message: 'Sipariş toplama aşamasına geçecek. Fiyat ve rezervasyon değişmez.',
                send: (repo, _, _, key, _) => repo.orderAction(
                  row['order_id'] as String,
                  'start',
                  null,
                  null,
                  key,
                ),
              ),
              child: const Text('Toplamayı başlat'),
            ),
          if (row['status'] == 'picked')
            TextButton(
              onPressed: () => action(
                title: 'Yüklemeyi tamamla',
                message: 'Fiziksel yüklemeyi doğrulayın. Aktif sefer/durak ataması zorunludur; stok ikinci kez düşmez.',
                send: (repo, _, _, key, _) => repo.orderAction(
                  row['order_id'] as String,
                  'load',
                  null,
                  null,
                  key,
                ),
              ),
              child: const Text('Yüklemeyi tamamla'),
            ),
        ]);
      case 'counts':
        children.addAll([
          Text('Sayım: ${row['id']}'),
          Text(inventoryLabel(row['status'] as String)),
          for (final item in (row['items'] as List? ?? []))
            Text(
              '${item['name']}: sistem ${item['system']}, sayılan ${item['counted']}, fark ${item['difference']} ${item['unit']}',
            ),
          if (row['status'] == 'pending' && role != AccountRole.warehouse)
            TextButton(
              onPressed: () => action(
                title: 'Sayımı onayla',
                message: 'Stok değiştiyse yeniden sayım gerekir. Sayılan miktar rezervasyonun altında olamaz.',
                send: (repo, _, _, key, _) =>
                    repo.approveCount(row['id'] as String, key),
              ),
              child: const Text('Sayımı onayla'),
            ),
        ]);
      case 'movements':
        children.addAll([
          Text('${row['name']} · ${inventoryLabel(row['type'] as String)}'),
          Text('${row['quantity']} ${row['unit']}'),
          Text(
            'Fiziksel fark: ${row['physical_delta']} · Rezerve fark: ${row['reserved_delta']}',
          ),
          Text('${row['created_at']}'),
        ]);
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Depo ve stok'),
      actions: [
        IconButton(
          tooltip: 'Yenile',
          onPressed: () => ref.invalidate(inventoryRowsProvider),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: index,
      onDestinationSelected: (value) => setState(() => index = value),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.inventory_2_outlined),
          label: 'Stok',
        ),
        NavigationDestination(icon: Icon(Icons.checklist), label: 'Toplama'),
        NavigationDestination(
          icon: Icon(Icons.fact_check_outlined),
          label: 'Sayım',
        ),
        NavigationDestination(icon: Icon(Icons.history), label: 'Hareket'),
      ],
    ),
    body: SafeArea(
      child: ref
          .watch(accountProfileProvider)
          .when(
            skipLoadingOnRefresh: false,
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) =>
                const Center(child: Text('Hesap erişimi doğrulanamadı.')),
            data: (profile) {
              if (profile == null || !canUseInventory(profile.role)) {
                return const Center(
                  child: Text('Bu ekrana erişim yetkiniz yok.'),
                );
              }
              return ref
                  .watch(inventoryRowsProvider(sections[index]))
                  .when(
                    skipLoadingOnRefresh: false,
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (_, _) => Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Depo kayıtları yüklenemedi.'),
                          TextButton(
                            onPressed: () =>
                                ref.invalidate(inventoryRowsProvider),
                            child: const Text('Yeniden dene'),
                          ),
                        ],
                      ),
                    ),
                    data: (rows) => ListView(
                      padding: const EdgeInsets.all(12),
                      children: [
                        if (rows.isEmpty) const Text('Henüz kayıt yok.'),
                        if (index == 1 &&
                            widget.orderId != null &&
                            !rows.any((r) => r['order_id'] == widget.orderId))
                          const Text(
                            'Sipariş hazırlık kapsamında değil veya erişiminiz sona erdi.',
                          ),
                        for (final row in rows.where(
                          (r) =>
                              index != 1 ||
                              widget.orderId == null ||
                              r['order_id'] == widget.orderId,
                        ))
                          card(row, profile.role),
                      ],
                    ),
                  );
            },
          ),
    ),
  );
}

/// Quantities stay decimal strings throughout the client, never double.
String? inventoryQuantity(
  String value, {
  bool integer = false,
  bool allowZero = false,
}) {
  final normalized = value.trim().replaceAll(',', '.');
  if (!RegExp(integer ? r'^\d+$' : r'^\d+(\.\d+)?$').hasMatch(normalized)) {
    return null;
  }
  if (!allowZero && !RegExp(r'[1-9]').hasMatch(normalized)) return null;
  if (integer && (BigInt.parse(normalized) > BigInt.from(2147483647))) {
    return null;
  }
  return normalized;
}

class InventoryActionDialog extends StatefulWidget {
  const InventoryActionDialog({
    super.key,
    required this.title,
    required this.message,
    required this.send,
    this.quantity = false,
    this.integer = false,
    this.allowZero = false,
    this.note = false,
    this.units = const [],
  });
  final String title, message;
  final bool quantity, integer, allowZero, note;
  final List<Map<String, dynamic>> units;
  final Future<void> Function(String, String, String, String?) send;
  @override
  State<InventoryActionDialog> createState() => _InventoryActionDialogState();
}

class _InventoryActionDialogState extends State<InventoryActionDialog> {
  final amount = TextEditingController(), note = TextEditingController();
  final key = newOperationKey();
  String? unit, error;
  bool busy = false, sent = false;
  @override
  void initState() {
    super.initState();
    unit = widget.units.isEmpty ? null : widget.units.first['id'] as String;
  }

  @override
  void dispose() {
    amount.dispose();
    note.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    final qty = widget.quantity
        ? inventoryQuantity(
            amount.text,
            integer: widget.integer,
            allowZero: widget.allowZero,
          )
        : '';
    if (qty == null || (widget.title == 'Mal kabulü' && unit == null)) {
      setState(() => error = 'Geçerli miktar ve birim girin.');
      return;
    }
    setState(() {
      busy = true;
      sent = true;
      error = null;
    });
    try {
      await widget.send(qty, note.text.trim(), key, unit);
      if (mounted) Navigator.of(context).pop(true);
    } on PostgrestException catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          error = e.code == '40001'
              ? 'Stok değişti. Kapatıp yeniden sayım yapın.'
              : 'İşlem reddedildi. Yetki, sipariş durumu, kalan miktar ve sefer atamasını kontrol edip listeyi yenileyin.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          busy = false;
          error = 'Sonuç doğrulanamadı. Aynı isteği yeniden deneyin; yeni işlem başlatmayın.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: AlertDialog(
      scrollable: true,
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.message),
          if (widget.units.isNotEmpty)
            DropdownButtonFormField<String>(
              initialValue: unit,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Birim'),
              items: widget.units
                  .map(
                    (u) => DropdownMenuItem(
                      value: u['id'] as String,
                      child: Text('${u['name']} (×${u['conversion']})'),
                    ),
                  )
                  .toList(),
              onChanged: sent ? null : (value) => setState(() => unit = value),
            ),
          if (widget.quantity)
            TextField(
              controller: amount,
              readOnly: sent,
              keyboardType: TextInputType.numberWithOptions(
                decimal: !widget.integer,
              ),
              decoration: const InputDecoration(labelText: 'Miktar'),
            ),
          if (widget.note)
            TextField(
              controller: note,
              readOnly: sent,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Evrak / sayım notu',
              ),
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
                : sent
                ? 'Aynı isteği yeniden dene'
                : 'Onayla',
          ),
        ),
      ],
    ),
  );
}
