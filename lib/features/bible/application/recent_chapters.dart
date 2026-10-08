import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/user_data.dart';
import '../../../core/storage/user_data_providers.dart';

/// Most-recently-read chapters, newest first. The in-memory list drives the
/// UI immediately; saving to the device database happens in the background.
class RecentChaptersNotifier extends Notifier<List<RecentChapter>> {
  @override
  List<RecentChapter> build() => ref.read(initialRecentsProvider);

  void record(String bookCode, int chapter) {
    final entry = RecentChapter(
      bookCode: bookCode,
      chapter: chapter,
      openedAt: DateTime.now(),
    );
    state = [
      entry,
      ...state.where((r) => !(r.bookCode == bookCode && r.chapter == chapter)),
    ].take(kMaxRecentChapters).toList();
    unawaited(ref.read(userDataStoreProvider).saveRecent(entry));
  }
}

final recentChaptersProvider =
    NotifierProvider<RecentChaptersNotifier, List<RecentChapter>>(
  RecentChaptersNotifier.new,
);
