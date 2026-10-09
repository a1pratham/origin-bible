import 'package:supabase_flutter/supabase_flutter.dart';

import 'sync_models.dart';
import 'sync_remote.dart';

/// Talks to the single `sync_items` table (see supabase/schema.sql). Row
/// Level Security makes sure each user only ever sees their own rows.
class SupabaseSyncRemote implements SyncRemote {
  SupabaseSyncRemote(this._client);

  final SupabaseClient _client;

  static const String _table = 'sync_items';
  static const String _columns = 'kind,id,book_code,chapter,verse,color,body,'
      'client_updated_at,deleted_at,server_updated_at';

  @override
  Future<void> push(String userId, List<SyncRecord> records) async {
    if (records.isEmpty) return;
    await _client.from(_table).upsert(
      [for (final r in records) r.toRemoteJson(userId)],
      onConflict: 'user_id,kind,id',
    );
  }

  @override
  Future<SyncPage> pull({String? cursor, required int limit}) async {
    var query = _client.from(_table).select(_columns);
    if (cursor != null) {
      // Normalized to "...Z" so the "+" of a "+00:00" offset never has to be
      // URL-encoded.
      query = query.gte(
        'server_updated_at',
        DateTime.parse(cursor).toUtc().toIso8601String(),
      );
    }
    final rows =
        await query.order('server_updated_at', ascending: true).limit(limit);

    final records = <SyncRecord>[];
    for (final row in rows) {
      final record = SyncRecord.tryFromRemote(row);
      if (record != null) records.add(record);
    }
    final next = rows.isEmpty
        ? cursor
        : DateTime.parse(rows.last['server_updated_at'] as String)
            .toUtc()
            .toIso8601String();
    return SyncPage(records, next);
  }
}
