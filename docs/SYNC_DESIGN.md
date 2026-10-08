# Sync Design (design only; no sync code until Phase 4.5)

## Principles (from the non-negotiables)
1. **Local first.** The device database is the source of truth. The UI never waits for the network and never reads from Supabase directly.
2. **Sync is optional.** No account, no network, or Supabase down = the app works fully. Sync resumes later.
3. **Fail closed, never spend.** Capped retries, hard request budgets, no realtime subscriptions, no paid features.
4. **Minimal data.** Only user-created data syncs. Bible text, caches and audio never sync.

## What syncs (Phase 4+)
| Data | Syncs | Notes |
|------|-------|-------|
| Preferences (theme, text size, translation, voice) | Yes | One row per user |
| Bookmarks, highlights, notes | Yes | Per-record |
| Saved feed cards / explanations | Yes | Store card id only, not content |
| Reading progress | Yes | One row per book+chapter |
| Recent chapters | No | Cheap to rebuild, device-specific |
| Bible text, feed content cache, audio, images | No | Downloaded read-only |

## Local schema rule (apply from Phase 4)
Every syncable table gets: `id` (client-generated UUID), `updated_at` (UTC ms), `deleted_at` (nullable, soft delete), `dirty` (0/1). Edits set `dirty = 1` and bump `updated_at`. Deletes set `deleted_at`, never remove the row until it has synced.

## Server schema sketch (Supabase)
Same tables with `user_id uuid references auth.users`, `server_updated_at timestamptz default now()`, plus a unique `(user_id, id)`. **Row Level Security on every table**: a user can only select/insert/update rows where `user_id = auth.uid()`. Account deletion cascades.

## Protocol
- **Push:** collect `dirty = 1` rows, send in batches of up to 100 using one upsert call per table, then clear `dirty` for rows acknowledged.
- **Pull:** `select ... where server_updated_at > last_pull_cursor order by server_updated_at limit 200`, repeat until fewer than 200 rows come back, then store the new cursor.
- **Conflicts:** last-write-wins per record using `updated_at`. A soft delete wins over an older edit. Notes keep the newer text; if both sides changed within 1 minute, keep both (the older becomes a copy) so nothing is silently lost.
- **When:** app start, app resume, after a local change (debounced 30 s), and at most once every 5 minutes in the background. Never on a tight timer.

## Quota safety (ties into the Phase 5 UsageGuard)
- Sync requests count against the Supabase request quota tracked by `UsageGuard`. At 90% the app stops background sync and syncs only on manual "Sync now"; at 100% it stops entirely (data stays local and safe).
- Retries: max 3 with exponential backoff (30 s, 2 min, 10 min), then wait for the next trigger. Never an infinite loop.
- Per-user caps: for example 5,000 notes, 20,000 highlights. Over the cap = refuse new syncs of that type and tell the user.
- Notes are text only, max 10,000 characters. No attachments.
- No realtime channels, no polling, no storage buckets.

## Failure behavior
| Failure | Behavior |
|---------|----------|
| Offline | Local edits continue; `dirty` rows wait |
| Supabase down or quota hit | Same; show a small "Not synced" indicator, never an error wall |
| Auth expired | Keep working locally; ask to sign in again when convenient |
| Corrupt local DB | Rebuild from server if signed in; otherwise start fresh (Bible text is unaffected) |

## Account lifecycle
- Anonymous/local mode is the default. Signing in uploads existing local data once (merge by UUID).
- Sign out keeps local data unless the user chooses "remove data from this device".
- Account deletion removes server rows (cascade) and offers local deletion.

## Open decisions for Phase 4
- Whether highlights store a verse range or one row per verse.
- Whether to sync reading progress as chapters-read or as a single "last position" per device.
