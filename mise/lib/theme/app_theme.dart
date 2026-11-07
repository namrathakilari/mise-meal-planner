import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppPalette {
  static const basil = Color(0xFF2E6B50);
  static const tomato = Color(0xFFE5533D);

  /// Meal colour tags (index stored on each meal).
  static const mealColors = <Color>[
    Color(0xFFE5533D), // tomato
    Color(0xFFE3A82B), // butter
    Color(0xFF3E8E63), // basil
    Color(0xFF4F6FB5), // blueberry
    Color(0xFF8A4F9E), // plum
    Color(0xFFEE8A4F), // peach
    Color(0xFF2A9D9A), // lagoon
    Color(0xFFD6567E), // rose
  ];
}

Color mealColor(int index) => AppPalette.mealColors[index % AppPalette.mealColors.length];

/// All semantic colours in one place so light and dark stay consistent.
class Tones {
  const Tones._(this.dark);
  final bool dark;

  factory Tones.of(BuildContext context) =>
      Tones._(Theme.of(context).brightness == Brightness.dark);

  Color get paper => dark ? const Color(0xFF0F1713) : const Color(0xFFF2F6F0);
  Color get card => dark ? const Color(0xFF18231D) : Colors.white;
  Color get line => dark ? const Color(0xFF2B3B32) : const Color(0xFFDCE5DA);
  Color get ink => dark ? const Color(0xFFEAF2EC) : const Color(0xFF15261E);
  Color get muted => dark ? const Color(0xFF9DB1A5) : const Color(0xFF5B6E62);
  Color get accent => dark ? const Color(0xFF7CCBA0) : AppPalette.basil;
  Color get accentSoft => dark ? const Color(0xFF1F3A2D) : const Color(0xFFDDEFE3);
  Color get onAccent => dark ? const Color(0xFF0B1A12) : Colors.white;

  Color mealTint(int index) => mealColor(index).withOpacity(dark ? 0.24 : 0.16);
}

class AppText {
  /// Fraunces for headings and big numbers.
  static TextStyle display(BuildContext context, double size,
      {FontWeight weight = FontWeight.w600, Color? color}) {
    return GoogleFonts.fraunces(
      fontSize: size,
      fontWeight: weight,
      height: 1.1,
      letterSpacing: -0.4,
      color: color ?? Tones.of(context).ink,
    );
  }
}

ThemeData buildTheme(Brightness brightness) {
  final t = Tones._(brightness == Brightness.dark);
  final scheme = ColorScheme.fromSeed(seedColor: AppPalette.basil, brightness: brightness).copyWith(
    primary: t.accent,
    onPrimary: t.onAccent,
    primaryContainer: t.accentSoft,
    onPrimaryContainer: t.ink,
    secondary: AppPalette.tomato,
    surface: t.card,
    onSurface: t.ink,
  );
  final base = ThemeData(useMaterial3: true, brightness: brightness, colorScheme: scheme);
  final textTheme = GoogleFonts.dmSansTextTheme(base.textTheme).apply(
    bodyColor: t.ink,
    displayColor: t.ink,
  );

  OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: c, width: w),
      );

  return base.copyWith(
    scaffoldBackgroundColor: t.paper,
    textTheme: textTheme,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: t.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: border(t.line),
      enabledBorder: border(t.line),
      focusedBorder: border(t.accent, 2),
      errorBorder: border(AppPalette.tomato),
      focusedErrorBorder: border(AppPalette.tomato, 2),
      hintStyle: TextStyle(color: t.muted),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: t.card,
      indicatorColor: t.accentSoft,
      elevation: 0,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: t.ink,
      contentTextStyle: TextStyle(color: t.paper, fontWeight: FontWeight.w500),
      actionTextColor: t.dark ? AppPalette.basil : const Color(0xFF9FE0BD),
    ),
    dividerColor: t.line,
  );
}
