# Origin Bible

Offline-first, multilingual Bible app with a daily swipe feed.
See `docs/ARCHITECTURE.md` for the rules every change must follow.

## Setup
```bash
unzip origin_bible_phase0.zip && cd origin_bible
./scripts/setup.sh
git init && git add . && git commit -m "Phase 0: foundation"
flutter run --dart-define-from-file=env/dev.json
```
Windows: run the commands inside `scripts/setup.sh` manually.

## Phase status
- [x] Phase 0: foundation
- [ ] Phase 1: UI/UX foundation
