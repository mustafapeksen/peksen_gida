import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/account_repository.dart';
import 'auth_providers.dart';
import '../../products/presentation/product_providers.dart';

class AccountPage extends ConsumerStatefulWidget {
  const AccountPage({super.key});
  @override
  ConsumerState<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends ConsumerState<AccountPage>
    with WidgetsBindingObserver {
  bool _signingOut = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(accountProfileProvider);
    }
  }

  Future<void> _signOut() async {
    setState(() {
      _signingOut = true;
      _error = null;
    });
    try {
      final repository = await ref.read(accountRepositoryProvider.future);
      await repository?.signOut();
      ref.invalidate(accountProfileProvider);
      if (mounted) context.go('/');
    } catch (_) {
      if (mounted) setState(() => _error = const SignOutException().toString());
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(accountProfileProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Hesabım')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            profile.when(
              skipLoadingOnRefresh: false,
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => Text(
                const AccountAccessException().toString(),
                key: const ValueKey('account-denied'),
              ),
              data: (value) => value == null
                  ? const Text('Oturum açmanız gerekiyor.')
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          value.name,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Rolünüz: ${value.role.label}',
                          key: const ValueKey('account-role'),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Oturum açıldı. İş ekranları sonraki geliştirme fazlarında bağlanacak.',
                        ),
                        if (canReadProducts(value.role))
                          TextButton(
                            onPressed: () => context.push('/account/products'),
                            child: const Text('Ürünler ve birimler'),
                          ),
                        if (value.role == AccountRole.customer)
                          TextButton(
                            onPressed: () => context.push('/account/shop'),
                            child: const Text('Katalog ve sepet'),
                          ),
                        TextButton(
                          onPressed: () => context.push('/account/password'),
                          child: const Text('Parola değiştir'),
                        ),
                        if (value.role == AccountRole.owner ||
                            value.role == AccountRole.manager)
                          TextButton(
                            onPressed: () => context.push('/account/admin'),
                            child: const Text('Hesap yönetimi'),
                          ),
                      ],
                    ),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => ref.invalidate(accountProfileProvider),
              child: const Text('Hesap erişimini yenile'),
            ),
            if (_error != null) Text(_error!),
            FilledButton(
              key: const ValueKey('account-sign-out'),
              onPressed: _signingOut ? null : _signOut,
              child: Text(_signingOut ? 'Çıkış yapılıyor…' : 'Çıkış yap'),
            ),
          ],
        ),
      ),
    );
  }
}
