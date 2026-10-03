import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/app_back_button.dart';
import '../../../shared/widgets/preview_notice.dart';
import '../domain/role_menu.dart';
import 'preview_state.dart';

class PreviewPage extends ConsumerWidget {
  const PreviewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedRole = ref.watch(selectedPreviewRoleProvider);
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallbackLocation: '/'),
        title: const Text('Önizleme'),
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
                  const SizedBox(height: 28),
                  Text('Rol menüleri', style: textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  const Text('İncelemek istediğiniz çalışma alanını seçin.'),
                  if (selectedRole != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Son seçilen rol: ${selectedRole.label}',
                      key: const ValueKey('last-preview-role'),
                      style: textTheme.labelLarge,
                    ),
                  ],
                  const SizedBox(height: 16),
                  for (final role in AppRole.values)
                    Card(
                      child: ListTile(
                        key: ValueKey('role-${role.id}'),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        leading: const Icon(Icons.badge_outlined),
                        title: Text(role.label),
                        subtitle: Text(role.description),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          ref
                              .read(selectedPreviewRoleProvider.notifier)
                              .select(role);
                          context.go('/preview/roles/${role.id}');
                        },
                      ),
                    ),
                  const SizedBox(height: 28),
                  Text('Ortak ekranlar', style: textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  const Text(
                    'Yüklenme, boş liste ve hata görünümlerini inceleyin.',
                  ),
                  const SizedBox(height: 12),
                  for (final item in const [
                    ('loading', 'Yükleniyor', Icons.hourglass_empty),
                    ('empty', 'Boş liste', Icons.inbox_outlined),
                    ('error', 'Hata', Icons.error_outline),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: OutlinedButton.icon(
                        key: ValueKey('state-${item.$1}'),
                        onPressed: () =>
                            context.go('/preview/states/${item.$1}'),
                        icon: Icon(item.$3),
                        label: Text(item.$2),
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
