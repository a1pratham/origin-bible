import 'dart:async';

import 'package:origin_bible/core/auth/auth_service.dart';
import 'package:origin_bible/core/sync/sync_models.dart';
import 'package:origin_bible/core/sync/sync_remote.dart';

class _Row {
  _Row(this.seq, this.record);

  final int seq;
  final SyncRecord record;
}

/// In-memory server with the same rules as supabase/schema.sql
/// (last write wins, server-assigned order).
class FakeRemote implements SyncRemote {
  final Map<String, _Row> _rows = {};
  int _seq = 0;
  final List<List<SyncRecord>> pushes = [];
  int pulls = 0;
  Object? failWith;

  List<SyncRecord> get stored => _rows.values.map((r) => r.record).toList();

  SyncRecord? find(SyncKind kind, String id) =>
      _rows['${kind.name}|$id']?.record;

  void seed(SyncRecord record) {
    _rows[record.key] = _Row(++_seq, record.copyWith(dirty: false));
  }

  @override
  Future<void> push(String userId, List<SyncRecord> records) async {
    if (failWith != null) throw failWith!;
    pushes.add(records);
    for (final r in records) {
      final existing = _rows[r.key];
      if (existing != null && !r.updatedAt.isAfter(existing.record.updatedAt)) {
        continue;
      }
      _rows[r.key] = _Row(++_seq, r.copyWith(dirty: false));
    }
  }

  @override
  Future<SyncPage> pull({String? cursor, required int limit}) async {
    pulls++;
    if (failWith != null) throw failWith!;
    final min = cursor == null ? 0 : int.parse(cursor);
    final rows = _rows.values.where((r) => r.seq >= min).toList()
      ..sort((a, b) => a.seq.compareTo(b.seq));
    final page = rows.take(limit).toList();
    return SyncPage(
      [for (final r in page) r.record],
      page.isEmpty ? cursor : '${page.last.seq}',
    );
  }
}

class FakeAuth implements AuthService {
  FakeAuth({AuthUser? user}) : _user = user;

  AuthUser? _user;
  final StreamController<AuthUser?> _changes =
      StreamController<AuthUser?>.broadcast();
  int signInCalls = 0;
  bool signedOut = false;
  bool deleted = false;

  void emit(AuthUser? user) {
    _user = user;
    _changes.add(user);
  }

  @override
  bool get isConfigured => true;

  @override
  AuthUser? get currentUser => _user;

  @override
  Stream<AuthUser?> get userChanges => _changes.stream;

  @override
  Stream<void> get passwordRecoveryEvents => const Stream.empty();

  @override
  Future<SignUpOutcome> signUpWithEmail(String email, String password) async =>
      SignUpOutcome.confirmationRequired;

  @override
  Future<void> signInWithEmail(String email, String password) async {
    signInCalls++;
    emit(AuthUser(id: 'u1', email: email));
  }

  @override
  Future<void> signInWithGoogle() async {}

  @override
  Future<void> sendPasswordReset(String email) async {}

  @override
  Future<void> updatePassword(String newPassword) async {}

  @override
  Future<void> signOut() async {
    signedOut = true;
    emit(null);
  }

  @override
  Future<void> deleteAccount() async {
    deleted = true;
    emit(null);
  }
}
