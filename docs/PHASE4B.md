# Phase 4B: Accounts and sync (delta)

Everything works without this phase configured. Without Supabase keys the app behaves exactly like 4A and Profile says accounts are unavailable.

## Order
1. Follow `docs/SUPABASE_SETUP.md` (project, SQL, auth, keys, Android manifest).
2. `flutter pub add supabase_flutter`
3. Extract this delta over the project (or extract first; the order does not matter).
4. `dart format .`, `flutter analyze`, `flutter test`, run on the emulator.

## Files added
supabase/schema.sql
docs/{SUPABASE_SETUP,PHASE4B}.md
lib/core/auth/{auth_constants,auth_service,auth_providers,supabase_auth_service}.dart
lib/core/sync/{sync_models,sync_store,sync_remote,supabase_sync_remote,sync_engine,sync_controller,sync_host}.dart
lib/core/storage/annotation_export.dart
lib/features/account/presentation/{account_section,sign_in_screen,new_password_screen}.dart
test/support/fakes.dart, test/sync_test.dart, test/account_ui_test.dart

## Files replaced
lib/main.dart, lib/app.dart, lib/core/router/app_router.dart,
lib/core/storage/{user_data,sqlite_user_data_store}.dart (schema v3, `clearAnnotations`, sync methods),
lib/features/annotations/application/annotations_provider.dart (adds `reload()`),
lib/features/profile/presentation/profile_screen.dart (Account + Your data sections added; appearance and text size unchanged)

## Not touched
Bible code, annotations UI, tests from earlier phases, app_config.dart, env files, android/ and ios/ (edited by hand per the setup guide), CI, pubspec.yaml (use `flutter pub add`).

## Add to docs/DECISIONS.md
| 31 | Supabase sits behind AuthService / SyncRemote interfaces; only 3 files import it | Swappable backend; tests use fakes; the app never depends on it being up |
| 32 | Google sign-in uses Supabase's browser OAuth flow, not the native google_sign_in package | Fewer moving parts and no Android OAuth client / SHA-1 setup; the native package's API changes between versions. Can be upgraded later |
| 33 | One `sync_items` table instead of one table per type | Fewer requests, one set of security rules, one cap |
| 34 | Pull first, then push | Lets a note edited on two devices be merged before upload. The server also ignores uploads older than what it holds |
| 35 | Conflicts: newest wins; two different live notes are merged (newer text first) | No silent loss of note text, as promised in SYNC_DESIGN.md |
| 36 | Preferences and recents are NOT synced (deviation from SYNC_DESIGN.md) | Low value; saves requests and complexity. Can be added later as one row per user |
| 37 | Sync limits: 30 s after a change, at most once a minute automatically, 3 retries (30 s, 2 min, 10 min), 300 requests per device per UTC day, bounded loops | Runaway protection; the global quota tracking arrives with the Phase 5 UsageGuard |
| 38 | Local data is owned by the first account that syncs it. A different account must remove local data first | Prevents one person's notes uploading into another person's account |
| 39 | Caps enforced in the database: 20,000 items per user, notes 10,000 characters | Protects the 500 MB free database |
| 40 | Account deletion runs `delete_my_account()` (cascade); local items stay on the device | Meets deletion requirement; user keeps their own notes |
| 41 | Passwords need at least 8 characters; email confirmation required | Basic account safety |
| 42 | "Copy my data" exports JSON to the clipboard | Data export with no new dependency; a file export can come later |

## Updates to docs/SYNC_DESIGN.md (read this once)
- Table layout: unified `sync_items` (decision 33), deterministic ids from 4A.
- Order: pull then push (decision 34).
- Preferences are not synced yet (decision 36).
- The "open decisions" are settled: one row per verse; reading progress syncs as chapters read.

## What to check on the emulator
1. With no keys in `env/dev.json`: everything works; Profile says accounts are unavailable.
2. After setup: create account, confirm email, sign in, highlight, Sync now, see the row in Supabase.
3. Second device: same account shows the same items.
4. Airplane mode: keep reading, adding notes; Profile shows a calm "will sync later" message; sync works once back online.
5. Sign out > "Sign out and remove data", then sign in with a different account: no data leaks across accounts.
6. Delete account removes the cloud data.

## Known limits
- Android only (iOS needs the URL scheme in Info.plist later).
- The built-in Supabase email sender is for testing only (see setup guide).
- Sync is not instant: changes upload about 30 seconds after you stop editing, or on Sync now / app resume.
- A device that stays offline for more than 90 days could bring back items you deleted elsewhere, if you ever run the optional purge function.
- The sync controller still lives in `core` but imports the annotations provider; Phase 5 will move shared providers when UsageGuard lands.
- There is no privacy policy or terms screen yet. Accounts store email addresses, so both are required before release (Phase 16).

## Add to LICENSES.md (verify each on pub.dev / the provider before release)
| supabase_flutter | code dependency | not yet verified |
| Supabase (hosted service) | backend | free plan terms: https://supabase.com/terms (verify) |
| Google OAuth sign-in | identity provider | Google API Services terms (verify) |
