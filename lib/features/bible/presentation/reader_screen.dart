import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/state_views.dart';
import '../application/bible_providers.dart';
import '../data/bible_books.dart';
import '../data/translations.dart';

class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({required this.code, required this.chapter, super.key});

  final String code;
  final int chapter;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  late final PageController _controller;
  late int _current;

  @override
  void initState() {
    super.initState();
    final book = bookByCode(widget.code);
    _current =
        book == null ? 1 : widget.chapter.clamp(1, book.chapters).toInt();
    _controller = PageController(initialPage: _current - 1);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final book = bookByCode(widget.code);
    if (book == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(
          icon: Icons.menu_book_outlined,
          title: 'Book not found',
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text('${book.name} $_current')),
      body: PageView.builder(
        controller: _controller,
        itemCount: book.chapters,
        onPageChanged: (i) => setState(() => _current = i + 1),
        itemBuilder: (context, i) =>
            _ChapterPage(bookCode: book.code, chapter: i + 1),
      ),
    );
  }
}

class _ChapterPage extends ConsumerWidget {
  const _ChapterPage({required this.bookCode, required this.chapter});

  final String bookCode;
  final int chapter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final translation = translationById(ref.watch(selectedTranslationProvider));
    final key = (translation.id, bookCode, chapter);
    final reading = Theme.of(context).extension<ReadingStyles>()!;

    return ref.watch(chapterVersesProvider(key)).when(
          loading: () => const LoadingView(label: 'Loading chapter'),
          error: (e, _) => ErrorState(
            title: 'Bible text unavailable',
            message: 'The Bible data could not be opened on this device.',
            onRetry: () => ref.invalidate(chapterVersesProvider(key)),
          ),
          data: (verses) {
            if (verses.isEmpty) {
              return const EmptyState(
                icon: Icons.menu_book_outlined,
                title: 'No text for this chapter',
              );
            }
            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  children: [
                    for (final v in verses)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: Text.rich(
                          TextSpan(
                            children: [
                              if (v.verse > 0)
                                TextSpan(
                                  text: '${v.verse} ',
                                  style: reading.verseNumber,
                                ),
                              TextSpan(
                                text: v.text,
                                style: v.verse == 0
                                    ? const TextStyle(
                                        fontStyle: FontStyle.italic,
                                      )
                                    : null,
                              ),
                            ],
                          ),
                          style: reading.verse,
                        ),
                      ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      '${translation.name} (${translation.abbreviation}) · '
                      '${translation.license}',
                      style: reading.reference,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
            );
          },
        );
  }
}
