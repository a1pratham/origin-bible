import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:origin_bible/core/auth/auth_providers.dart';
import 'package:origin_bible/core/auth/auth_service.dart';
import 'package:origin_bible/core/storage/annotation_export.dart';
import 'package:origin_bible/core/storage/annotation_models.dart';
import 'package:origin_bible/core/storage/user_data.dart';
import 'package:origin_bible/core/storage/user_data_providers.dart';
import 'package:origin_bible/core/sync/sync_controller.dart';
import 'package:origin_bible/core/sync/sync_engine.dart';
import 'package:origin_bible/core/sync/sync_models.dart';
import 'package:origin_bible/core/sync/sync_store.dart';
import 'package:origin_bible/features/annotations/application/annotations_provider.dart';

import 'support/fakes.dart';

final DateTime _t0 = DateTime.utc(2020, 1, 1, 12);

SyncRecord _note(
  String body,
  DateTime at, {
  bool dirty = false,
  DateTime? deletedAt,
}) {
  return SyncRecord(
    kind: SyncKind.note,
    id: 'JHN:3:16',
    bookCode: 'JHN',
    chapter: 3,
    verse: 16,
    body: body,
    updatedAt: at,
    deletedAt: deletedAt,
    dirty: dirty,
  );
}

SyncRecord _bookmark(String id, DateTime at, {bool dirty = false}) {
  final parts = id.split(':');
  return SyncRecord(
    kind: SyncKind.bookmark,
    id: id,
    bookCode: parts[0],
    chapter: int.parse(parts[1]),
    verse: int.parse(parts[2]),
    updatedAt: at,
    dirty: dirty,
  );
}

void main() {
  group('resolveConflict', () {
    final now = DateTime.utc(2020, 6, 1);

    test('takes remote when nothing is stored locally', () {
      final remote = _bookmark('JHN:3:16', _t0);
      expect(resolveConflict(null, remote, now), same(remote));
    });

    test('clean local: newer remote wins, older remote is ignored', () {
      final local = _bookmark('JHN:3:16', _t0);
      final newer = _bookmark('JHN:3:16', _t0.add(const Duration(hours: 1)));
      final older =
          _bookmark('JHN:3:16', _t0.subtract(const Duration(hours: 1)));
      expect(resolveConflict(local, newer, now), same(newer));
      expect(resolveConflict(local, older, now), isNull);
    });

    test('dirty local bookmark: the newer side wins', () {
      final local =
          _bookmark('JHN:3:16', _t0.add(const Duration(hours: 2)), dirty: true);
      final olderRemote = _bookmark('JHN:3:16', _t0);
      final newerRemote =
          _bookmark('JHN:3:16', _t0.add(const Duration(hours: 3)));
      expect(resolveConflict(local, olderRemote, now), isNull);
      expect(resolveConflict(local, newerRemote, now), same(newerRemote));
    });

    test('two different live notes are merged and kept dirty', () {
      final local = _note('mine', _t0, dirty: true);
      final remote = _note('theirs', _t0.add(const Duration(hours: 1)));
      final merged = resolveConflict(local, remote, now)!;
      expect(merged.body, contains('mine'));
      expect(merged.body, contains('theirs'));
      expect(merged.body!.startsWith('theirs'), isTrue); // newer text first
      expect(merged.dirty, isTrue);
      expect(merged.updatedAt, now);
    });

    test('identical note text is not merged', () {
      final local =
          _note('same', _t0.add(const Duration(hours: 1)), dirty: true);
      final remote = _note('same', _t0);
      expect(resolveConflict(local, remote, now), isNull);
    });

    test('a newer remote deletion beats an older local edit', () {
      final local = _note('mine', _t0, dirty: true);
      final remote = _note(
        '',
        _t0.add(const Duration(hours: 1)),
        deletedAt: _t0.add(const Duration(hours: 1)),
      );
      expect(resolveConflict(local, remote, now), same(remote));
    });
  });

  group('SyncEngine', () {
    late InMemorySyncStore store;
    late FakeRemote remote;
    late SyncEngine engine;

    setUp(() {
      store = InMemorySyncStore();
      remote = FakeRemote();
      engine = SyncEngine(
        store: store,
        remote: remote,
        pullBatch: 2,
        pushBatch: 2,
        maxBatchesPerRun: 2,
      );
    });

    test('pushes local changes and clears the unsent flag', () async {
      store.put(_bookmark('JHN:3:16', _t0, dirty: true));

      final result = await engine.run(userId: 'u1');

      expect(result.pushed, 1);
      expect(remote.stored.length, 1);
      expect(store.records.values.single.dirty, isFalse);
      expect(await store.getState(kSyncOwnerKey), 'u1');
      expect(await store.getState(kLastSyncedKey), isNotNull);
    });

    test('pulls items from other devices', () async {
      remote.seed(_bookmark('GEN:1:1', _t0));

      final result = await engine.run(userId: 'u1');

      expect(result.changedLocal, isTrue);
      expect(store.records.keys, contains('bookmark|GEN:1:1'));
      expect(store.records.values.single.dirty, isFalse);
    });

    test('merges a note edited on two devices before uploading', () async {
      store.put(_note('mine', _t0, dirty: true));
      remote.seed(_note('theirs', _t0.add(const Duration(hours: 1))));

      await engine.run(userId: 'u1');

      final local = store.records['note|JHN:3:16']!;
      expect(local.body, allOf(contains('mine'), contains('theirs')));
      expect(local.dirty, isFalse);
      final cloud = remote.find(SyncKind.note, 'JHN:3:16')!;
      expect(cloud.body, allOf(contains('mine'), contains('theirs')));
    });

    test('repeated runs with no changes are stable', () async {
      store.put(_bookmark('JHN:3:16', _t0, dirty: true));
      await engine.run(userId: 'u1');
      final second = await engine.run(userId: 'u1');

      expect(second.pushed, 0);
      expect(second.changedLocal, isFalse);
      expect(remote.stored.length, 1);
    });

    test('refuses to mix data from two accounts', () async {
      await store.setState(kSyncOwnerKey, 'someone-else');
      expect(
        () => engine.run(userId: 'u1'),
        throwsA(isA<SyncOwnerMismatch>()),
      );
    });

    test('a big backlog is spread over bounded runs', () async {
      for (var i = 1; i <= 5; i++) {
        remote.seed(_bookmark('GEN:1:$i', _t0));
      }

      var runs = 0;
      SyncRunResult result;
      do {
        result = await engine.run(userId: 'u1');
        runs++;
        // Each run makes at most 2 pull requests (maxBatchesPerRun).
        expect(result.requests, lessThanOrEqualTo(2));
      } while (result.hasMore && runs < 6);

      expect(store.records.length, 5);
      expect(runs, lessThan(6));
    });

    test('a failing server surfaces an error instead of looping', () async {
      remote.failWith = Exception('offline');
      await expectLater(engine.run(userId: 'u1'), throwsException);
      expect(remote.pulls, 1);
    });
  });

  group('SyncController', () {
    late FakeAuth auth;
    late FakeRemote remote;
    late InMemorySyncStore syncStore;
    late InMemoryUserDataStore userStore;
    late ProviderContainer container;

    ProviderContainer make({AuthUser? user}) {
      auth = FakeAuth(user: user);
      remote = FakeRemote();
      syncStore = InMemorySyncStore();
      userStore = InMemoryUserDataStore();
      final c = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(auth),
          syncRemoteProvider.overrideWithValue(remote),
          syncStoreProvider.overrideWithValue(syncStore),
          userDataStoreProvider.overrideWithValue(userStore),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('syncs right away when a user is already signed in', () async {
      container = make(user: const AuthUser(id: 'u1', email: 'a@b.c'));
      container.read(syncControllerProvider);
      await pumpEventQueue(times: 50);

      final state = container.read(syncControllerProvider);
      expect(state.status, SyncStatus.idle);
      expect(state.lastSyncedAt, isNotNull);
      expect(remote.pulls, 1);
    });

    test('does nothing while signed out', () async {
      container = make();
      container.read(syncControllerProvider);
      await pumpEventQueue(times: 50);

      expect(
        container.read(syncControllerProvider).status,
        SyncStatus.signedOut,
      );
      expect(remote.pulls, 0);
    });

    test('a failure shows "retrying" and does not hammer the server', () async {
      container = make(user: const AuthUser(id: 'u1'));
      remote.failWith = Exception('offline');
      container.read(syncControllerProvider);
      await pumpEventQueue(times: 50);

      expect(
        container.read(syncControllerProvider).status,
        SyncStatus.retrying,
      );
      expect(remote.pulls, 1);
    });

    test('stops for the day when the request budget is used up', () async {
      container = make(user: const AuthUser(id: 'u1'));
      final today = DateTime.now().toUtc().toIso8601String().substring(0, 10);
      await syncStore.setState(kBudgetDayKey, today);
      await syncStore.setState(kBudgetRequestsKey, '$kDailyRequestCap');

      container.read(syncControllerProvider);
      await pumpEventQueue(times: 50);

      expect(container.read(syncControllerProvider).status, SyncStatus.paused);
      expect(remote.pulls, 0);
    });

    test('signing out resets the status', () async {
      container = make(user: const AuthUser(id: 'u1'));
      container.read(syncControllerProvider);
      await pumpEventQueue(times: 50);

      auth.emit(null);
      await pumpEventQueue(times: 50);

      expect(
        container.read(syncControllerProvider).status,
        SyncStatus.signedOut,
      );
    });

    test('removeLocalData clears items and ownership on this device', () async {
      container = make(user: const AuthUser(id: 'u1'));
      container.read(syncControllerProvider);
      await pumpEventQueue(times: 50);
      container
          .read(annotationsProvider.notifier)
          .toggleBookmark(const VerseRef('JHN', 3, 16));
      expect(userStore.bookmarks, isNotEmpty);

      await container.read(syncControllerProvider.notifier).removeLocalData();

      expect(userStore.bookmarks, isEmpty);
      expect(container.read(annotationsProvider).bookmarks, isEmpty);
      expect(await syncStore.getState(kSyncOwnerKey), isNull);
    });
  });

  test('data export lists everything as JSON', () {
    final json = exportAnnotationsJson(
      UserAnnotations(
        bookmarks: {const VerseRef('JHN', 3, 16): _t0},
        notes: {const VerseRef('GEN', 1, 1): Note('hello', _t0)},
        highlights: {
          const VerseRef('PSA', 23, 1): Highlight(HighlightColor.green, _t0),
        },
        readChapters: const {'JHN:3', 'GEN:1'},
      ),
      now: _t0,
    );
    expect(json, contains('"verse": "JHN:3:16"'));
    expect(json, contains('"text": "hello"'));
    expect(json, contains('"color": "green"'));
    expect(json, contains('"GEN:1"'));
  });
}
