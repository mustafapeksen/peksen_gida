import 'package:flutter/material.dart';

import '../../../shared/widgets/app_back_button.dart';
import '../../../shared/widgets/preview_notice.dart';
import '../domain/role_menu.dart';

class ScreenPlaceholderPage extends StatelessWidget {
  const ScreenPlaceholderPage({
    required this.role,
    required this.destination,
    super.key,
  });

  final AppRole role;
  final RoleMenuEntry destination;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: AppBackButton(fallbackLocation: '/preview/roles/${role.id}'),
        title: const Text('Ekran önizlemesi'),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const PreviewNotice(),
                  const SizedBox(height: 32),
                  Text(role.label, style: theme.textTheme.labelLarge),
                  const SizedBox(height: 8),
                  Text(
                    destination.label,
                    key: const ValueKey('destination-title'),
                    style: theme.textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 24),
                  Icon(
                    Icons.space_dashboard_outlined,
                    size: 56,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Bu ekran henüz bağlı değil',
                    style: theme.textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Bu bölümün iş akışı sonraki geliştirme aşamalarında '
                    'eklenecek. Bu önizleme veri okumaz veya işlem oluşturmaz.',
                    textAlign: TextAlign.center,
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
