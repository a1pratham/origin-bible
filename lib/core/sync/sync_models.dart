import 'package:flutter/foundation.dart';

import '../storage/annotation_models.dart';

enum SyncKind { bookmark, highlight, note, progress }

/// One syncable item in a neutral shape shared by the device database, the
/// sync engine and the server.
@immutable
class SyncRecord {
  const SyncRecord({
    required this.kind,
    required this.id,
    required this.bookCode,
    required this.chapter,
    required this.verse,
    required this.updatedAt,
    this.color,
    this.body,
    this.deletedAt,
    this.dirty = false,
  });

  final SyncKind kind;

  /// "JHN:3:16" (verse items) or "JHN:3" (progress).
  final String id;
  final String bookCode;
  final int chapter;

  /// 0 for progress items.
  final int verse;
  final String? color;
  final String? body;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  /// True when this device has changes the server has not seen.
  final bool dirty;

  bool get isDeleted => deletedAt != null;
  String get key => '${kind.name}|$id';

  SyncRecord copyWith({bool? dirty}) {
    return SyncRecord(
      kind: kind,
      id: id,
      bookCode: bookCode,
      chapter: chapter,
      verse: verse,
      updatedAt: updatedAt,
      color: color,
      body: body,
      deletedAt: deletedAt,
      dirty: dirty ?? this.dirty,
    );
  }

  Map<String, Object?> toRemoteJson(String userId) => {
        'user_id': userId,
        'kind': kind.name,
        'id': id,
        'book_code': bookCode,
        'chapter': chapter,
        'verse': verse,
        'color': color,
        'body': body,
        'client_updated_at': updatedAt.toUtc().toIso8601String(),
        'deleted_at': deletedAt?.toUtc().toIso8601String(),
      };

  /// Returns null for rows this app version does not understand.
  static SyncRecord? tryFromRemote(Map<String, dynamic> json) {
    try {
      final kind = SyncKind.values.asNameMap()[json['kind']];
      if (kind == null) return null;
      final deleted = json['deleted_at'] as String?;
      return SyncRecord(
        kind: kind,
        id: json['id'] as String,
        bookCode: json['book_code'] as String,
        chapter: json['chapter'] as int,
        verse: json['verse'] as int,
        color: json['color'] as String?,
        body: json['body'] as String?,
        updatedAt: DateTime.parse(json['client_updated_at'] as String).toUtc(),
        deletedAt: deleted == null ? null : DateTime.parse(deleted).toUtc(),
      );
    } catch (_) {
      return null;
    }
  }
}

/// Decides what to store locally when [remote] arrives and [local] may exist.
/// Returns the record to write, or null to keep [local] unchanged.
///
/// Rules (see docs/SYNC_DESIGN.md):
/// - nothing local: take remote
/// - local has no unsent changes: take remote if it is newer
/// - local has unsent changes: newer timestamp wins, except two different
///   live notes are merged so no text is silently lost
SyncRecord? resolveConflict(
  SyncRecord? local,
  SyncRecord remote,
  DateTime now,
) {
  if (local == null) return remote;

  if (!local.dirty) {
    return remote.updatedAt.isAfter(local.updatedAt) ? remote : null;
  }

  final bothLiveNotes = local.kind == SyncKind.note &&
      !local.isDeleted &&
      !remote.isDeleted &&
      local.body != remote.body;
  if (bothLiveNotes) {
    final remoteIsNewer = !local.updatedAt.isAfter(remote.updatedAt);
    final newer = remoteIsNewer ? remote.body : local.body;
    final older = remoteIsNewer ? local.body : remote.body;
    var merged = '$newer\n\n---\n$older';
    if (merged.length > kMaxNoteLength) {
      merged = merged.substring(0, kMaxNoteLength);
    }
    return SyncRecord(
      kind: local.kind,
      id: local.id,
      bookCode: local.bookCode,
      chapter: local.chapter,
      verse: local.verse,
      body: merged,
      updatedAt: now,
      dirty: true,
    );
  }

  return remote.updatedAt.isAfter(local.updatedAt) ? remote : null;
}
