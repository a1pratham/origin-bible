import 'package:flutter/foundation.dart';

const int kMaxNoteLength = 10000;

/// A single verse, independent of translation (so bookmarks and notes
/// survive a translation change). Also used as the natural sync key.
@immutable
class VerseRef {
  const VerseRef(this.bookCode, this.chapter, this.verse);

  final String bookCode;
  final int chapter;
  final int verse;

  /// Deterministic record id, e.g. "JHN:3:16".
  String get id => '$bookCode:$chapter:$verse';

  @override
  bool operator ==(Object other) =>
      other is VerseRef &&
      other.bookCode == bookCode &&
      other.chapter == chapter &&
      other.verse == verse;

  @override
  int get hashCode => Object.hash(bookCode, chapter, verse);
}

String chapterId(String bookCode, int chapter) => '$bookCode:$chapter';

enum HighlightColor { yellow, green, blue, pink }

@immutable
class Highlight {
  const Highlight(this.color, this.updatedAt);

  final HighlightColor color;
  final DateTime updatedAt;
}

@immutable
class Note {
  const Note(this.text, this.updatedAt);

  final String text;
  final DateTime updatedAt;
}

/// Everything the user has created on top of the Bible text.
@immutable
class UserAnnotations {
  const UserAnnotations({
    this.bookmarks = const {},
    this.highlights = const {},
    this.notes = const {},
    this.readChapters = const {},
  });

  /// Verse -> when it was bookmarked.
  final Map<VerseRef, DateTime> bookmarks;
  final Map<VerseRef, Highlight> highlights;
  final Map<VerseRef, Note> notes;

  /// Chapter ids like "JHN:3".
  final Set<String> readChapters;

  UserAnnotations copyWith({
    Map<VerseRef, DateTime>? bookmarks,
    Map<VerseRef, Highlight>? highlights,
    Map<VerseRef, Note>? notes,
    Set<String>? readChapters,
  }) {
    return UserAnnotations(
      bookmarks: bookmarks ?? this.bookmarks,
      highlights: highlights ?? this.highlights,
      notes: notes ?? this.notes,
      readChapters: readChapters ?? this.readChapters,
    );
  }
}
