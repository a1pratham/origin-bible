import 'package:flutter/material.dart';

/// Typography uses system fonts on purpose: zero licensing risk, zero network,
/// zero download size. A bundled reading font can be added later, but only
/// after its license is recorded in LICENSES.md.
abstract final class AppTypography {
  static const List<String> serifFallback = [
    'Georgia',
    'Noto Serif',
    'serif',
  ];

  static TextTheme textTheme(TextTheme base, ColorScheme scheme) {
    final t = base.apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );
    return t.copyWith(
      bodyLarge: t.bodyLarge?.copyWith(fontSize: 17, height: 1.5),
      bodyMedium: t.bodyMedium?.copyWith(fontSize: 15, height: 1.5),
      titleLarge: t.titleLarge?.copyWith(fontWeight: FontWeight.w600),
      titleMedium: t.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    );
  }
}

/// Styles for Scripture and references. Access with
/// `Theme.of(context).extension<ReadingStyles>()!`.
@immutable
class ReadingStyles extends ThemeExtension<ReadingStyles> {
  const ReadingStyles({
    required this.verse,
    required this.verseNumber,
    required this.reference,
  });

  factory ReadingStyles.fromScheme(ColorScheme scheme) {
    return ReadingStyles(
      verse: TextStyle(
        fontSize: 20,
        height: 1.65,
        color: scheme.onSurface,
        fontFamilyFallback: AppTypography.serifFallback,
      ),
      verseNumber: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: scheme.primary,
        fontFeatures: const [FontFeature.superscripts()],
      ),
      reference: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: scheme.onSurfaceVariant,
        letterSpacing: 0.3,
      ),
    );
  }

  final TextStyle verse;
  final TextStyle verseNumber;
  final TextStyle reference;

  @override
  ReadingStyles copyWith({
    TextStyle? verse,
    TextStyle? verseNumber,
    TextStyle? reference,
  }) {
    return ReadingStyles(
      verse: verse ?? this.verse,
      verseNumber: verseNumber ?? this.verseNumber,
      reference: reference ?? this.reference,
    );
  }

  @override
  ReadingStyles lerp(ThemeExtension<ReadingStyles>? other, double t) {
    if (other is! ReadingStyles) return this;
    return ReadingStyles(
      verse: TextStyle.lerp(verse, other.verse, t)!,
      verseNumber: TextStyle.lerp(verseNumber, other.verseNumber, t)!,
      reference: TextStyle.lerp(reference, other.reference, t)!,
    );
  }
}
