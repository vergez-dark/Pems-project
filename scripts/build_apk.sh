#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
version="$(sed -n 's/^version: \([^+]*\).*/\1/p' pubspec.yaml)"

flutter pub get
if grep -q 'build_runner:' pubspec.yaml; then
  dart run build_runner build --delete-conflicting-outputs
fi
if ! dart format --output=none --set-exit-if-changed lib test; then
  echo "Formatage requis : lancez 'dart format lib test', puis relancez le script." >&2
  exit 1
fi
flutter analyze
flutter test
flutter build apk --release
flutter build apk --release --split-per-abi

mkdir -p dist
cp build/app/outputs/flutter-apk/app-release.apk "dist/pems-store-v${version}.apk"
for apk in build/app/outputs/flutter-apk/app-*-release.apk; do
  [ -f "$apk" ] || continue
  abi="$(basename "$apk" | sed -E 's/app-(.*)-release.apk/\1/')"
  cp "$apk" "dist/pems-store-v${version}-${abi}.apk"
done

echo "APK disponibles dans dist/"
