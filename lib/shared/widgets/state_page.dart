import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'app_back_button.dart';
import 'preview_notice.dart';

enum PreviewState { loading, empty, error }

class StatePage extends StatelessWidget {
  const StatePage({super.key, required this.state});

  final PreviewState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (title, message, icon) = switch (state) {
      PreviewState.loading => (
        'Yükleniyor',
        'Yükleniyor görünümünün örneği. Sunucuya istek gönderilmiyor; '
            'bu örnek kendiliğinden tamamlanmaz. Geri dönebilirsiniz.',
        Icons.hourglass_top_rounded,
      ),
      PreviewState.empty => (
        'Henüz kayıt yok',
        'Boş liste görünümünün örneği. Bu ekranda gerçek bir liste '
            'sorgulanmıyor veya kayıt oluşturulmuyor.',
        Icons.inventory_2_outlined,
      ),
      PreviewState.error => (
        'Bir sorun oluştu',
        'Hata görünümünün örneği. Gerçek bir işlem başarısız olmadı; '
            'otomatik yeniden deneme yapılmıyor.',
        Icons.cloud_off_outlined,
      ),
    };

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallbackLocation: '/preview'),
        title: const Text('Ekran durumları', overflow: TextOverflow.ellipsis),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const PreviewNotice(),
                  const SizedBox(height: 24),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Align(
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surface,
                                shape: BoxShape.circle,
                              ),
                              child: state == PreviewState.loading
                                  ? const SizedBox.square(
                                      dimension: 36,
                                      child: CircularProgressIndicator(
                                        semanticsLabel: 'Yükleniyor örneği',
                                      ),
                                    )
                                  : Icon(
                                      icon,
                                      size: 36,
                                      color: theme.colorScheme.primary,
                                    ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            title,
                            key: ValueKey('state-${state.name}-title'),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            message,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 24),
                          if (state == PreviewState.error) ...[
                            FilledButton(
                              onPressed: () {
                                context.go('/preview/states/empty');
                              },
                              child: const Text(
                                'Boş liste örneğine git',
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          OutlinedButton(
                            onPressed: () => context.go('/preview'),
                            child: const Text(
                              'Önizlemeye dön',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class NotFoundPage extends StatelessWidget {
  const NotFoundPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          context.go('/');
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: const AppBackButton(fallbackLocation: '/'),
          title: const Text(
            'Sayfa bulunamadı',
            overflow: TextOverflow.ellipsis,
          ),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      Icons.explore_off_outlined,
                      size: 52,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Bu sayfayı bulamadık',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Bağlantıyı kontrol edebilir veya giriş ekranına '
                      'dönebilirsiniz.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: () => context.go('/'),
                      child: const Text('Giriş ekranına dön'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
