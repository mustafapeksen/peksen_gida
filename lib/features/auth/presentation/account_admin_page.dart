import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/account_repository.dart';
import '../domain/account_lifecycle.dart';
import 'auth_providers.dart';

class AccountAdminPage extends ConsumerStatefulWidget {
  const AccountAdminPage({super.key});
  @override
  ConsumerState<AccountAdminPage> createState() => _AccountAdminPageState();
}

class _AccountAdminPageState extends ConsumerState<AccountAdminPage> {
  final _name = TextEditingController(),
      _email = TextEditingController(),
      _customer = TextEditingController();
  AccountRole _role = AccountRole.driver;
  bool _busy = false;
  String? _message;
  List<Map<String, dynamic>> _accounts = [], _invitations = [];
  Future<void> _run(Future<void> Function(AccountLifecycle) action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final service = await ref.read(accountLifecycleProvider.future);
      if (service == null) throw const AccountLifecycleException();
      await action(service);
      final accounts = await service.accounts(),
          invitations = await service.invitations();
      if (mounted) {
        setState(() {
          _accounts = accounts;
          _invitations = invitations;
          _message = 'İşlem tamamlandı.';
        });
      }
      ref.invalidate(accountProfileProvider);
    } catch (_) {
      if (mounted) {
        setState(() => _message = const AccountLifecycleException().toString());
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _customer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(accountProfileProvider).asData?.value;
    final owner = profile?.role == AccountRole.owner;
    if (!owner && profile?.role != AccountRole.manager) {
      return const Scaffold(
        body: SafeArea(
          child: Center(child: Text('Hesap yönetimi yetkiniz yok.')),
        ),
      );
    }
    final roles = AccountRole.values
        .where(
          (r) =>
              owner ||
              [
                AccountRole.customer,
                AccountRole.salesOperator,
                AccountRole.warehouse,
                AccountRole.driver,
              ].contains(r),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Hesap yönetimi')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'Davet edilen kişi e-posta kodunu doğrular ve kendi parolasını belirler.',
            ),
            TextField(
              key: const ValueKey('invite-name'),
              controller: _name,
              enabled: !_busy,
              decoration: const InputDecoration(labelText: 'Ad soyad'),
            ),
            TextField(
              key: const ValueKey('invite-email'),
              controller: _email,
              enabled: !_busy,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'E-posta'),
            ),
            DropdownButtonFormField<AccountRole>(
              key: const ValueKey('invite-role'),
              initialValue: roles.contains(_role) ? _role : AccountRole.driver,
              items: [
                for (final r in roles)
                  DropdownMenuItem(value: r, child: Text(r.label)),
              ],
              onChanged: _busy
                  ? null
                  : (value) => setState(() => _role = value!),
              decoration: const InputDecoration(labelText: 'Davet rolü'),
            ),
            if (_role == AccountRole.customer)
              TextField(
                controller: _customer,
                enabled: !_busy,
                decoration: const InputDecoration(
                  labelText: 'Boş müşteri kuruluşu kimliği',
                ),
              ),
            const SizedBox(height: 16),
            FilledButton(
              key: const ValueKey('invite-send'),
              onPressed: _busy
                  ? null
                  : () => _run((s) async {
                      await s.invite(
                        _name.text,
                        _email.text,
                        _role,
                        _role == AccountRole.customer
                            ? _customer.text.trim()
                            : null,
                      );
                    }),
              child: const Text('E-posta daveti gönder'),
            ),
            OutlinedButton(
              onPressed: _busy ? null : () => _run((_) async {}),
              child: const Text('Hesapları ve davetleri yenile'),
            ),
            if (_message != null) Text(_message!),
            if (_busy) const LinearProgressIndicator(),
            for (final i in _invitations)
              ListTile(
                title: Text('${i['name']} · ${i['email']}'),
                subtitle: Text(
                  '${i['role']} · ${i['revoked'] == true
                      ? 'İptal'
                      : i['accepted_at'] != null
                      ? 'Kabul edildi'
                      : 'Bekliyor'}',
                ),
                trailing: i['revoked'] == false && i['accepted_at'] == null
                    ? IconButton(
                        tooltip: 'Daveti iptal et',
                        onPressed: _busy
                            ? null
                            : () => _run(
                                (s) => s.revokeInvitation(i['id'] as String),
                              ),
                        icon: const Icon(Icons.cancel_outlined),
                      )
                    : null,
              ),
            if (owner)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Pasifleştirme kayıtları silmez. Açık işi olan çalışan ve son aktif işletme sahibi korunur.',
                ),
              ),
            for (final a in _accounts)
              ListTile(
                title: Text(a['name'] as String),
                subtitle: Text(
                  '${a['role']} · ${a['active'] == true ? 'Aktif' : 'Pasif'}',
                ),
                trailing: owner
                    ? TextButton(
                        onPressed: _busy
                            ? null
                            : () async {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: Text(
                                      a['active'] == true
                                          ? 'Hesap pasifleştirilsin mi?'
                                          : 'Hesap yeniden açılsın mı?',
                                    ),
                                    content: Text(a['name'] as String),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: const Text('Vazgeç'),
                                      ),
                                      FilledButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        child: const Text('Onayla'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirmed == true && mounted) {
                                  await _run(
                                    (s) => s.setActive(
                                      a['id'] as String,
                                      a['active'] != true,
                                    ),
                                  );
                                }
                              },
                        child: Text(
                          a['active'] == true ? 'Pasifleştir' : 'Yeniden aç',
                        ),
                      )
                    : null,
              ),
          ],
        ),
      ),
    );
  }
}
