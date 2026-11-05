import 'package:flutter/material.dart';

ThemeData ledgerTheme(bool dark) {
  final bg = dark ? const Color(0xff191816) : const Color(0xfff6f2ea);
  final surface = dark ? const Color(0xff25231f) : const Color(0xfffffcf7);
  final ink = dark ? const Color(0xfff4efe7) : const Color(0xff27231f);
  final accent = dark ? const Color(0xffe5a7b5) : const Color(0xff6b2d3d);
  final scheme =
      ColorScheme.fromSeed(
        seedColor: accent,
        brightness: dark ? Brightness.dark : Brightness.light,
      ).copyWith(
        primary: accent,
        surface: surface,
        onSurface: ink,
        outlineVariant: dark
            ? const Color(0xff474139)
            : const Color(0xffded7cb),
      );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: bg,
  );
  return base.copyWith(
    textTheme: base.textTheme.copyWith(
      displaySmall: TextStyle(
        fontFamily: 'serif',
        fontSize: 40,
        height: 1.12,
        letterSpacing: -1.4,
        color: ink,
      ),
      headlineMedium: TextStyle(
        fontFamily: 'serif',
        fontSize: 30,
        letterSpacing: -.8,
        color: ink,
      ),
      titleLarge: TextStyle(fontFamily: 'serif', fontSize: 23, color: ink),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: bg,
      foregroundColor: ink,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      contentPadding: const EdgeInsets.all(16),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surface,
      indicatorColor: accent.withValues(alpha: .12),
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, thickness: 1),
  );
}

IconData categoryIcon(String name) => switch (name) {
  'coffee' => Icons.local_cafe_outlined,
  'bag' => Icons.shopping_bag_outlined,
  'car' => Icons.directions_car_outlined,
  'bill' => Icons.receipt_long_outlined,
  'heart' => Icons.favorite_border,
  'play' => Icons.play_circle_outline,
  _ => Icons.more_horiz,
};
