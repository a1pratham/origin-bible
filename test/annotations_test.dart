import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:origin_bible/app.dart';
import 'package:origin_bible/core/storage/annotation_models.dart';
import 'package:origin_bible/core/storage/user_data.dart';
import 'package:origin_bible/core/storage/user_data_providers.dart';
import 'package:origin_bible/features/annotations/application/annotations_provider.dart';
import 'package:origin_bible/features/bible/application/bible_providers.dart';
import 'package:origin_bible/features/bible/data/bible_repository.dart';
import 'package:origin_bible/features/bible/data/verse.dart';

/// Placeholder text only (not Scripture); never touches the real database.
class _FakeRepository implements BibleRepository {
  @override
  Future<List<Verse>> chapter({
    required String translationId,
    required String bookCode,
    required int chapter,
  }) async {
    return [
      Verse(bookCode: bookCode, chapter: chapter, verse: 1, text: 'Test one.'),
      Verse(bookCode: bookCode, chapter: chapter, verse: 2, text: 'Test two.'),
    ];
  }

  @override
  Future<List<Verse>> search({
    required String translationId,
    required String query,
    int limit = 100,
  }) async =>
      const [];
}

const _gen11 = VerseRef('GEN', 1, 1);

Future<void> _openGenesis1(
  WidgetTester tester,
  InMemoryUserDataStore store, {
  List<Override> extra = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        bibleRepositoryProvider.overrideWithValue(_FakeRepository()),
        userDataStoreProvider.overrideWithValue(store),
        ...extra,
      ],
      child: const OriginBibleApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Bible').last);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Genesis'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('1'));
  await tester.pumpAndSettle();
}

void main() {
  group('AnnotationsNotifier', () {
    late InMemoryUserDataStore store;
    late ProviderContainer container;

    setUp(() {
      store = InMemoryUserDataStore();
      container = ProviderContainer(
        overrides: [userDataStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);
    });

    AnnotationsNotifier notifier() =>
        container.read(annotationsProvider.notifier);
    UserAnnotations state() => container.read(annotationsProvider);

    test('bookmark toggles on and off and is saved', () {
      notifier().toggleBookmark(_gen11);
      expect(state().bookmarks.containsKey(_gen11), isTrue);
      expect(store.bookmarks.containsKey(_gen11), isTrue);

      notifier().toggleBookmark(_gen11);
      expect(state().bookmarks, isEmpty);
      expect(store.bookmarks, isEmpty);
    });

    test('highlight can be set, changed and cleared', () {
      notifier().setHighlight(_gen11, HighlightColor.green);
      expect(state().highlights[_gen11]!.color, HighlightColor.green);
      notifier().setHighlight(_gen11, HighlightColor.pink);
      expect(store.highlights[_gen11]!.color, HighlightColor.pink);
      notifier().setHighlight(_gen11, null);
      expect(state().highlights, isEmpty);
    });

    test('note is trimmed, and blank text removes it', () {
      notifier().setNote(_gen11, '  hello  ');
      expect(state().notes[_gen11]!.text, 'hello');
      expect(store.notes[_gen11]!.text, 'hello');
      notifier().setNote(_gen11, '   ');
      expect(state().notes, isEmpty);
      expect(store.notes, isEmpty);
    });

    test('note longer than the limit is clipped', () {
      notifier().setNote(_gen11, 'a' * (kMaxNoteLength + 50));
      expect(state().notes[_gen11]!.text.length, kMaxNoteLength);
    });

    test('markRead is idempotent', () {
      notifier()
        ..markRead('JHN', 3)
        ..markRead('JHN', 3);
      expect(state().readChapters, {'JHN:3'});
      expect(store.readChapters, {'JHN:3'});
    });
  });

  testWidgets('bookmark from the reader appears in Saved', (tester) async {
    final store = InMemoryUserDataStore();
    await _openGenesis1(tester, store);

    await tester.tap(find.textContaining('Test one.'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bookmark'));
    await tester.pumpAndSettle();
    expect(store.bookmarks.containsKey(_gen11), isTrue);

    await tester.tap(find.text('Saved').last);
    await tester.pumpAndSettle();
    expect(find.text('Genesis 1:1'), findsOneWidget);
  });

  testWidgets('highlight color is saved', (tester) async {
    final store = InMemoryUserDataStore();
    await _openGenesis1(tester, store);

    await tester.tap(find.textContaining('Test one.'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Highlight yellow'));
    await tester.pumpAndSettle();

    expect(store.highlights[_gen11]!.color, HighlightColor.yellow);
  });

  testWidgets('note from the reader appears in Saved > Notes', (tester) async {
    final store = InMemoryUserDataStore();
    await _openGenesis1(tester, store);

    await tester.tap(find.textContaining('Test one.'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add note'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'my note');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(store.notes[_gen11]!.text, 'my note');

    await tester.tap(find.text('Saved').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Notes'));
    await tester.pumpAndSettle();
    expect(find.text('my note'), findsOneWidget);
  });

  testWidgets('a chapter is marked read after the dwell time', (tester) async {
    final store = InMemoryUserDataStore();
    await _openGenesis1(tester, store);
    expect(store.readChapters, isEmpty);

    await tester.pump(const Duration(seconds: 4));
    expect(store.readChapters, {'GEN:1'});
  });

  testWidgets('Bible tab shows reading progress per book', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          initialAnnotationsProvider.overrideWithValue(
            const UserAnnotations(readChapters: {'GEN:1'}),
          ),
        ],
        child: const OriginBibleApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bible').last);
    await tester.pumpAndSettle();

    expect(find.text('1 of 50 chapters read'), findsOneWidget);
  });
}
