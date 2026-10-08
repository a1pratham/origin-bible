import 'package:flutter/material.dart' show ThemeMode;

import 'annotation_models.dart';

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

  Future<UserAnnotations> loadAnnotations();

  /// [at] == null removes the bookmark.
  Future<void> setBookmark(VerseRef verse, DateTime? at);

  /// [highlight] == null removes the highlight.
  Future<void> setHighlight(VerseRef verse, Highlight? highlight);

  /// [note] == null removes the note.
  Future<void> setNote(VerseRef verse, Note? note);

  Future<void> markChapterRead(String bookCode, int chapter, DateTime at);
}

const int kMaxRecentChapters = 20;

/// Default store (used in tests and as a fallback). Nothing is persisted.
class InMemoryUserDataStore implements UserDataStore {
  UserPreferences preferences = const UserPreferences();
  final List<RecentChapter> recents = [];
  final Map<VerseRef, DateTime> bookmarks = {};
  final Map<VerseRef, Highlight> highlights = {};
  final Map<VerseRef, Note> notes = {};
  final Set<String> readChapters = {};

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

  @override
  Future<UserAnnotations> loadAnnotations() async => UserAnnotations(
        bookmarks: Map.of(bookmarks),
        highlights: Map.of(highlights),
        notes: Map.of(notes),
        readChapters: Set.of(readChapters),
      );

  @override
  Future<void> setBookmark(VerseRef verse, DateTime? at) async {
    if (at == null) {
      bookmarks.remove(verse);
    } else {
      bookmarks[verse] = at;
    }
  }

  @override
  Future<void> setHighlight(VerseRef verse, Highlight? highlight) async {
    if (highlight == null) {
      highlights.remove(verse);
    } else {
      highlights[verse] = highlight;
    }
  }

  @override
  Future<void> setNote(VerseRef verse, Note? note) async {
    if (note == null) {
      notes.remove(verse);
    } else {
      notes[verse] = note;
    }
  }

  @override
  Future<void> markChapterRead(
    String bookCode,
    int chapter,
    DateTime at,
  ) async {
    readChapters.add(chapterId(bookCode, chapter));
  }
}
