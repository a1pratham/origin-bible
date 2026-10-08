import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/annotation_models.dart';
import '../../../core/theme/app_spacing.dart';
import '../../bible/data/translations.dart';
import '../../bible/data/verse.dart';
import '../application/annotations_provider.dart';
import 'highlight_colors.dart';
import 'note_editor_dialog.dart';
import 'verse_labels.dart';

Future<void> showVerseActions(
  BuildContext context, {
  required Verse verse,
  required Translation translation,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => VerseActionsSheet(
      host: context,
      verse: verse,
      translation: translation,
    ),
  );
}

class VerseActionsSheet extends ConsumerWidget {
  const VerseActionsSheet({
    required this.host,
    required this.verse,
    required this.translation,
    super.key,
  });

  /// Context that outlives the sheet (used for the note dialog and snackbar).
  final BuildContext host;
  final Verse verse;
  final Translation translation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final key = VerseRef(verse.bookCode, verse.chapter, verse.verse);
    final title = verseTitle(key);
    final notifier = ref.read(annotationsProvider.notifier);

    final bookmarked = ref
        .watch(annotationsProvider.select((a) => a.bookmarks.containsKey(key)));
    final hasNote =
        ref.watch(annotationsProvider.select((a) => a.notes.containsKey(key)));
    final current =
        ref.watch(annotationsProvider.select((a) => a.highlights[key]?.color));

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    verse.text,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: Row(
                children: [
                  for (final c in HighlightColor.values)
                    IconButton(
                      tooltip: current == c
                          ? 'Remove ${highlightLabel(c)} highlight'
                          : 'Highlight ${highlightLabel(c)}',
                      icon: Icon(
                        current == c ? Icons.check_circle : Icons.circle,
                        color: highlightSwatch(c),
                        size: 32,
                      ),
                      onPressed: () {
                        notifier.setHighlight(key, current == c ? null : c);
                        Navigator.of(context).pop();
                      },
                    ),
                ],
              ),
            ),
            ListTile(
              leading: Icon(
                bookmarked ? Icons.bookmark : Icons.bookmark_border,
              ),
              title: Text(bookmarked ? 'Remove bookmark' : 'Bookmark'),
              onTap: () {
                notifier.toggleBookmark(key);
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              leading: const Icon(Icons.sticky_note_2_outlined),
              title: Text(hasNote ? 'Edit note' : 'Add note'),
              onTap: () {
                Navigator.of(context).pop();
                showNoteEditor(host, key);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy_outlined),
              title: const Text('Copy'),
              onTap: () {
                Clipboard.setData(
                  ClipboardData(
                    text: '${verse.text}\n'
                        '$title (${translation.abbreviation})',
                  ),
                );
                Navigator.of(context).pop();
                ScaffoldMessenger.of(host).showSnackBar(
                  const SnackBar(content: Text('Copied')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
