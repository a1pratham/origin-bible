import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// User-selectable text size steps, applied on top of the system font scale.
const List<double> kTextScaleSteps = [0.85, 1.0, 1.15, 1.3, 1.5];
const List<String> kTextScaleLabels = ['Small', 'Default', 'Large', 'XL', 'XXL'];

/// Combines the OS font scale with the in-app scale, within safe bounds.
double effectiveTextScale({required double system, required double user}) {
  return (system * user).clamp(0.8, 2.4);
}

// Held in memory for now. Persistence to local storage arrives in Phase 3.
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);

/// Index into [kTextScaleSteps]. Default is 1 (1.0x).
final textScaleIndexProvider = StateProvider<int>((ref) => 1);
