import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/storage/annotation_models.dart';
import '../../../shared/widgets/state_views.dart';
import '../../annotations/application/annotations_provider.dart';
import '../../annotations/presentation/highlight_colors.dart';
import '../../annotations/presentation/verse_labels.dart';
import '../../bible/application/bible_providers.dart';

class SavedScreen extends ConsumerWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = ref.watch(annotationsProvider);
    final notifier = ref.read(annotationsProvider.notifier);

    final bookmarks = a.bookmarks.entries.toList()
      ..sort((x, y) => y.value.compareTo(x.value));
    final highlights = a.highlights.entries.toList()
      ..sort((x, y) => y.value.updatedAt.compareTo(x.value.updatedAt));
    final notes = a.notes.entries.toList()
      ..sort((x, y) => y.value.updatedAt.compareTo(x.value.updatedAt));

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Saved'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Bookmarks'),
              Tab(text: 'Highlights'),
              Tab(text: 'Notes'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _SavedList(
              emptyIcon: Icons.bookmark_border,
              emptyTitle: 'No bookmarks yet',
              emptyMessage: 'Tap a verse while reading, then choose Bookmark.',
              children: [
                for (final e in bookmarks)
                  _SavedTile(
                    verse: e.key,
                    trailing: IconButton(
                      tooltip: 'Remove bookmark',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => notifier.toggleBookmark(e.key),
                    ),
                  ),
              ],
            ),
            _SavedList(
              emptyIcon: Icons.brush_outlined,
              emptyTitle: 'No highlights yet',
              emptyMessage: 'Tap a verse while reading, then pick a color.',
              children: [
                for (final e in highlights)
                  _SavedTile(
                    verse: e.key,
                    leading: Icon(
                      Icons.circle,
                      color: highlightSwatch(e.value.color),
                    ),
                    trailing: IconButton(
                      tooltip: 'Remove highlight',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => notifier.setHighlight(e.key, null),
                    ),
                  ),
              ],
            ),
            _SavedList(
              emptyIcon: Icons.sticky_note_2_outlined,
              emptyTitle: 'No notes yet',
              emptyMessage: 'Tap a verse while reading, then choose Add note.',
              children: [
                for (final e in notes)
                  _SavedTile(
                    verse: e.key,
                    note: e.value.text,
                    trailing: IconButton(
                      tooltip: 'Delete note',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => notifier.setNote(e.key, null),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SavedList extends StatelessWidget {
  const _SavedList({
    required this.children,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptyMessage,
  });

  final List<Widget> children;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) {
      return EmptyState(
        icon: emptyIcon,
        title: emptyTitle,
        message: emptyMessage,
      );
    }
    return ListView.separated(
      itemCount: children.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) => children[i],
    );
  }
}

class _SavedTile extends ConsumerWidget {
  const _SavedTile({
    required this.verse,
    required this.trailing,
    this.leading,
    this.note,
  });

  final VerseRef verse;
  final Widget trailing;
  final Widget? leading;
  final String? note;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final translationId = ref.watch(selectedTranslationProvider);
    // Verse text comes from the local Bible database (cached per chapter).
    final text = ref
        .watch(
      chapterVersesProvider((translationId, verse.bookCode, verse.chapter)),
    )
        .whenOrNull(
      data: (verses) {
        for (final v in verses) {
          if (v.verse == verse.verse) return v.text;
        }
        return null;
      },
    );

    return ListTile(
      leading: leading,
      title: Text(verseTitle(verse)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (note != null)
            Text(note!, maxLines: 3, overflow: TextOverflow.ellipsis),
          if (text != null)
            Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: note != null
                  ? const TextStyle(fontStyle: FontStyle.italic)
                  : null,
            ),
        ],
      ),
      trailing: trailing,
      // go() switches to the Bible tab and builds the back stack properly.
      onTap: () => context.go('/bible/read/${verse.bookCode}/${verse.chapter}'),
    );
  }
}
