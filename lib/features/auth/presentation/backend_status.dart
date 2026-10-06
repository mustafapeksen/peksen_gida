import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/auth_repository.dart';
import 'auth_providers.dart';

/// Development-only status. Client initialization is not a connectivity check.
class BackendStatus extends ConsumerWidget {
  const BackendStatus({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authSessionProvider);
    final message = session.when(
      loading: () => 'Bağlantı hazırlanıyor…',
      error: (_, _) =>
          'Bağlantı hazırlığı tamamlanamadı. Önizleme kullanılabilir.',
      data: (value) => switch (value.status) {
        AuthSessionStatus.unavailable =>
          'Backend yapılandırılmadı. Önizleme kullanılabilir.',
        AuthSessionStatus.signedOut =>
          'İstemci hazır; sunucu bağlantısı doğrulanmadı. Giriş yapılabilir.',
        AuthSessionStatus.signedIn =>
          'Oturum bilgisi alındı; hesap erişimi veritabanından denetlenir.',
      },
    );
    return Text(
      message,
      key: const ValueKey('backend-status'),
      style: Theme.of(context).textTheme.bodySmall,
    );
  }
}
