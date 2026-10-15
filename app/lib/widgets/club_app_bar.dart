import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// App bar shared by every screen, so the look stays consistent without
/// touching version-sensitive theme fields.
class ClubAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ClubAppBar({
    super.key,
    required this.title,
    this.actions,
    this.automaticallyImplyLeading = true,
  });

  final String title;
  final List<Widget>? actions;
  final bool automaticallyImplyLeading;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return AppBar(
      title: Text(title),
      actions: actions,
      automaticallyImplyLeading: automaticallyImplyLeading,
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      elevation: 0,
      centerTitle: false,
      leading: automaticallyImplyLeading && Navigator.of(context).canPop()
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Volver',
              onPressed: () => Navigator.of(context).maybePop(),
            )
          : null,
    );
  }

  /// Accent used by the club brand in headers.
  static Color accent(BuildContext context) => AppTheme.accentColor;
}
