# Architecture Rules (non-negotiable)

1. **Zero-cost operation.** Every service runs on a free tier. No code path may enable billing or upgrade a plan.
2. **Hard quota protection.** Every external service is gated by a UsageGuard (80% warn, 90% stop new jobs, 100% hard stop). Built in Phase 5, before any generation feature exists.
3. **Legal licensing.** No Bible translation, image source, voice or dataset enters the repo until it is recorded in LICENSES.md and ATTRIBUTIONS.md.
4. **Offline-first.** The UI reads local SQLite/cache. Startup and screens never wait on the network.
5. **Graceful degradation.** AI, TTS, image, storage, Supabase or network failure must never break existing content.
6. **Generation is optional at runtime.** Generation runs in the background or offline pipeline, never on the path that renders content. `GENERATION_ENABLED` defaults to false.
7. **Fail closed.** At a limit: stop. Never spend, never retry forever.

## Layers
```
Flutter UI -> Repository -> SQLite (source of truth)
                         -> Supabase (sync/metadata, optional)
Audio: R2 (Opus only) -> local cache.  Images: external providers -> local cache.
```

## Secrets
The app contains only public values (Supabase URL + anon key). Service-role, Groq, Gemini and R2 keys exist only in the backend/pipeline environment.

## Structure
`lib/core` (config, router, shared infra) / `lib/shared` (reusable widgets) / `lib/features/<name>/{data,domain,presentation}`.
