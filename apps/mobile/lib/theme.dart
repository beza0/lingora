import 'package:flutter/material.dart';

/// Tasarım belirteçleri (docs/design). Sade, göz yormayan; açık ve koyu tema.
class Palette {
  final Color bg, surface, surface2, text, muted, border, primary, primaryInk, primarySoft, primaryText;
  final Color success, successSoft, hint, hintSoft, danger, dangerSoft;
  final Map<String, Color> domains;
  const Palette({
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.text,
    required this.muted,
    required this.border,
    required this.primary,
    required this.primaryInk,
    required this.primarySoft,
    required this.primaryText,
    required this.success,
    required this.successSoft,
    required this.hint,
    required this.hintSoft,
    required this.danger,
    required this.dangerSoft,
    required this.domains,
  });

  static const light = Palette(
    bg: Color(0xFFFAF8F5),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFF3F0F8),
    text: Color(0xFF1E1B2E),
    muted: Color(0xFF5E5A6E),
    border: Color(0xFFE6E1EE),
    primary: Color(0xFF5B3FD0),
    primaryInk: Color(0xFFFFFFFF),
    primarySoft: Color(0xFFEEE9FC),
    primaryText: Color(0xFF4E33C2),
    success: Color(0xFF1E7A46),
    successSoft: Color(0xFFE5F4EA),
    hint: Color(0xFFA34B07),
    hintSoft: Color(0xFFFFF0E0),
    danger: Color(0xFFB3263E),
    dangerSoft: Color(0xFFFCE8EC),
    domains: {
      'general': Color(0xFF0B7F80),
      'software': Color(0xFF2B63C9),
      'engineering': Color(0xFFB45A0C),
      'yds': Color(0xFF6E42C8),
      'health': Color(0xFFC0365A),
      'tourism': Color(0xFF1F8A4C),
      'law': Color(0xFF5A5F6E),
    },
  );

  static const dark = Palette(
    bg: Color(0xFF0E1424),
    surface: Color(0xFF161E33),
    surface2: Color(0xFF1D2740),
    text: Color(0xFFECEAF4),
    muted: Color(0xFFA6A3BA),
    border: Color(0xFF2A3452),
    primary: Color(0xFFA58DFF),
    primaryInk: Color(0xFF140F2E),
    primarySoft: Color(0xFF2A2550),
    primaryText: Color(0xFFBBA8FF),
    success: Color(0xFF5BD08F),
    successSoft: Color(0xFF173528),
    hint: Color(0xFFF5A25A),
    hintSoft: Color(0xFF3A2614),
    danger: Color(0xFFFF8A9A),
    dangerSoft: Color(0xFF3D1A22),
    domains: {
      'general': Color(0xFF3CC7C4),
      'software': Color(0xFF6EA2FF),
      'engineering': Color(0xFFF0A050),
      'yds': Color(0xFFB79BFF),
      'health': Color(0xFFFF8FAB),
      'tourism': Color(0xFF6FD69A),
      'law': Color(0xFFB4BAC8),
    },
  );

  Color domain(String id) => domains[id] ?? primary;
}

class PaletteExt extends ThemeExtension<PaletteExt> {
  final Palette p;
  const PaletteExt(this.p);
  @override
  PaletteExt copyWith({Palette? p}) => PaletteExt(p ?? this.p);
  @override
  PaletteExt lerp(ThemeExtension<PaletteExt>? other, double t) => this;
}

extension PaletteContext on BuildContext {
  Palette get pal => Theme.of(this).extension<PaletteExt>()!.p;
}

ThemeData buildTheme(Palette p, Brightness b) {
  final scheme = ColorScheme.fromSeed(seedColor: p.primary, brightness: b).copyWith(
    primary: p.primary,
    onPrimary: p.primaryInk,
    surface: p.surface,
    onSurface: p.text,
    error: p.danger,
    outline: p.border,
  );
  final radius = BorderRadius.circular(14);
  return ThemeData(
    useMaterial3: true,
    brightness: b,
    colorScheme: scheme,
    scaffoldBackgroundColor: p.bg,
    extensions: [PaletteExt(p)],
    appBarTheme: AppBarTheme(backgroundColor: p.bg, foregroundColor: p.text, elevation: 0, scrolledUnderElevation: 0, centerTitle: false),
    cardTheme: CardThemeData(
      color: p.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: radius, side: BorderSide(color: p.border)),
    ),
    dividerTheme: DividerThemeData(color: p.border, space: 1),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: radius),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: radius),
        side: BorderSide(color: p.border),
        foregroundColor: p.text,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.surface,
      border: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: p.border)),
      enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: p.border)),
      focusedBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: p.primary, width: 2)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.surface,
      indicatorColor: p.primarySoft,
      height: 64,
      labelTextStyle: WidgetStatePropertyAll(TextStyle(fontSize: 12, color: p.muted)),
    ),
    chipTheme: ChipThemeData(backgroundColor: p.surface2, side: BorderSide(color: p.border), labelStyle: TextStyle(color: p.text)),
  );
}
