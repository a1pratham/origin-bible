import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:origin_bible/app.dart';
import 'package:origin_bible/core/storage/user_data.dart';
import 'package:origin_bible/core/storage/user_data_providers.dart';
import 'package:origin_bible/features/bible/application/recent_chapters.dart';

void main() {
  group('RecentChaptersNotifier', () {
    test('newest first, no duplicates, saved to the store', () {
      final store = InMemoryUserDataStore();
      final container = ProviderContainer(
        overrides: [userDataStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);
      final notifier = container.read(recentChaptersProvider.notifier);

      notifier
        ..record('GEN', 1)
        ..record('JHN', 3)
        ..record('GEN', 1);

      final recents = container.read(recentChaptersProvider);
      expect(recents.map((r) => '${r.bookCode} ${r.chapter}').toList(), [
        'GEN 1',
        'JHN 3',
      ]);
      expect(store.recents.length, 2);
    });

    test('keeps at most $kMaxRecentChapters entries', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(recentChaptersProvider.notifier);

      for (var i = 1; i <= 25; i++) {
        notifier.record('PSA', i);
      }

      final recents = container.read(recentChaptersProvider);
      expect(recents.length, kMaxRecentChapters);
      expect(recents.first.chapter, 25);
    });
  });

  testWidgets('saved settings are applied on startup', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          initialPreferencesProvider.overrideWithValue(
            const UserPreferences(themeMode: ThemeMode.dark),
          ),
        ],
        child: const OriginBibleApp(),
      ),
    );
    await tester.pumpAndSettle();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
  });

  testWidgets('changing a setting saves it', (tester) async {
    final store = InMemoryUserDataStore();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [userDataStoreProvider.overrideWithValue(store)],
        child: const OriginBibleApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profile').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    expect(store.preferences.themeMode, ThemeMode.dark);
  });

  testWidgets('Bible tab shows Continue reading from saved recents',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          initialRecentsProvider.overrideWithValue([
            RecentChapter(
              bookCode: 'JHN',
              chapter: 3,
              openedAt: DateTime(2026, 10, 1),
            ),
          ]),
        ],
        child: const OriginBibleApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Bible').last);
    await tester.pumpAndSettle();

    expect(find.text('Continue reading'), findsOneWidget);
    expect(find.text('John 3'), findsOneWidget);
  });
}
