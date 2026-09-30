#!/usr/bin/env bash
# One-time setup. Run from the project root after unzipping.
set -euo pipefail
command -v flutter >/dev/null || { echo "Install Flutter first: https://docs.flutter.dev/get-started/install"; exit 1; }

# Generates android/ (and ios/) platform folders without touching lib/ or pubspec.yaml
flutter create . --project-name origin_bible --org com.originbible --platforms android,ios

cp -n env/dev.json.example env/dev.json || true
flutter pub get
dart format .
flutter analyze
flutter test
echo "OK. Run the app with: flutter run --dart-define-from-file=env/dev.json"
