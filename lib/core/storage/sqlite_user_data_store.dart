import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'annotation_models.dart';
import 'user_data.dart';

/// Writable on-device database for user data. Separate from the read-only
/// Bible database so Bible updates can never touch it.
///
/// Schema history:
///   v1 (Phase 3): preferences, recent_chapters
///   v2 (Phase 4A): bookmarks, highlights, notes, reading_progress
///
/// Syncable tables follow SYNC_DESIGN.md: updated_at (UTC ms), deleted_at
/// (soft delete) and dirty (needs upload). Ids are deterministic ("JHN:3:16")
/// because there is at most one record per verse.
class SqliteUserDataStore implements UserDataStore {
  static const String _fileName = 'origin_user.db';
  static const int _schemaVersion = 2;
  static const Duration _timeout = Duration(seconds: 2);

  static const String _syncColumns = 'updated_at INTEGER NOT NULL, '
      'deleted_at INTEGER, dirty INTEGER NOT NULL DEFAULT 1';

  static const List<String> _v1Tables = [
    'CREATE TABLE preferences(key TEXT PRIMARY KEY, value TEXT NOT NULL)',
    'CREATE TABLE recent_chapters('
        'book_code TEXT NOT NULL, chapter INTEGER NOT NULL, '
        'opened_at INTEGER NOT NULL, PRIMARY KEY (book_code, chapter))',
  ];

  static const List<String> _v2Tables = [
    'CREATE TABLE bookmarks(id TEXT PRIMARY KEY, book_code TEXT NOT NULL, '
        'chapter INTEGER NOT NULL, verse INTEGER NOT NULL, $_syncColumns)',
    'CREATE TABLE highlights(id TEXT PRIMARY KEY, book_code TEXT NOT NULL, '
        'chapter INTEGER NOT NULL, verse INTEGER NOT NULL, '
        'color TEXT NOT NULL, $_syncColumns)',
    'CREATE TABLE notes(id TEXT PRIMARY KEY, book_code TEXT NOT NULL, '
        'chapter INTEGER NOT NULL, verse INTEGER NOT NULL, '
        'text TEXT NOT NULL, $_syncColumns)',
    'CREATE TABLE reading_progress(id TEXT PRIMARY KEY, '
        'book_code TEXT NOT NULL, chapter INTEGER NOT NULL, $_syncColumns)',
  ];

  Future<Database>? _opening;

  Future<Database> _open() async {
    final dir = await getDatabasesPath();
    return openDatabase(
      p.join(dir, _fileName),
      version: _schemaVersion,
      onCreate: (db, version) async {
        for (final sql in [..._v1Tables, ..._v2Tables]) {
          await db.execute(sql);
        }
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          for (final sql in _v2Tables) {
            await db.execute(sql);
          }
        }
      },
    );
  }

  /// Runs [body]; on any failure (or timeout) returns [fallback] instead of
  /// throwing, so a storage problem can never break the app.
  Future<T> _guard<T>(Future<T> Function(Database db) body, T fallback) async {
    try {
      final db = await (_opening ??= _open());
      return await body(db).timeout(_timeout);
    } catch (e) {
      debugPrint('User data store error: $e');
      _opening = null;
      return fallback;
    }
  }

  // ---- preferences ----

  @override
  Future<UserPreferences> loadPreferences() {
    return _guard<UserPreferences>(
      (db) async {
        final rows = await db.query('preferences');
        final map = {
          for (final r in rows) r['key']! as String: r['value']! as String,
        };
        return UserPreferences(
          themeMode: ThemeMode.values.asNameMap()[map['theme_mode']] ??
              ThemeMode.system,
          textScaleIndex: int.tryParse(map['text_scale_index'] ?? '') ?? 1,
          translationId: map['translation_id'] ?? 'web',
        );
      },
      const UserPreferences(),
    );
  }

  @override
  Future<void> savePreferences(UserPreferences preferences) {
    return _guard<void>(
      (db) async {
        final batch = db.batch();
        void put(String key, String value) => batch.insert(
              'preferences',
              {'key': key, 'value': value},
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
        put('theme_mode', preferences.themeMode.name);
        put('text_scale_index', '${preferences.textScaleIndex}');
        put('translation_id', preferences.translationId);
        await batch.commit(noResult: true);
      },
      null,
    );
  }

  // ---- recents ----

  @override
  Future<List<RecentChapter>> loadRecents() {
    return _guard<List<RecentChapter>>(
      (db) async {
        final rows = await db.query(
          'recent_chapters',
          orderBy: 'opened_at DESC',
          limit: kMaxRecentChapters,
        );
        return [
          for (final r in rows)
            RecentChapter(
              bookCode: r['book_code']! as String,
              chapter: r['chapter']! as int,
              openedAt: DateTime.fromMillisecondsSinceEpoch(
                r['opened_at']! as int,
              ),
            ),
        ];
      },
      const [],
    );
  }

  @override
  Future<void> saveRecent(RecentChapter recent) {
    return _guard<void>(
      (db) async {
        await db.insert(
          'recent_chapters',
          {
            'book_code': recent.bookCode,
            'chapter': recent.chapter,
            'opened_at': recent.openedAt.millisecondsSinceEpoch,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        await db.delete(
          'recent_chapters',
          where: 'rowid NOT IN (SELECT rowid FROM recent_chapters '
              'ORDER BY opened_at DESC LIMIT ?)',
          whereArgs: [kMaxRecentChapters],
        );
      },
      null,
    );
  }

  // ---- annotations ----

  static DateTime _time(Object? ms) =>
      DateTime.fromMillisecondsSinceEpoch(ms! as int);

  static VerseRef _verse(Map<String, Object?> r) => VerseRef(
        r['book_code']! as String,
        r['chapter']! as int,
        r['verse']! as int,
      );

  @override
  Future<UserAnnotations> loadAnnotations() {
    return _guard<UserAnnotations>(
      (db) async {
        const live = 'deleted_at IS NULL';
        final bookmarks = await db.query('bookmarks', where: live);
        final highlights = await db.query('highlights', where: live);
        final notes = await db.query('notes', where: live);
        final progress = await db.query('reading_progress', where: live);
        return UserAnnotations(
          bookmarks: {
            for (final r in bookmarks) _verse(r): _time(r['updated_at']),
          },
          highlights: {
            for (final r in highlights)
              _verse(r): Highlight(
                HighlightColor.values.asNameMap()[r['color']] ??
                    HighlightColor.yellow,
                _time(r['updated_at']),
              ),
          },
          notes: {
            for (final r in notes)
              _verse(r): Note(r['text']! as String, _time(r['updated_at'])),
          },
          readChapters: {
            for (final r in progress)
              chapterId(r['book_code']! as String, r['chapter']! as int),
          },
        );
      },
      const UserAnnotations(),
    );
  }

  Map<String, Object?> _row(VerseRef v, int ms) => {
        'id': v.id,
        'book_code': v.bookCode,
        'chapter': v.chapter,
        'verse': v.verse,
        'updated_at': ms,
        'deleted_at': null,
        'dirty': 1,
      };

  Future<void> _softDelete(Database db, String table, String id) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return db.update(
      table,
      {'deleted_at': now, 'updated_at': now, 'dirty': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> setBookmark(VerseRef verse, DateTime? at) {
    return _guard<void>(
      (db) async {
        if (at == null) {
          await _softDelete(db, 'bookmarks', verse.id);
        } else {
          await db.insert(
            'bookmarks',
            _row(verse, at.millisecondsSinceEpoch),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      },
      null,
    );
  }

  @override
  Future<void> setHighlight(VerseRef verse, Highlight? highlight) {
    return _guard<void>(
      (db) async {
        if (highlight == null) {
          await _softDelete(db, 'highlights', verse.id);
        } else {
          await db.insert(
            'highlights',
            {
              ..._row(verse, highlight.updatedAt.millisecondsSinceEpoch),
              'color': highlight.color.name,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      },
      null,
    );
  }

  @override
  Future<void> setNote(VerseRef verse, Note? note) {
    return _guard<void>(
      (db) async {
        if (note == null) {
          await _softDelete(db, 'notes', verse.id);
        } else {
          await db.insert(
            'notes',
            {
              ..._row(verse, note.updatedAt.millisecondsSinceEpoch),
              'text': note.text,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      },
      null,
    );
  }

  @override
  Future<void> markChapterRead(String bookCode, int chapter, DateTime at) {
    return _guard<void>(
      (db) async {
        await db.insert(
          'reading_progress',
          {
            'id': chapterId(bookCode, chapter),
            'book_code': bookCode,
            'chapter': chapter,
            'updated_at': at.millisecondsSinceEpoch,
            'deleted_at': null,
            'dirty': 1,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      },
      null,
    );
  }
}
