import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/login_page.dart';
import '../../features/auth/presentation/account_page.dart';
import '../../features/auth/presentation/auth_providers.dart';
import '../../features/auth/domain/auth_repository.dart';
import '../../features/auth/domain/account_lifecycle.dart';
import '../../features/auth/presentation/onboarding_page.dart';
import '../../features/auth/presentation/account_admin_page.dart';
import '../../features/auth/presentation/password_page.dart';
import '../../features/products/presentation/products_page.dart';
import '../../features/products/presentation/price_page.dart';
import '../../features/products/presentation/create_product_page.dart';
import '../../features/products/presentation/quote_page.dart';
import '../../features/customer/presentation/catalog_page.dart';
import '../../features/customer/presentation/product_detail_page.dart';
import '../../features/customer/presentation/cart_page.dart';
import '../../features/customer/presentation/orders_page.dart';
import '../../features/preview/domain/role_menu.dart';
import '../../features/preview/presentation/preview_page.dart';
import '../../features/preview/presentation/role_menu_page.dart';
import '../../features/preview/presentation/screen_placeholder_page.dart';
import '../../shared/widgets/state_page.dart';
import '../config/preview_config.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(authSessionProvider, (_, _) => refresh.value++);
  final router = createAppRouter(
    previewEnabled: ref.watch(developmentPreviewEnabledProvider),
    refreshListenable: refresh,
    isSignedIn: () =>
        ref.read(authSessionProvider).asData?.value.status ==
        AuthSessionStatus.signedIn,
  );
  ref.onDispose(router.dispose);
  ref.onDispose(refresh.dispose);
  return router;
});

GoRouter createAppRouter({
  required bool previewEnabled,
  String initialLocation = '/',
  Listenable? refreshListenable,
  bool Function()? isSignedIn,
}) {
  // Enforced here, as well as hiding the entry point. Never a backend role gate.
  final allowPreview = kDebugMode && previewEnabled;
  return GoRouter(
    initialLocation: initialLocation,
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      final signedIn = isSignedIn?.call() ?? false;
      if ((state.uri.path == '/account' ||
              state.uri.path.startsWith('/account/')) &&
          !signedIn) {
        return '/';
      }
      if (state.uri.path == '/' && signedIn) return '/account';
      if (!allowPreview &&
          (state.uri.path == '/preview' ||
              state.uri.path.startsWith('/preview/'))) {
        return '/';
      }
      return null;
    },
    // Keep unknown URLs on a real route. go_router 18.0.2's errorBuilder
    // leaves an empty match list, which crashes its Android back handler.
    onException: (context, state, router) => router.go('/not-found'),
    routes: [
      GoRoute(
        path: '/account',
        builder: (context, state) => const AccountPage(),
        routes: [
          GoRoute(
            path: 'shop',
            builder: (context, state) => const CatalogPage(),
            routes: [
              GoRoute(
                path: 'orders',
                builder: (context, state) => const CustomerOrdersPage(),
              ),
              GoRoute(
                path: 'product/:id',
                builder: (context, state) =>
                    ProductDetailPage(productId: state.pathParameters['id']!),
              ),
              GoRoute(
                path: 'cart',
                builder: (context, state) => const CartPage(),
              ),
            ],
          ),
          GoRoute(
            path: 'products',
            builder: (context, state) => const ProductsPage(),
            routes: [
              GoRoute(
                path: ':productId/quote',
                builder: (context, state) =>
                    QuotePage(productId: state.pathParameters['productId']!),
              ),
              GoRoute(
                path: 'new',
                builder: (context, state) => const CreateProductPage(),
              ),
              GoRoute(
                path: ':productId/price',
                builder: (context, state) =>
                    PricePage(productId: state.pathParameters['productId']!),
              ),
            ],
          ),
          GoRoute(
            path: 'admin',
            builder: (context, state) => const AccountAdminPage(),
          ),
          GoRoute(
            path: 'password',
            builder: (context, state) => const PasswordPage(),
          ),
        ],
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) =>
            const OnboardingPage(purpose: EmailCodePurpose.signup),
      ),
      GoRoute(
        path: '/accept-invite',
        builder: (context, state) =>
            const OnboardingPage(purpose: EmailCodePurpose.invite),
      ),
      GoRoute(
        path: '/recover',
        builder: (context, state) =>
            const OnboardingPage(purpose: EmailCodePurpose.recovery),
      ),
      GoRoute(path: '/login', redirect: (context, state) => '/'),
      GoRoute(
        path: '/not-found',
        builder: (context, state) => const NotFoundPage(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => LoginPage(previewEnabled: allowPreview),
        routes: [
          if (allowPreview)
            GoRoute(
              path: 'preview',
              builder: (context, state) => const PreviewPage(),
              routes: [
                GoRoute(
                  path: 'states/:kind',
                  builder: (context, state) {
                    final kind = switch (state.pathParameters['kind']) {
                      'loading' => PreviewState.loading,
                      'empty' => PreviewState.empty,
                      'error' => PreviewState.error,
                      _ => null,
                    };
                    return kind == null
                        ? const NotFoundPage()
                        : StatePage(state: kind);
                  },
                ),
                GoRoute(
                  path: 'roles/:roleId',
                  builder: (context, state) {
                    final role = AppRole.fromId(
                      state.pathParameters['roleId']!,
                    );
                    return role == null
                        ? const NotFoundPage()
                        : RoleMenuPage(role: role);
                  },
                  routes: [
                    GoRoute(
                      path: ':screenId',
                      builder: (context, state) {
                        final role = AppRole.fromId(
                          state.pathParameters['roleId']!,
                        );
                        final entries = roleMenus[role];
                        final destination = entries
                            ?.where(
                              (entry) =>
                                  entry.id == state.pathParameters['screenId'],
                            )
                            .firstOrNull;
                        if (role == null || destination == null) {
                          return const NotFoundPage();
                        }
                        return ScreenPlaceholderPage(
                          role: role,
                          destination: destination,
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
        ],
      ),
    ],
  );
}
