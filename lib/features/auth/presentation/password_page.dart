import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/account_lifecycle.dart';
import 'auth_providers.dart';

class PasswordPage extends ConsumerStatefulWidget {
  const PasswordPage({super.key});
  @override
  ConsumerState<PasswordPage> createState() => _PasswordPageState();
}

class _PasswordPageState extends ConsumerState<PasswordPage> {
  final _old = TextEditingController(), _new = TextEditingController();
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _old.dispose();
    _new.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (_old.text.isEmpty || !validNewPassword(_new.text)) {
      setState(
        () => _error = _old.text.isEmpty
            ? 'Mevcut parolayı girin.'
            : newPasswordError(_new.text),
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final service = await ref.read(accountLifecycleProvider.future);
      if (service == null) throw const AccountLifecycleException();
      await service.changePassword(_old.text, _new.text);
      if (mounted) context.go('/');
    } catch (_) {
      if (mounted) {
        setState(() => _error = const AccountLifecycleException().toString());
      }
    } finally {
      if (mounted) {
        _old.clear();
        _new.clear();
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Parola değiştir')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Parola değiştikten sonra tüm oturumlarınızdan çıkış yapılır.',
          ),
          TextField(
            controller: _old,
            enabled: !_busy,
            obscureText: true,
            enableSuggestions: false,
            autocorrect: false,
            decoration: const InputDecoration(labelText: 'Mevcut parola'),
          ),
          TextField(
            controller: _new,
            enabled: !_busy,
            obscureText: true,
            enableSuggestions: false,
            autocorrect: false,
            decoration: const InputDecoration(labelText: 'Yeni parola'),
          ),
          if (_error != null) Text(_error!),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: Text(_busy ? 'İşleniyor…' : 'Parolayı değiştir'),
          ),
        ],
      ),
    ),
  );
}
