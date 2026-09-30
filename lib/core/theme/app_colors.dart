import 'package:flutter/material.dart';

/// Single source of truth for brand colors.
/// Everything else derives from [seed] via Material 3 ColorScheme.fromSeed,
/// which keeps light/dark contrast consistent.
abstract final class AppColors {
  static const Color seed = Color(0xFF3F3D8F);
}
