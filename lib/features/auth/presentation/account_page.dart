import '../../finance/presentation/finance_page.dart' show canUseFinance;
import '../../delivery/presentation/dispatch_page.dart' show canUseDispatch;
import '../../delivery/presentation/delivery_page.dart' show canUseDelivery;
import '../../tracking/presentation/tracking_providers.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/account_repository.dart';
import 'auth_providers.dart';
import '../../../core/notifications/push_service.dart';
import '../../products/presentation/product_providers.dart';
import '../../inventory/presentation/inventory_page.dart' show canUseInventory;

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
      // A push failure must not prevent logout. Server jobs also verify the
      // live Auth session, and push clicks verify the current recipient.
      try {
        await ref
            .read(pushServiceProvider)
            .asData
            ?.value
            ?.disconnect()
            .timeout(const Duration(seconds: 5));
      } catch (_) {}
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
                        Text(_roleDescription(value.role)),
                        const SizedBox(height: 20),
                        Text(
                          'İş ekranları',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        if (canUseTracking(value.role))
                          _AccountAction(
                            title: 'Canlı teslimat konumu',
                            icon: Icons.location_on_outlined,
                            route: '/account/tracking',
                            description: 'Aktif teslimatı izleyin; primary sürücü konum paylaşabilir.',
                          ),
                        if (canUseDispatch(value.role))
                          _AccountAction(
                            title: 'Araç ve seferler',
                            icon: Icons.local_shipping_outlined,
                            route: '/account/dispatch',
                            description: 'Sefer, ekip ve durak bilgilerini görüntüleyin.',
                          ),
                        if (canUseDelivery(value.role))
                          _AccountAction(
                            title: 'Teslimat ve puanlama',
                            icon: Icons.task_alt,
                            route: '/account/deliveries',
                            description: 'Teslimat onayı, uyuşmazlık ve puanlama işlemleri.',
                          ),
                        if (canReadProducts(value.role))
                          _AccountAction(
                            title: 'Ürünler ve birimler',
                            icon: Icons.inventory_2_outlined,
                            route: '/account/products',
                          ),
                        if (canUseFinance(value.role))
                          _AccountAction(
                            title: 'Tahsilat ve cari',
                            icon: Icons.receipt_long_outlined,
                            route: '/account/finance',
                          ),
                        if (canUseInventory(value.role))
                          _AccountAction(
                            title: 'Depo ve stok',
                            icon: Icons.warehouse_outlined,
                            route: '/account/inventory',
                          ),
                        if (value.role == AccountRole.salesOperator)
                          _AccountAction(
                            title: 'Müşteri adına sipariş',
                            icon: Icons.shopping_bag_outlined,
                            route: '/account/sales',
                          ),
                        if (value.role == AccountRole.customer)
                          _AccountAction(
                            title: 'Katalog ve sepet',
                            icon: Icons.shopping_cart_outlined,
                            route: '/account/shop',
                          ),
                        if (value.role == AccountRole.owner ||
                            value.role == AccountRole.manager)
                          _AccountAction(
                            title: 'Sipariş talepleri',
                            icon: Icons.assignment_outlined,
                            route: '/account/order-requests',
                          ),
                        if (value.role == AccountRole.owner ||
                            value.role == AccountRole.manager)
                          _AccountAction(
                            title: 'Hesap yönetimi',
                            icon: Icons.manage_accounts_outlined,
                            route: '/account/admin',
                          ),
                        if (value.role == AccountRole.owner ||
                            value.role == AccountRole.manager)
                          _AccountAction(
                            title: 'Operasyon raporları',
                            icon: Icons.bar_chart,
                            route: '/account/reports',
                          ),
                        if (value.role == AccountRole.owner) ...[
                          _AccountAction(
                            title: 'Maaş ve prim',
                            icon: Icons.badge_outlined,
                            route: '/account/salary',
                          ),
                          _AccountAction(
                            title: 'Audit kayıtları',
                            icon: Icons.history,
                            route: '/account/audit',
                          ),
                        ],
                        _AccountAction(
                          title: 'Bildirimler',
                          icon: Icons.notifications_outlined,
                          route: '/account/notifications',
                        ),
                        _AccountAction(
                          title: 'Parola değiştir',
                          icon: Icons.lock_outline,
                          route: '/account/password',
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

String _roleDescription(AccountRole role) => switch (role) {
  AccountRole.driver => 'Atandığınız seferleri ve durakları takip edin. Aktif primary seferinizde konum paylaşımını siz başlatırsınız.',
  AccountRole.customer => 'Kataloğa göz atın, sepetinizi hazırlayın ve aktif teslimatınızı takip edin.',
  AccountRole.salesOperator => 'Yalnız aktif olarak atandığınız müşteriler adına sipariş ve tahsilat işlemlerini yürütün.',
  AccountRole.warehouse =>
    'Ürün, stok, toplama ve yükleme işlerinize buradan ulaşın.',
  AccountRole.accounting => 'Atanmış müşterilerinizin cari bilgilerini ve doğrulanacak tahsilatlarını inceleyin.',
  AccountRole.manager => 'Ürün, sipariş, depo, tahsilat ve sefer işlerini yetkileriniz kapsamında yönetin.',
  AccountRole.owner =>
    'Operasyonları ve hesapları yönetin; aktif teslimatları takip edin.',
};

class _AccountAction extends StatelessWidget {
  const _AccountAction({
    required this.title,
    required this.icon,
    required this.route,
    this.description,
  });
  final String title;
  final String? description;
  final IconData icon;
  final String route;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    clipBehavior: Clip.antiAlias,
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Icon(icon),
      title: Text(title),
      subtitle: description == null ? null : Text(description!),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push(route),
    ),
  );
}
