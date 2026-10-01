import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract class Kawaii {
  // Core palette — Kawaii Pop tokens (light)
  static const peach = Color(0xFFF8BE9E);
  static const peachHover = Color(0xFFF5A888);
  static const sky = Color(0xFF70D6FF);
  static const skyHover = Color(0xFF4DC8FF);
  static const sunny = Color(0xFFFFD670);
  static const sunnyHover = Color(0xFFFFCA4D);
  static const bubble = Color(0xFFFF7096);
  static const mint = Color(0xFFBCFFBE);
  static const ink = Color(0xFF0A0A0A);
  static const paper = Color(0xFFFFFFFF);
  static const cream = Color(0xFFFFF7F0);
  static const blushSubtle = Color(0xFFFFE9D9);
  static const skySubtle = Color(0xFFE3F5FF);
  static const sunnySubtle = Color(0xFFFFF1C9);
  static const pinkSubtle = Color(0xFFFFE0E9);
  static const mintSubtle = Color(0xFFE2FFE3);

  // Dark mode surfaces
  static const night = Color(0xFF0A0A0A);
  static const nightCard = Color(0xFF1E1E1E);
  static const nightInk = Color(0xFFFFFFFF);

  static const borderW = 3.0;
  static const radiusCard = 32.0;
  static const radiusInput = 24.0;
  static const radiusBtn = 28.0;

  /// Display face for sticker headers. Loaded via GoogleFonts in
  /// light()/dark(); refer to this const so const TextStyles stay const
  /// and the family never drifts per file.
  static const displayFamily = 'Nunito';

  /// Note color order. DB stores colorIdx into this list — append only,
  /// never reorder, or old notes change color.
  static const notePalette = [peach, sky, sunny, mint, bubble];

  /// App-wide theme mode. SettingsTab writes, OurSpaceApp reads.
  /// Defaults to light to preserve the sticker-book look.
  static final themeMode = ValueNotifier<ThemeMode>(ThemeMode.light);

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  /// Outline color: ink on light, white on dark. Never a fill.
  static Color edgeOf(BuildContext context) =>
      isDark(context) ? Colors.white : ink;

  /// Card surface: white on light, nightCard on dark.
  static Color cardOf(BuildContext context) =>
      isDark(context) ? nightCard : Colors.white;

  static Color textOf(BuildContext context) =>
      isDark(context) ? Colors.white : ink;

  /// Bottom clearance for tab scrolls: floating nav (~72) + FAB (64)
  /// + margins. Plus the device safe-area so content never hides
  /// behind the nav on notched phones.
  static double tabBottom(BuildContext context) =>
      100 + MediaQuery.of(context).padding.bottom;

  // Signature kawaii sticker shadow: chunky offset + soft lift.
  // Craft-floor collision note: floor bans zero-blur hard offsets as
  // decoration, but Kawaii Pop REQUIRES offset sticker depth as identity.
  // Override named here: style wins for depth; contrast/focus still hold.
  static List<BoxShadow> stickerShadow(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final edge = dark ? Colors.white : ink;
    return [
      BoxShadow(
        color: edge,
        offset: const Offset(4, 4),
        blurRadius: 0,
        spreadRadius: 0,
      ),
      const BoxShadow(
        color: Color(0x14000000),
        offset: Offset(0, 10),
        blurRadius: 24,
      ),
    ];
  }

  static List<BoxShadow> stickerShadowSmall(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final edge = dark ? Colors.white : ink;
    return [
      BoxShadow(color: edge, offset: const Offset(3, 3), blurRadius: 0),
      const BoxShadow(
          color: Color(0x14000000), offset: Offset(0, 6), blurRadius: 16),
    ];
  }

  static ThemeData light() {
    final nunito = GoogleFonts.nunitoTextTheme();
    final inter = GoogleFonts.interTextTheme();
    final scheme = ColorScheme.fromSeed(
      seedColor: peach,
      primary: ink,
      brightness: Brightness.light,
    ).copyWith(
      primary: peach,
      onPrimary: ink,
      secondary: sky,
      onSecondary: ink,
      tertiary: sunny,
      surface: paper,
      onSurface: ink,
      error: bubble,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: cream,
      textTheme: nunito.copyWith(
        displayLarge: nunito.displayLarge?.copyWith(
            fontWeight: FontWeight.w900, color: ink, letterSpacing: -0.5),
        displayMedium: nunito.displayMedium
            ?.copyWith(fontWeight: FontWeight.w800, color: ink),
        headlineLarge: nunito.headlineLarge
            ?.copyWith(fontWeight: FontWeight.w800, color: ink),
        headlineMedium: nunito.headlineMedium
            ?.copyWith(fontWeight: FontWeight.w800, color: ink),
        titleLarge: nunito.titleLarge
            ?.copyWith(fontWeight: FontWeight.w800, color: ink),
        bodyLarge: inter.bodyLarge?.copyWith(color: ink),
        bodyMedium: inter.bodyMedium?.copyWith(color: ink),
        labelLarge:
            inter.labelLarge?.copyWith(fontWeight: FontWeight.w700, color: ink),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: cream,
        foregroundColor: ink,
        elevation: 0,
        centerTitle: false,
      ),
    );
  }

  static ThemeData dark() {
    final nunito = GoogleFonts.nunitoTextTheme(ThemeData.dark().textTheme);
    final inter = GoogleFonts.interTextTheme(ThemeData.dark().textTheme);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: peach,
        onPrimary: ink,
        secondary: sky,
        onSecondary: ink,
        tertiary: sunny,
        surface: nightCard,
        onSurface: Color(0xFFF5F5F5),
        error: bubble,
      ),
      scaffoldBackgroundColor: night,
      textTheme: nunito.copyWith(
        displayLarge: nunito.displayLarge
            ?.copyWith(fontWeight: FontWeight.w900, color: Colors.white),
        headlineMedium: nunito.headlineMedium
            ?.copyWith(fontWeight: FontWeight.w800, color: Colors.white),
        titleLarge: nunito.titleLarge
            ?.copyWith(fontWeight: FontWeight.w800, color: Colors.white),
        bodyLarge: inter.bodyLarge?.copyWith(color: const Color(0xFFF5F5F5)),
        bodyMedium: inter.bodyMedium?.copyWith(color: const Color(0xFFF5F5F5)),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: night,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
    );
  }
}
