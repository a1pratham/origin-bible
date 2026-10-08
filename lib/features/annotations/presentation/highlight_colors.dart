import 'package:flutter/material.dart';

import '../../../core/storage/annotation_models.dart';

/// Translucent so text stays readable in both light and dark themes.
Color highlightBackground(HighlightColor c) => switch (c) {
      HighlightColor.yellow => const Color(0x66FFD54F),
      HighlightColor.green => const Color(0x6681C784),
      HighlightColor.blue => const Color(0x6664B5F6),
      HighlightColor.pink => const Color(0x66F48FB1),
    };

Color highlightSwatch(HighlightColor c) => switch (c) {
      HighlightColor.yellow => const Color(0xFFFFD54F),
      HighlightColor.green => const Color(0xFF81C784),
      HighlightColor.blue => const Color(0xFF64B5F6),
      HighlightColor.pink => const Color(0xFFF48FB1),
    };

String highlightLabel(HighlightColor c) => switch (c) {
      HighlightColor.yellow => 'yellow',
      HighlightColor.green => 'green',
      HighlightColor.blue => 'blue',
      HighlightColor.pink => 'pink',
    };
