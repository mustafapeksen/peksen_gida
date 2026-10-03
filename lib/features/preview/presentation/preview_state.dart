import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/role_menu.dart';

/// Ephemeral UI preference only. Never use this as an authenticated role.
final selectedPreviewRoleProvider =
    NotifierProvider<SelectedPreviewRole, AppRole?>(SelectedPreviewRole.new);

class SelectedPreviewRole extends Notifier<AppRole?> {
  @override
  AppRole? build() => null;

  void select(AppRole role) => state = role;
}
