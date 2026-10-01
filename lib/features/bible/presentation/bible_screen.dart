import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_spacing.dart';
import '../application/bible_providers.dart';
import '../data/bible_books.dart';
import '../data/translations.dart';
import 'translation_picker.dart';

class BibleScreen extends ConsumerWidget {
  const BibleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final translation = translationById(ref.watch(selectedTranslationProvider));
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
          const _SectionHeader('Old Testament'),
          for (final b in oldBooks) _BookTile(book: b),
          const _SectionHeader('New Testament'),
          for (final b in newBooks) _BookTile(book: b),
          const SizedBox(height: AppSpacing.lg),
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
  const _BookTile({required this.book});

  final BibleBook book;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(book.name),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => book.chapters == 1
          ? context.push('/bible/read/${book.code}/1')
          : context.push('/bible/book/${book.code}'),
    );
  }
}
