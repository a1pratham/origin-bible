import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/annotation_models.dart';
import '../../../core/storage/user_data.dart';
import '../../../core/storage/user_data_providers.dart';

/// Bookmarks, highlights, notes and reading progress. The in-memory state
/// drives the UI instantly; saving to the device database happens in the
/// background and can never block or break the UI.
class AnnotationsNotifier extends Notifier<UserAnnotations> {
  @override
  UserAnnotations build() => ref.read(initialAnnotationsProvider);

  UserDataStore get _store => ref.read(userDataStoreProvider);

  void toggleBookmark(VerseRef verse) {
    final bookmarks = Map<VerseRef, DateTime>.of(state.bookmarks);
    DateTime? at;
    if (bookmarks.containsKey(verse)) {
      bookmarks.remove(verse);
    } else {
      at = DateTime.now();
      bookmarks[verse] = at;
    }
    state = state.copyWith(bookmarks: bookmarks);
    unawaited(_store.setBookmark(verse, at));
  }

  /// Passing null (or the color already set) clears the highlight.
  void setHighlight(VerseRef verse, HighlightColor? color) {
    final highlights = Map<VerseRef, Highlight>.of(state.highlights);
    Highlight? value;
    if (color == null) {
      highlights.remove(verse);
    } else {
      value = Highlight(color, DateTime.now());
      highlights[verse] = value;
    }
    state = state.copyWith(highlights: highlights);
    unawaited(_store.setHighlight(verse, value));
  }

  /// Blank text removes the note.
  void setNote(VerseRef verse, String? text) {
    final trimmed = text?.trim() ?? '';
    final notes = Map<VerseRef, Note>.of(state.notes);
    Note? value;
    if (trimmed.isEmpty) {
      notes.remove(verse);
    } else {
      final clipped = trimmed.length > kMaxNoteLength
          ? trimmed.substring(0, kMaxNoteLength)
          : trimmed;
      value = Note(clipped, DateTime.now());
      notes[verse] = value;
    }
    state = state.copyWith(notes: notes);
    unawaited(_store.setNote(verse, value));
  }

  void markRead(String bookCode, int chapter) {
    final id = chapterId(bookCode, chapter);
    if (state.readChapters.contains(id)) return;
    state = state.copyWith(readChapters: {...state.readChapters, id});
    unawaited(_store.markChapterRead(bookCode, chapter, DateTime.now()));
  }
}

final annotationsProvider =
    NotifierProvider<AnnotationsNotifier, UserAnnotations>(
  AnnotationsNotifier.new,
);
