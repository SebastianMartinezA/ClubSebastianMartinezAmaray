import 'package:flutter/material.dart';

/// App palette.
///
/// Every colour here was measured with PIL over the screenshots of the Figma
/// prototype (Android Compact frame, 360x800 dp). See `docs/design-system.md`
/// for the measurement method and the pixel counts behind each value.
class AppColors {
  AppColors._();

  // --- Surfaces ---
  static const Color bg = Color(0xFF050508); // screen background
  static const Color surface = Color(0xFF171719); // cards
  static const Color surfaceAlt = Color(0xFF141417); // tabs and input container
  static const Color surfacePanel = Color(0xFF0C0C0F); // form panel, one step above the background

  // --- Borders ---
  static const Color border = Color(0xFF242427);
  static const Color borderStrong = Color(0xFF2A2A2D); // card top border, secondary button
  static const Color inputBorder = Color(0xFF2D2D30);
  static const Color hairline = Color(0xFF1C1C1E); // separators

  // --- Accent ---
  static const Color lime = Color(0xFFD4FF00);
  static const Color onLime = Color(0xFF000000);

  // --- Text ---
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textHeadline = Color(0xFFF0F1F8);
  static const Color textSecondary = Color(0xFF6C6C6E);
  static const Color textLabel = Color(0xFF545456);
  static const Color tabInactive = Color(0xFF777778);

  // --- States ---
  static const Color danger = Color(0xFFF87171);
  static const Color dangerBg = Color(0xFF331D1F);
  static const Color dangerBorder = Color(0xFF4C2225);
  static const Color success = Color(0xFF0A8A5E);

  // --- Sport chips (background / border / foreground) ---
  static const SportStyle sportFutbol =
      SportStyle(Color(0xFF132F28), Color(0xFF104335), Color(0xFF10B981));
  static const SportStyle sportTenis =
      SportStyle(Color(0xFF392315), Color(0xFF522C13), Color(0xFFF97316));
  static const SportStyle sportHockey =
      SportStyle(Color(0xFF3B2860), Color(0xFF3E206C), Color(0xFF7C3AED));
  static const SportStyle sportVoley =
      SportStyle(Color(0xFF5B2041), Color(0xFF5C2142), Color(0xFFDB2777));
  static const SportStyle sportGolf =
      SportStyle(Color(0xFF132C3A), Color(0xFF0F435D), Color(0xFF0EA5E9));
}

/// Colours of a sport chip.
class SportStyle {
  const SportStyle(this.bg, this.border, this.fg);

  final Color bg;
  final Color border;
  final Color fg;
}

/// Visual identity of the app: dark only, lime accent, Material 3.
///
/// The prototype is a dark theme with a lime accent, so the app is dark only
/// (`light` is kept as an alias because the widget tests build with it).
///
/// Note on the type scale: the prototype was measured on a compact frame and
/// its body text came out around 11 dp. That is too small to read on a phone,
/// so the scale below is the same hierarchy with legible sizes (15 dp body).
/// The choice is deliberate and easy to defend: same design, readable text.
class AppTheme {
  AppTheme._();

  /// Club lime, kept as the seed for compatibility.
  static const Color seedColor = AppColors.lime;

  /// Used for warnings and as a fallback accent.
  static const Color accentColor = AppColors.lime;

  static const double cardRadius = 16;
  static const double buttonRadius = 12;
  static const double gap = 12;

  static BorderRadius get borderRadius => BorderRadius.circular(cardRadius);

  /// Dark only: the light theme is the dark one.
  static ThemeData get light => dark;

  static ThemeData get dark {
    const ColorScheme scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.lime,
      onPrimary: AppColors.onLime,
      primaryContainer: AppColors.lime,
      onPrimaryContainer: AppColors.onLime,
      secondary: AppColors.lime,
      onSecondary: AppColors.onLime,
      secondaryContainer: AppColors.surfaceAlt,
      onSecondaryContainer: AppColors.textPrimary,
      error: AppColors.danger,
      onError: AppColors.onLime,
      errorContainer: AppColors.dangerBg,
      onErrorContainer: AppColors.danger,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      surfaceContainerLowest: AppColors.bg,
      surfaceContainerLow: AppColors.surfacePanel,
      surfaceContainer: AppColors.surfaceAlt,
      surfaceContainerHigh: AppColors.surface,
      surfaceContainerHighest: AppColors.surface,
      onSurfaceVariant: AppColors.textSecondary,
      outline: AppColors.borderStrong,
      outlineVariant: AppColors.hairline,
      scrim: Color(0x99000000),
      inverseSurface: AppColors.lime,
      onInverseSurface: AppColors.onLime,
    );

    const TextTheme text = TextTheme(
      displaySmall: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w800,
        height: 1.15,
        color: AppColors.textHeadline,
      ),
      headlineMedium: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        height: 1.15,
        color: AppColors.textHeadline,
      ),
      headlineSmall: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        height: 1.2,
        color: AppColors.textHeadline,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        height: 1.2,
        color: AppColors.textPrimary,
      ),
      titleMedium: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        height: 1.25,
        letterSpacing: 1.2,
        color: AppColors.lime,
      ),
      titleSmall: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        height: 1.2,
        color: AppColors.textPrimary,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.35,
        color: AppColors.textPrimary,
      ),
      bodyMedium: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 1.35,
        color: AppColors.textSecondary,
      ),
      bodySmall: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        height: 1.3,
        color: AppColors.textSecondary,
      ),
      labelLarge: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
        color: AppColors.onLime,
      ),
      labelMedium: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
        color: AppColors.textSecondary,
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
        color: AppColors.textLabel,
      ),
    );

    final ThemeData base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.bg,
      canvasColor: AppColors.bg,
      textTheme: text,
      dividerTheme: const DividerThemeData(
        color: AppColors.hairline,
        thickness: 1,
        space: 1,
      ),
    );

    return base.copyWith(
      // ---- Inputs ----
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceAlt,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        hintStyle: const TextStyle(fontSize: 15, color: AppColors.textLabel),
        labelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
          color: AppColors.textLabel,
        ),
        floatingLabelStyle: const TextStyle(fontSize: 13, color: AppColors.lime),
        border: _inputBorder(AppColors.inputBorder),
        enabledBorder: _inputBorder(AppColors.inputBorder),
        focusedBorder: _inputBorder(AppColors.lime, width: 1.4),
        errorBorder: _inputBorder(AppColors.dangerBorder),
        focusedErrorBorder: _inputBorder(AppColors.danger, width: 1.4),
        errorStyle: const TextStyle(fontSize: 13, color: AppColors.danger),
      ),

      // ---- Buttons ----
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.lime,
          foregroundColor: AppColors.onLime,
          disabledBackgroundColor: AppColors.surfaceAlt,
          disabledForegroundColor: AppColors.textLabel,
          elevation: 0,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonRadius),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.lime,
          foregroundColor: AppColors.onLime,
          disabledBackgroundColor: AppColors.surfaceAlt,
          disabledForegroundColor: AppColors.textLabel,
          minimumSize: const Size(0, 46),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonRadius),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          backgroundColor: Colors.transparent,
          side: const BorderSide(color: AppColors.borderStrong),
          minimumSize: const Size(0, 46),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonRadius),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.lime,
          minimumSize: const Size(0, 44),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
          ),
        ),
      ),

      // ---- Chips (sport filters) ----
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.lime,
        disabledColor: AppColors.surfaceAlt,
        labelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        secondaryLabelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.onLime,
        ),
        side: const BorderSide(color: AppColors.borderStrong),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),

      // ---- Cards ----
      // `CardThemeData` is the type in Flutter >= 3.27; on older versions the
      // same object is called `CardTheme`. See app/README.md.
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: const BorderSide(color: AppColors.borderStrong),
        ),
      ),

      // ---- Segmented control (Todas | Terminadas | Canceladas) ----
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((Set<WidgetState> states) =>
              states.contains(WidgetState.selected)
                  ? AppColors.lime
                  : AppColors.surfaceAlt),
          foregroundColor: WidgetStateProperty.resolveWith((Set<WidgetState> states) =>
              states.contains(WidgetState.selected)
                  ? AppColors.onLime
                  : AppColors.textPrimary),
          side: const WidgetStatePropertyAll<BorderSide>(
            BorderSide(color: AppColors.hairline),
          ),
          shape: WidgetStatePropertyAll<OutlinedBorder>(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          textStyle: const WidgetStatePropertyAll<TextStyle>(
            TextStyle(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 0.6),
          ),
          minimumSize: const WidgetStatePropertyAll<Size>(Size(0, 40)),
        ),
      ),

      // ---- Flat app bar ----
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bg,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
        ),
      ),

      // ---- Feedback ----
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surface,
        contentTextStyle: const TextStyle(
          fontSize: 15,
          color: AppColors.textPrimary,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(buttonRadius),
          side: const BorderSide(color: AppColors.borderStrong),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.lime,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.lime,
        textColor: AppColors.textPrimary,
        tileColor: Colors.transparent,
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(buttonRadius),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  /// Shared input decoration. Kept as a helper (and not only in the theme) so
  /// screens can build a field with an icon or a suffix in one line.
  static InputDecoration inputDecoration(
    String label, {
    String? hint,
    Widget? suffixIcon,
    Widget? prefixIcon,
    bool enabled = true,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      enabled: enabled,
    );
  }

  /// Colour of a reservation status chip.
  static Color statusColor(String label) {
    switch (label) {
      case 'Activa':
        return AppColors.lime;
      case 'Terminada':
        return AppColors.textSecondary;
      default: // Cancelada
        return AppColors.danger;
    }
  }
}
