import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/login_page.dart';
import '../../features/auth/presentation/account_page.dart';
import '../../features/auth/presentation/auth_providers.dart';
import '../../features/auth/domain/auth_repository.dart';
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
      if (state.uri.path == '/account' && !signedIn) return '/';
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
