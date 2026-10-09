import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../sync/sync_models.dart';
import '../sync/sync_store.dart';
import 'annotation_models.dart';
import 'user_data.dart';

/// Writable on-device database for user data. Separate from the read-only
/// Bible database so Bible updates can never touch it.
///
/// Schema history:
///   v1 (Phase 3): preferences, recent_chapters
///   v2 (Phase 4A): bookmarks, highlights, notes, reading_progress
///   v3 (Phase 4B): sync_state
///
/// Syncable tables follow SYNC_DESIGN.md: updated_at (UTC ms), deleted_at
/// (soft delete) and dirty (needs upload). Ids are deterministic ("JHN:3:16")
/// because there is at most one record per verse.
class SqliteUserDataStore implements UserDataStore, SyncStore {
  static const String _fileName = 'origin_user.db';
  static const int _schemaVersion = 3;
  static const Duration _timeout = Duration(seconds: 2);
  static const Duration _longTimeout = Duration(seconds: 15);

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

  static const List<String> _v3Tables = [
    'CREATE TABLE sync_state(key TEXT PRIMARY KEY, value TEXT NOT NULL)',
  ];

  static const Map<SyncKind, String> _tables = {
    SyncKind.bookmark: 'bookmarks',
    SyncKind.highlight: 'highlights',
    SyncKind.note: 'notes',
    SyncKind.progress: 'reading_progress',
  };

  Future<Database>? _opening;

  Future<Database> _open() async {
    final dir = await getDatabasesPath();
    return openDatabase(
      p.join(dir, _fileName),
      version: _schemaVersion,
      onCreate: (db, version) async {
        for (final sql in [..._v1Tables, ..._v2Tables, ..._v3Tables]) {
          await db.execute(sql);
        }
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          for (final sql in _v2Tables) {
            await db.execute(sql);
          }
        }
        if (oldVersion < 3) {
          for (final sql in _v3Tables) {
            await db.execute(sql);
          }
        }
      },
    );
  }

  /// Runs [body]; on any failure (or timeout) returns [fallback] instead of
  /// throwing, so a storage problem can never break the app.
  Future<T> _guard<T>(
    Future<T> Function(Database db) body,
    T fallback, {
    Duration? timeout,
  }) async {
    try {
      final db = await (_opening ??= _open());
      return await body(db).timeout(timeout ?? _timeout);
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

  @override
  Future<void> clearAnnotations() {
    return _guard<void>(
      (db) async {
        await db.transaction((txn) async {
          for (final table in _tables.values) {
            await txn.delete(table);
          }
        });
      },
      null,
    );
  }

  // ---- sync ----

  static DateTime _utc(Object? ms) =>
      DateTime.fromMillisecondsSinceEpoch(ms! as int, isUtc: true);

  static SyncRecord _toRecord(SyncKind kind, Map<String, Object?> r) {
    final deleted = r['deleted_at'];
    return SyncRecord(
      kind: kind,
      id: r['id']! as String,
      bookCode: r['book_code']! as String,
      chapter: r['chapter']! as int,
      verse: kind == SyncKind.progress ? 0 : r['verse']! as int,
      color: kind == SyncKind.highlight ? r['color'] as String? : null,
      body: kind == SyncKind.note ? r['text'] as String? : null,
      updatedAt: _utc(r['updated_at']),
      deletedAt: deleted == null ? null : _utc(deleted),
      dirty: (r['dirty'] as int?) == 1,
    );
  }

  static Map<String, Object?> _toRow(SyncRecord s) => {
        'id': s.id,
        'book_code': s.bookCode,
        'chapter': s.chapter,
        if (s.kind != SyncKind.progress) 'verse': s.verse,
        if (s.kind == SyncKind.highlight) 'color': s.color ?? 'yellow',
        if (s.kind == SyncKind.note) 'text': s.body ?? '',
        'updated_at': s.updatedAt.millisecondsSinceEpoch,
        'deleted_at': s.deletedAt?.millisecondsSinceEpoch,
        'dirty': s.dirty ? 1 : 0,
      };

  @override
  Future<List<SyncRecord>> dirtyRecords({int limit = 100}) {
    return _guard<List<SyncRecord>>(
      (db) async {
        final out = <SyncRecord>[];
        for (final e in _tables.entries) {
          if (out.length >= limit) break;
          final rows = await db.query(
            e.value,
            where: 'dirty = 1',
            limit: limit - out.length,
          );
          out.addAll(rows.map((r) => _toRecord(e.key, r)));
        }
        return out;
      },
      const [],
      timeout: _longTimeout,
    );
  }

  @override
  Future<int> dirtyCount() {
    return _guard<int>(
      (db) async {
        var total = 0;
        for (final table in _tables.values) {
          total += Sqflite.firstIntValue(
                await db
                    .rawQuery('SELECT COUNT(*) FROM $table WHERE dirty = 1'),
              ) ??
              0;
        }
        return total;
      },
      0,
    );
  }

  @override
  Future<void> markPushed(List<SyncRecord> pushed) {
    return _guard<void>(
      (db) async {
        final batch = db.batch();
        for (final r in pushed) {
          batch.update(
            _tables[r.kind]!,
            {'dirty': 0},
            where: 'id = ? AND updated_at = ?',
            whereArgs: [r.id, r.updatedAt.millisecondsSinceEpoch],
          );
        }
        await batch.commit(noResult: true);
      },
      null,
      timeout: _longTimeout,
    );
  }

  @override
  Future<int> applyRemote(List<SyncRecord> remote) {
    return _guard<int>(
      (db) async {
        var changed = 0;
        final now = DateTime.now().toUtc();
        await db.transaction((txn) async {
          for (final incoming in remote) {
            final table = _tables[incoming.kind]!;
            final rows = await txn.query(
              table,
              where: 'id = ?',
              whereArgs: [incoming.id],
              limit: 1,
            );
            final local =
                rows.isEmpty ? null : _toRecord(incoming.kind, rows.first);
            final result = resolveConflict(local, incoming, now);
            if (result == null) continue;
            await txn.insert(
              table,
              _toRow(result),
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
            changed++;
          }
        });
        return changed;
      },
      0,
      timeout: _longTimeout,
    );
  }

  @override
  Future<String?> getState(String key) {
    return _guard<String?>(
      (db) async {
        final rows = await db.query(
          'sync_state',
          where: 'key = ?',
          whereArgs: [key],
          limit: 1,
        );
        return rows.isEmpty ? null : rows.first['value']! as String;
      },
      null,
    );
  }

  @override
  Future<void> setState(String key, String? value) {
    return _guard<void>(
      (db) async {
        if (value == null) {
          await db.delete('sync_state', where: 'key = ?', whereArgs: [key]);
        } else {
          await db.insert(
            'sync_state',
            {'key': key, 'value': value},
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      },
      null,
    );
  }

  @override
  Future<void> resetSyncState() {
    return _guard<void>(
      (db) async {
        await db.delete(
          'sync_state',
          where: 'key IN (?, ?, ?)',
          whereArgs: [kSyncOwnerKey, kSyncCursorKey, kLastSyncedKey],
        );
      },
      null,
    );
  }
}
