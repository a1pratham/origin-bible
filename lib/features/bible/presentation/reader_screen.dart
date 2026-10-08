import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/state_views.dart';
import '../../annotations/application/annotations_provider.dart';
import '../../annotations/presentation/verse_tile.dart';
import '../application/bible_providers.dart';
import '../application/recent_chapters.dart';
import '../data/bible_books.dart';
import '../data/translations.dart';

/// A chapter counts as "read" after it has been on screen this long, so
/// flipping quickly through chapters does not mark them.
const Duration kReadDwell = Duration(seconds: 3);

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
  Timer? _readTimer;

  @override
  void initState() {
    super.initState();
    final book = bookByCode(widget.code);
    _current =
        book == null ? 1 : widget.chapter.clamp(1, book.chapters).toInt();
    _controller = PageController(initialPage: _current - 1);
    if (book != null) {
      // Providers must not be modified while the tree is building.
      Future<void>.microtask(_recordCurrent);
      _scheduleRead();
    }
  }

  void _recordCurrent() {
    if (!mounted) return;
    ref.read(recentChaptersProvider.notifier).record(widget.code, _current);
  }

  void _scheduleRead() {
    _readTimer?.cancel();
    final chapter = _current;
    _readTimer = Timer(kReadDwell, () {
      if (!mounted) return;
      ref.read(annotationsProvider.notifier).markRead(widget.code, chapter);
    });
  }

  @override
  void dispose() {
    _readTimer?.cancel();
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
        onPageChanged: (i) {
          setState(() => _current = i + 1);
          _recordCurrent();
          _scheduleRead();
        },
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
                      VerseTile(verse: v, translation: translation),
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
