import 'package:flutter/material.dart';

abstract class Kawaii {
  // Pastels — content + wayfinding only (note/ritual colors, active nav,
  // the primary button of a tab). Chrome stays ink on paper.
  static const peach = Color(0xFFF8BE9E);
  static const peachHover = Color(0xFFF5A888);
  static const sky = Color(0xFF70D6FF);
  static const skyHover = Color(0xFF4DC8FF);
  static const sunny = Color(0xFFFFD670);
  static const sunnyHover = Color(0xFFFFCA4D);
  static const bubble = Color(0xFFFF7096);
  static const mint = Color(0xFFBCFFBE);

  /// Deep plum ink: text, outlines, sticker shadow. Stays the text color
  /// on every pastel fill in both themes.
  static const ink = Color(0xFF2A2133);
  static const paper = Color(0xFFFFFFFF);
  static const cream = Color(0xFFFFF7F0);

  // Semantic tints: alert/toast backgrounds only.
  static const blushSubtle = Color(0xFFFFE9D9);
  static const skySubtle = Color(0xFFE3F5FF);
  static const sunnySubtle = Color(0xFFFFF1C9);
  static const pinkSubtle = Color(0xFFFFE0E9);
  static const mintSubtle = Color(0xFFE2FFE3);

  // Night: plum-tinted, not neutral grey, so pastels still sit warm.
  static const night = Color(0xFF1C1622);
  static const nightCard = Color(0xFF2A2231);
  static const nightInk = Color(0xFFF3EAF5);

  static const borderW = 3.0;
  static const paperBorderW = 2.0;

  /// Radii by tier: sticker cards > inner/paper blocks > inputs.
  /// Buttons, chips and the FAB are pills.
  static const radiusCard = 24.0;
  static const radiusInner = 16.0;
  static const radiusInput = 16.0;
  static const radiusBtn = 999.0;

  /// The only typeface. Bundled in assets/fonts (see pubspec).
  static const displayFamily = 'Nunito';

  /// Note color order. DB stores colorIdx into this list — append only,
  /// never reorder, or old notes change color.
  static const notePalette = [peach, sky, sunny, mint, bubble];

  /// Human names for [notePalette], same order (screen-reader labels).
  static const notePaletteNames = ['Peach', 'Sky', 'Sunny', 'Mint', 'Pink'];

  /// App-wide theme mode. SettingsTab writes, OurSpaceApp reads.
  /// Defaults to light to preserve the sticker-book look.
  static final themeMode = ValueNotifier<ThemeMode>(ThemeMode.light);

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  /// Outline + sticker-shadow color: ink on light, soft lilac on dark.
  static Color edgeOf(BuildContext context) =>
      isDark(context) ? nightInk : ink;

  /// Card surface: white on light, nightCard on dark.
  static Color cardOf(BuildContext context) =>
      isDark(context) ? nightCard : Colors.white;

  /// Body text color on the theme surface.
  static Color textOf(BuildContext context) =>
      isDark(context) ? nightInk : ink;

  /// Secondary text (meta, timestamps) on the theme surface.
  static Color mutedOf(BuildContext context) =>
      textOf(context).withValues(alpha: 0.68);

  /// Hairline dividers inside paper groups.
  static Color lineOf(BuildContext context) =>
      textOf(context).withValues(alpha: isDark(context) ? 0.18 : 0.12);

  /// Readable foreground for any fill. Pastels get ink in both themes —
  /// this is what keeps dark mode from painting white text on peach.
  static Color onFill(Color fill) =>
      ThemeData.estimateBrightnessForColor(fill) == Brightness.light
          ? ink
          : nightInk;

  /// Bottom clearance for tab scrolls. With `extendBody`, the Scaffold
  /// already folds the floating nav + safe area into padding.bottom;
  /// add room for the FAB so the last item never hides behind it.
  static double tabBottom(BuildContext context) =>
      MediaQuery.of(context).padding.bottom + 88;

  /// Sticker depth: one hard offset, no blur. Reserved for the main
  /// object on a screen, buttons, the FAB and the nav bar.
  static List<BoxShadow> sticker(BuildContext context, {double offset = 4}) =>
      [BoxShadow(color: edgeOf(context), offset: Offset(offset, offset))];

  static TextTheme _text(Color fg) {
    final muted = fg.withValues(alpha: 0.68);
    TextStyle s(double size, FontWeight w,
            {double height = 1.25, double spacing = 0, Color? color}) =>
        TextStyle(
            fontFamily: displayFamily,
            fontSize: size,
            fontWeight: w,
            height: height,
            letterSpacing: spacing,
            color: color ?? fg);
    return TextTheme(
      displayLarge: s(48, FontWeight.w900, height: 1.05, spacing: -1),
      displayMedium: s(40, FontWeight.w900, height: 1.05, spacing: -0.8),
      displaySmall: s(34, FontWeight.w900, height: 1.1, spacing: -0.6),
      headlineLarge: s(30, FontWeight.w900, height: 1.15, spacing: -0.4),
      headlineMedium: s(28, FontWeight.w900, height: 1.15, spacing: -0.4),
      headlineSmall: s(26, FontWeight.w900, height: 1.15, spacing: -0.3),
      titleLarge: s(20, FontWeight.w800),
      titleMedium: s(17, FontWeight.w800),
      titleSmall: s(15, FontWeight.w800),
      bodyLarge: s(16, FontWeight.w600, height: 1.45),
      bodyMedium: s(15, FontWeight.w600, height: 1.4),
      bodySmall: s(13, FontWeight.w600, height: 1.35, color: muted),
      labelLarge: s(16, FontWeight.w800),
      labelMedium: s(13, FontWeight.w800),
      labelSmall: s(12, FontWeight.w700),
    );
  }

  static ThemeData _build({required bool dark}) {
    final bg = dark ? night : cream;
    final surface = dark ? nightCard : paper;
    final fg = dark ? nightInk : ink;
    final scheme = (dark
            ? const ColorScheme.dark()
            : const ColorScheme.light())
        .copyWith(
      primary: peach,
      onPrimary: ink,
      secondary: sky,
      onSecondary: ink,
      tertiary: sunny,
      onTertiary: ink,
      surface: surface,
      onSurface: fg,
      surfaceContainerHighest: surface,
      error: bubble,
      onError: ink,
      outline: fg,
      surfaceTint: Colors.transparent,
    );
    final text = _text(fg);
    return ThemeData(
      useMaterial3: true,
      brightness: dark ? Brightness.dark : Brightness.light,
      colorScheme: scheme,
      fontFamily: displayFamily,
      scaffoldBackgroundColor: bg,
      textTheme: text,
      iconTheme: IconThemeData(color: fg),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: fg),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: fg,
        selectionColor: sky.withValues(alpha: 0.5),
        selectionHandleColor: fg,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: fg,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: text.headlineSmall,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }

  static ThemeData light() => _build(dark: false);
  static ThemeData dark() => _build(dark: true);
}
