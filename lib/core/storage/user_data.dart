import 'package:flutter/material.dart' show ThemeMode;

/// Settings that survive app restarts.
class UserPreferences {
  const UserPreferences({
    this.themeMode = ThemeMode.system,
    this.textScaleIndex = 1,
    this.translationId = 'web',
  });

  final ThemeMode themeMode;
  final int textScaleIndex;
  final String translationId;
}

class RecentChapter {
  const RecentChapter({
    required this.bookCode,
    required this.chapter,
    required this.openedAt,
  });

  final String bookCode;
  final int chapter;
  final DateTime openedAt;
}

/// Local storage for everything that belongs to the user (as opposed to the
/// read-only Bible text). Implementations must never throw: if storage is
/// broken the app keeps working with defaults and in-memory state.
abstract class UserDataStore {
  Future<UserPreferences> loadPreferences();
  Future<void> savePreferences(UserPreferences preferences);
  Future<List<RecentChapter>> loadRecents();
  Future<void> saveRecent(RecentChapter recent);
}

const int kMaxRecentChapters = 20;

/// Default store (used in tests and as a fallback). Nothing is persisted.
class InMemoryUserDataStore implements UserDataStore {
  UserPreferences preferences = const UserPreferences();
  final List<RecentChapter> recents = [];

  @override
  Future<UserPreferences> loadPreferences() async => preferences;

  @override
  Future<void> savePreferences(UserPreferences value) async {
    preferences = value;
  }

  @override
  Future<List<RecentChapter>> loadRecents() async => List.of(recents);

  @override
  Future<void> saveRecent(RecentChapter recent) async {
    recents
      ..removeWhere(
        (r) => r.bookCode == recent.bookCode && r.chapter == recent.chapter,
      )
      ..insert(0, recent);
    if (recents.length > kMaxRecentChapters) {
      recents.removeRange(kMaxRecentChapters, recents.length);
    }
  }
}
