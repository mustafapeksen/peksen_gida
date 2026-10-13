import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/notifications/push_service.dart';
import 'features/auth/presentation/auth_providers.dart';
import 'features/tracking/presentation/tracking_providers.dart';

class PeksenGidaApp extends ConsumerWidget {
  const PeksenGidaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Start once in the app scope, without blocking the offline preview.
    ref.watch(authSessionProvider);
    ref.watch(pushServiceProvider);
    // Keep the publisher's auth dependency active even after leaving the map.
    // Signing out disposes it and stops the native service immediately.
    ref.watch(trackingPublisherProvider);
    return MaterialApp.router(
      title: 'Pekşen Gıda',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      locale: const Locale('tr', 'TR'),
      supportedLocales: const [Locale('tr', 'TR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
