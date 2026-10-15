import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// App bar shared by every screen.
///
/// The look comes entirely from the theme's `appBarTheme` (background
/// `#050508`, white text, flat): the bar must never be painted with the accent
/// lime. Lima is the accent of a single element per screen — the main
/// action — so painting the whole bar with it would break the design system
/// (see `docs/design-system.md`, "3.1 Header" and "5.2 Cuidados al portar").
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
    return AppBar(
      title: Text(title),
      actions: actions,
      automaticallyImplyLeading: automaticallyImplyLeading,
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
