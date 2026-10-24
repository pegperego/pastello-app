import 'package:flutter/material.dart';

import 'tokens.dart';

/// Titles and buttons use Fredoka, a variable font: the weight is set both
/// as `fontWeight` and as a `wght` variation.
TextStyle fredoka(double size, {FontWeight weight = FontWeight.w600}) =>
    TextStyle(
      fontFamily: 'Fredoka',
      fontSize: size,
      fontWeight: weight,
      fontVariations: [FontVariation.weight(weight.value.toDouble())],
      color: Tokens.ink,
    );

/// The app theme: light only in v1 (G-01).
ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: Tokens.coral,
    primary: Tokens.coral,
    surface: Tokens.paper,
    onSurface: Tokens.ink,
    error: Tokens.raspberry,
  );
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: Tokens.paper,
    fontFamily: 'Andika',
    textTheme: TextTheme(
      headlineMedium: fredoka(28),
      titleLarge: fredoka(22),
      labelLarge: fredoka(16, weight: FontWeight.w500),
      bodyLarge: const TextStyle(fontSize: 18, color: Tokens.ink),
      bodyMedium: const TextStyle(fontSize: 16, color: Tokens.graphite),
    ),
    dividerTheme: const DividerThemeData(color: Tokens.border, thickness: 1.5),
    materialTapTargetSize: MaterialTapTargetSize.padded,
  );
}
