import 'package:flutter/material.dart';

ThemeData ledgerTheme(bool dark) {
  final bg = dark ? const Color(0xff000000) : const Color(0xfff8f9fd);
  final surface = dark ? const Color(0xff18181b) : const Color(0xffffffff);
  final ink = dark ? const Color(0xfffafafa) : const Color(0xff191c1f);
  final accent = dark ? const Color(0xff10b981) : const Color(0xff224b3a);
  final scheme =
      ColorScheme.fromSeed(
        seedColor: accent,
        brightness: dark ? Brightness.dark : Brightness.light,
      ).copyWith(
        primary: accent,
        onPrimary: dark ? const Color(0xff000000) : Colors.white,
        primaryContainer: dark
            ? const Color(0xff10b981)
            : const Color(0xff3a6351),
        onPrimaryContainer: dark
            ? const Color(0xff002a1a)
            : const Color(0xffb0ddc6),
        surface: surface,
        onSurface: ink,
        onSurfaceVariant: dark
            ? const Color(0xffa1a1aa)
            : const Color(0xff414944),
        outlineVariant: dark
            ? const Color(0xff27272a)
            : const Color(0xffc1c8c2),
      );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: bg,
  );
  return base.copyWith(
    textTheme: base.textTheme.copyWith(
      displaySmall: TextStyle(
        fontSize: 34,
        height: 1.16,
        fontWeight: FontWeight.w600,
        letterSpacing: -.7,
        color: ink,
      ),
      headlineMedium: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w600,
        letterSpacing: -.4,
        color: ink,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: ink,
      ),
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
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      contentPadding: const EdgeInsets.all(16),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surface,
      indicatorColor: accent.withValues(alpha: .14),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant.withValues(alpha: .6),
      thickness: 1,
    ),
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
