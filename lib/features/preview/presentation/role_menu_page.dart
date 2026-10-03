import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/app_back_button.dart';
import '../../../shared/widgets/preview_notice.dart';
import '../domain/role_menu.dart';

/// A development screen inventory, not a role or permission assignment.
class RoleMenuPage extends StatelessWidget {
  const RoleMenuPage({required this.role, super.key});

  final AppRole role;

  @override
  Widget build(BuildContext context) {
    final entries = roleMenus[role]!;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallbackLocation: '/preview'),
        title: const Text('Rol menüsü'),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              key: PageStorageKey('role-menu-${role.id}'),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                const PreviewNotice(),
                const SizedBox(height: 24),
                Text(role.label, style: textTheme.headlineMedium),
                const SizedBox(height: 8),
                Text(role.description, style: textTheme.bodyLarge),
                const SizedBox(height: 24),
                Text('Ekranlar', style: textTheme.titleMedium),
                const SizedBox(height: 8),
                for (final entry in entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Card(
                      margin: EdgeInsets.zero,
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        key: ValueKey('menu-${role.id}-${entry.id}'),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        title: Text(entry.label, softWrap: true),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () =>
                            context.go('/preview/roles/${role.id}/${entry.id}'),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
