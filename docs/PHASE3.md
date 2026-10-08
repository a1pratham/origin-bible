# Phase 3: Offline-First (delta)

## No new dependencies
Uses sqflite and path from Phase 2. No pubspec change.

## Files added
lib/core/storage/{user_data,sqlite_user_data_store,user_data_providers}.dart
lib/features/bible/application/recent_chapters.dart
test/user_data_test.dart
docs/SYNC_DESIGN.md

## Files replaced
- lib/main.dart (loads saved settings and recents before the first frame, with a 2 s safety timeout)
- lib/app.dart (saves settings in the background when they change)
- lib/core/settings/display_settings.dart (initial values come from storage)
- lib/features/bible/application/bible_providers.dart (initial translation from storage)
- lib/features/bible/presentation/bible_screen.dart (Continue reading + Recent)
- lib/features/bible/presentation/reader_screen.dart (records chapters as you read)

## Not touched
app_config.dart, tests from earlier phases, profile_screen.dart, android/, ios/, env/, CI, pubspec.yaml, assets.

## Add to docs/DECISIONS.md
| 19 | User data lives in its own writable SQLite file (origin_user.db) | Separate from the read-only Bible DB; Phase 4 adds bookmarks/notes by migration, no new storage tech |
| 20 | Settings and recents are write-behind: memory drives the UI, storage saves in the background | The UI never waits on disk |
| 21 | The store never throws; failures fall back to defaults and in-memory state | A broken or slow database cannot break startup or reading |
| 22 | Default store is in-memory; main.dart swaps in SQLite | Tests never need a device database |
| 23 | Recents are not synced | Device-specific and cheap to rebuild (see SYNC_DESIGN.md) |

## What to check on the emulator
1. Profile: switch to Dark and set text size to Large. Fully close the app (swipe it away) and reopen: both should be remembered, with no flash of the light theme.
2. Read John 3, then Genesis 1. Reopen the app and open the Bible tab: "Continue reading" shows Genesis 1 and "Recent" lists John 3.
3. Airplane mode on: everything above still works.

## Known limits
- Reading position is chapter-level (not scroll position within a chapter).
- Verse-level highlights, bookmarks and notes arrive in Phase 4.
