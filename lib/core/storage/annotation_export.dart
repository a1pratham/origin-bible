import 'dart:convert';

import 'annotation_models.dart';

/// A readable JSON copy of everything the user created (data export).
String exportAnnotationsJson(UserAnnotations a, {DateTime? now}) {
  String time(DateTime t) => t.toUtc().toIso8601String();
  final data = <String, Object?>{
    'app': 'Origin Bible',
    'exportedAt': time(now ?? DateTime.now()),
    'bookmarks': [
      for (final e in a.bookmarks.entries)
        {'verse': e.key.id, 'at': time(e.value)},
    ],
    'highlights': [
      for (final e in a.highlights.entries)
        {
          'verse': e.key.id,
          'color': e.value.color.name,
          'at': time(e.value.updatedAt),
        },
    ],
    'notes': [
      for (final e in a.notes.entries)
        {
          'verse': e.key.id,
          'text': e.value.text,
          'at': time(e.value.updatedAt),
        },
    ],
    'chaptersRead': a.readChapters.toList()..sort(),
  };
  return const JsonEncoder.withIndent('  ').convert(data);
}
