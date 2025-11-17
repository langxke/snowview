import 'package:flutter/material.dart';

class AppColorScheme {
  static const Color seed = Color(0xFF3F51B5);

  static ColorScheme light = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: Brightness.light,
  );

  static ColorScheme dark = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: Brightness.dark,
  );
}


