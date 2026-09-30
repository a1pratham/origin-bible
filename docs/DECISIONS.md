# Decision Log

| # | Decision | Why |
|---|----------|-----|
| 1 | Riverpod for state | Testable, compile-safe, good for repository/provider layering |
| 2 | go_router with StatefulShellRoute | Keeps each tab's state alive when switching tabs |
| 3 | Safety system (UsageGuard) built in Phase 5, not Phase 12 | Every generation feature is gated from its first line of code |
| 4 | Local-only user data before login (Phase 4) | Offline-first: core features work without account or network |
| 5 | Feed built on seed JSON first (Phase 6) | Proves "stored content is the source of truth" before any AI exists |
| 6 | Drift (SQLite) added in Phase 2, not Phase 0 | Avoid unused dependencies until the schema is designed |
| 7 | Config via --dart-define-from-file | No secrets in source; public values only in the app |
| 8 | System fonts only in Phase 1 | No license risk, no download size; bundled reading font only after LICENSES.md entry |
| 9 | Theme mode and text size held in memory | Persistence arrives with local storage in Phase 3 |
| 10 | All animations via AppMotion.resolve | Respects the OS "remove animations" accessibility setting |
| 11 | Sample reading text is not Scripture | No translation text enters the app before its license is approved |
