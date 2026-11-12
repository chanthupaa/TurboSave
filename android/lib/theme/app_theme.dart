import 'package:flutter/material.dart';

class AppTheme {
  // Light Palette (Refined Editorial & High-Utility Porcelain)
  static const Color lightBgCanvas = Color(0xFFF6F6F4);
  static const Color lightBgSurface = Color(0xFFFFFFFF); // Pure White
  static const Color lightBgElevated = Color(0xFFEDEDE9);
  static const Color lightBgHover = Color(0xFFE2E8F0); // Slate 200
  static const Color lightBorder = Color(0xFFE2E2DE);
  static const Color lightBorderSubtle = Color(0xFFEEF2F6);
  static const Color lightTextPrimary = Color(0xFF101010);
  static const Color lightTextSecondary = Color(0xFF555552);
  static const Color lightTextMuted = Color(0xFF676762);

  // Dark Palette (Balanced Obsidian & Midnight Slate - Non-harsh)
  static const Color darkBgCanvas = Color(0xFF0A0A0A);
  static const Color darkBgSurface = Color(0xFF171717);
  static const Color darkBgElevated = Color(0xFF242424);
  static const Color darkBgHover = Color(0xFF2D2D2D);
  static const Color darkBorder = Color(0xFF292929);
  static const Color darkBorderSubtle = Color(0xFF202020);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkTextMuted = Color(0xFF94A3B8);

  // Intentional Accents (Tailored Royal Blue & Signal Accents)
  static const Color brandBlue = Color(0xFF5B5CE2); // Signature indigo
  static const Color brandBlueHover = Color(0xFF4748C8);
  static const Color brandBlueLight = Color(0xFFF0F0FF);

  static const Color accentIndigo = Color(0xFF4F46E5);
  static const Color accentViolet = Color(0xFF7C3AED);
  static const Color accentCyan = Color(0xFF0284C7);
  static const Color accentEmerald = Color(0xFF059669);
  static const Color accentAmber = Color(0xFFD97706);
  static const Color accentRose = Color(0xFFE11D48);

  // Platform Brand Colors
  static const Color instagramGradientStart = Color(0xFF833AB4);
  static const Color instagramGradientEnd = Color(0xFFFD1D1D);
  static const Color tiktokColor = Color(0xFF00F2FE);
  static const Color facebookBlue = Color(0xFF1877F2);
  static const Color twitterBlue = Color(0xFF1DA1F2);
  static const Color soundcloudOrange = Color(0xFFFF5500);

  // Gradients (Subtle & Tasteful)
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF6D5DFB), Color(0xFF4263EB)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient subtleGlassGradient = LinearGradient(
    colors: [Color(0x0DFFFFFF), Color(0x05FFFFFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Legacy static aliases for backward compatibility
  static const Color bgCanvas = darkBgCanvas;
  static const Color bgSurface = darkBgSurface;
  static const Color bgSurfaceElevated = darkBgElevated;
  static const Color bgPrimary = darkBgCanvas;
  static const Color bgSecondary = darkBgSurface;
  static const Color bgElevated = darkBgElevated;
  static const Color textPrimary = darkTextPrimary;
  static const Color textSecondary = darkTextSecondary;
  static const Color textMuted = darkTextMuted;
  static const Color borderHairline = Color(0x1FFFFFFF);
  static const Color borderSubtle = darkBorder;
  static const Color borderFocus = brandBlue;

  // Context-aware dynamic helpers
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color canvas(BuildContext context) =>
      isDark(context) ? darkBgCanvas : lightBgCanvas;

  static Color surface(BuildContext context) =>
      isDark(context) ? darkBgSurface : lightBgSurface;

  static Color surfaceElevated(BuildContext context) =>
      isDark(context) ? darkBgElevated : lightBgElevated;

  static Color border(BuildContext context) =>
      isDark(context) ? darkBorder : lightBorder;

  static Color borderLight(BuildContext context) =>
      isDark(context) ? darkBorderSubtle : lightBorderSubtle;

  static Color text(BuildContext context) =>
      isDark(context) ? darkTextPrimary : lightTextPrimary;

  static Color textSec(BuildContext context) =>
      isDark(context) ? darkTextSecondary : lightTextSecondary;

  static Color textMut(BuildContext context) =>
      isDark(context) ? darkTextMuted : lightTextMuted;

  static Color primary(BuildContext context) => brandBlue;

  // LIGHT THEME SPECIFICATION
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBgCanvas,
      primaryColor: brandBlue,
      canvasColor: lightBgCanvas,
      cardColor: lightBgSurface,
      dividerColor: lightBorder,
      colorScheme: const ColorScheme.light(
        primary: brandBlue,
        onPrimary: Colors.white,
        secondary: accentCyan,
        onSecondary: Colors.white,
        surface: lightBgSurface,
        onSurface: lightTextPrimary,
        surfaceContainerHighest: lightBgElevated,
        error: accentRose,
        onError: Colors.white,
        outline: lightBorder,
      ),
      fontFamily: 'Manrope',
      textTheme: _textTheme(lightTextPrimary, lightTextSecondary),
      appBarTheme: const AppBarTheme(
        backgroundColor: lightBgSurface,
        foregroundColor: lightTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: lightTextPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: lightBorder,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightBgElevated,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: brandBlue, width: 1.8),
        ),
        hintStyle: const TextStyle(color: lightTextMuted, fontSize: 13),
      ),
      filledButtonTheme: _filledButtonTheme,
      snackBarTheme: _snackBarTheme(lightBgSurface, lightTextPrimary),
      pageTransitionsTheme: _pageTransitions,
    );
  }

  // DARK THEME SPECIFICATION
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBgCanvas,
      primaryColor: brandBlue,
      canvasColor: darkBgCanvas,
      cardColor: darkBgSurface,
      dividerColor: darkBorder,
      colorScheme: const ColorScheme.dark(
        primary: brandBlue,
        onPrimary: Colors.white,
        secondary: Color(0xFF38BDF8),
        onSecondary: Colors.white,
        surface: darkBgSurface,
        onSurface: darkTextPrimary,
        surfaceContainerHighest: darkBgElevated,
        error: accentRose,
        onError: Colors.white,
        outline: darkBorder,
      ),
      fontFamily: 'Manrope',
      textTheme: _textTheme(darkTextPrimary, darkTextSecondary),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkBgSurface,
        foregroundColor: darkTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: darkTextPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: darkBorder,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkBgElevated,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: brandBlue, width: 1.8),
        ),
        hintStyle: const TextStyle(color: darkTextMuted, fontSize: 13),
      ),
      filledButtonTheme: _filledButtonTheme,
      snackBarTheme: _snackBarTheme(darkBgElevated, darkTextPrimary),
      pageTransitionsTheme: _pageTransitions,
    );
  }

  static ThemeData get proTheme => darkTheme;

  static TextTheme _textTheme(Color primary, Color secondary) => TextTheme(
    displaySmall: TextStyle(
      color: primary,
      fontSize: 48,
      fontWeight: FontWeight.w800,
      letterSpacing: -2.2,
    ),
    headlineMedium: TextStyle(
      color: primary,
      fontSize: 30,
      fontWeight: FontWeight.w800,
      letterSpacing: -1,
    ),
    headlineSmall: TextStyle(
      color: primary,
      fontSize: 24,
      fontWeight: FontWeight.w700,
      letterSpacing: -.6,
    ),
    titleLarge: TextStyle(
      color: primary,
      fontSize: 20,
      fontWeight: FontWeight.w700,
      letterSpacing: -.4,
    ),
    titleMedium: TextStyle(
      color: primary,
      fontSize: 16,
      fontWeight: FontWeight.w700,
      letterSpacing: -.2,
    ),
    bodyLarge: TextStyle(color: secondary, fontSize: 16, height: 1.45),
    bodyMedium: TextStyle(color: secondary, fontSize: 14, height: 1.45),
    labelLarge: const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w700,
      letterSpacing: -.1,
    ),
  ).apply(fontFamily: 'Manrope');

  static final FilledButtonThemeData _filledButtonTheme = FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: brandBlue,
      foregroundColor: Colors.white,
      minimumSize: const Size(0, 50),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
    ),
  );

  static SnackBarThemeData _snackBarTheme(Color background, Color foreground) =>
      SnackBarThemeData(
        backgroundColor: background,
        contentTextStyle: TextStyle(
          color: foreground,
          fontWeight: FontWeight.w600,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        insetPadding: const EdgeInsets.all(16),
      );

  static const PageTransitionsTheme _pageTransitions = PageTransitionsTheme(
    builders: {
      TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
    },
  );
}
