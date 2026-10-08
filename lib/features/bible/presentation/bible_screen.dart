import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_card.dart';
import '../../annotations/application/annotations_provider.dart';
import '../application/bible_providers.dart';
import '../application/recent_chapters.dart';
import '../data/bible_books.dart';
import '../data/translations.dart';
import 'translation_picker.dart';

class BibleScreen extends ConsumerWidget {
  const BibleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final translation = translationById(ref.watch(selectedTranslationProvider));
    final recents = ref
        .watch(recentChaptersProvider)
        .where((r) => bookByCode(r.bookCode) != null)
        .toList();

    final readByBook = <String, int>{};
    for (final id in ref.watch(
      annotationsProvider.select((a) => a.readChapters),
    )) {
      final code = id.split(':').first;
      readByBook[code] = (readByBook[code] ?? 0) + 1;
    }

    final oldBooks =
        kBibleBooks.where((b) => b.testament == Testament.oldTestament);
    final newBooks =
        kBibleBooks.where((b) => b.testament == Testament.newTestament);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bible'),
        actions: [
          TextButton.icon(
            onPressed: () => showTranslationPicker(context, ref),
            icon: const Icon(Icons.translate),
            label: Text(translation.abbreviation),
          ),
          IconButton(
            tooltip: 'Search',
            icon: const Icon(Icons.search),
            onPressed: () => context.push('/bible/search'),
          ),
        ],
      ),
      body: ListView(
        children: [
          if (recents.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                0,
              ),
              child: _ContinueCard(
                bookName: bookByCode(recents.first.bookCode)!.name,
                chapter: recents.first.chapter,
                onTap: () => context.push(
                  '/bible/read/${recents.first.bookCode}/${recents.first.chapter}',
                ),
              ),
            ),
            if (recents.length > 1) ...[
              const _SectionHeader('Recent'),
              for (final r in recents.skip(1).take(4))
                ListTile(
                  leading: const Icon(Icons.history),
                  title: Text('${bookByCode(r.bookCode)!.name} ${r.chapter}'),
                  onTap: () =>
                      context.push('/bible/read/${r.bookCode}/${r.chapter}'),
                ),
            ],
          ],
          const _SectionHeader('Old Testament'),
          for (final b in oldBooks)
            _BookTile(book: b, readCount: readByBook[b.code] ?? 0),
          const _SectionHeader('New Testament'),
          for (final b in newBooks)
            _BookTile(book: b, readCount: readByBook[b.code] ?? 0),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({
    required this.bookName,
    required this.chapter,
    required this.onTap,
  });

  final String bookName;
  final int chapter;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Icon(
            Icons.play_circle_outline,
            size: 32,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Continue reading', style: theme.textTheme.titleMedium),
                Text('$bookName $chapter', style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Semantics(
        header: true,
        child: Text(
          title,
          style: theme.textTheme.titleSmall
              ?.copyWith(color: theme.colorScheme.primary),
        ),
      ),
    );
  }
}

class _BookTile extends StatelessWidget {
  const _BookTile({required this.book, required this.readCount});

  final BibleBook book;
  final int readCount;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(book.name),
      subtitle: readCount > 0
          ? Text('$readCount of ${book.chapters} chapters read')
          : null,
      trailing: const Icon(Icons.chevron_right),
      onTap: () => book.chapters == 1
          ? context.push('/bible/read/${book.code}/1')
          : context.push('/bible/book/${book.code}'),
    );
  }
}
