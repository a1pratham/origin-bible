import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/annotation_models.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../bible/data/translations.dart';
import '../../bible/data/verse.dart';
import '../application/annotations_provider.dart';
import 'highlight_colors.dart';
import 'verse_actions_sheet.dart';

/// One verse in the reader. Tap for actions. Shows its highlight color and
/// small bookmark / note markers.
class VerseTile extends ConsumerWidget {
  const VerseTile({required this.verse, required this.translation, super.key});

  final Verse verse;
  final Translation translation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final reading = theme.extension<ReadingStyles>()!;
    final isTitle = verse.verse == 0;
    final key = VerseRef(verse.bookCode, verse.chapter, verse.verse);

    final (color, bookmarked, hasNote) = ref.watch(
      annotationsProvider.select(
        (a) => (
          a.highlights[key]?.color,
          a.bookmarks.containsKey(key),
          a.notes.containsKey(key),
        ),
      ),
    );

    InlineSpan marker(IconData icon) => WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Icon(icon, size: 16, color: theme.colorScheme.primary),
          ),
        );

    final text = Text.rich(
      TextSpan(
        children: [
          if (!isTitle)
            TextSpan(text: '${verse.verse} ', style: reading.verseNumber),
          TextSpan(
            text: verse.text,
            style:
                isTitle ? const TextStyle(fontStyle: FontStyle.italic) : null,
          ),
          if (bookmarked) marker(Icons.bookmark),
          if (hasNote) marker(Icons.sticky_note_2_outlined),
        ],
      ),
      style: reading.verse,
    );

    if (isTitle) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.sm,
          0,
          AppSpacing.sm,
          AppSpacing.sm,
        ),
        child: text,
      );
    }

    final radius = BorderRadius.circular(8);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Material(
        color: color == null ? Colors.transparent : highlightBackground(color),
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: () => showVerseActions(
            context,
            verse: verse,
            translation: translation,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: 6,
            ),
            child: text,
          ),
        ),
      ),
    );
  }
}
