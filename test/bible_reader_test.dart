import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:origin_bible/app.dart';
import 'package:origin_bible/features/bible/application/bible_providers.dart';
import 'package:origin_bible/features/bible/data/bible_repository.dart';
import 'package:origin_bible/features/bible/data/verse.dart';
import 'package:flutter/material.dart';

/// Test double with placeholder text (not Scripture), so tests never touch
/// the real database or a licensed translation.
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
  }) async {
    return [
      const Verse(bookCode: 'GEN', chapter: 1, verse: 1, text: 'Test hit.'),
    ];
  }
}

void main() {
  testWidgets('Bible tab -> book -> chapter shows verses', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bibleRepositoryProvider.overrideWithValue(_FakeRepository()),
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

    expect(find.textContaining('Test one.'), findsOneWidget);
    expect(find.textContaining('World English Bible'), findsOneWidget);
  });

  testWidgets('search: keyword shows results, reference opens chapter',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bibleRepositoryProvider.overrideWithValue(_FakeRepository()),
        ],
        child: const OriginBibleApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bible').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Search').first);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'hello');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.textContaining('Test hit.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'john 3:16');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.textContaining('Test one.'), findsOneWidget);
  });
}
