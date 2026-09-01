#!/usr/bin/env bash
# Пакует собранный macOS-релиз в .dmg с ярлыком /Applications.
# Запускать после `flutter build macos --release`.
set -euo pipefail

BUILD_DIR="build/macos/Build/Products/Release"
APP_PATH="$(find "$BUILD_DIR" -maxdepth 1 -name '*.app' | head -n 1)"

if [ -z "$APP_PATH" ]; then
  echo "Не найден .app в $BUILD_DIR — сначала выполни: flutter build macos --release" >&2
  exit 1
fi

APP_NAME="$(basename "$APP_PATH" .app)"
VERSION="$(sed -n 's/^version: *\([0-9][^+ ]*\).*/\1/p' pubspec.yaml | head -n 1)"
VERSION="${VERSION:-0.0.0}"
DMG_PATH="dist/${APP_NAME}-${VERSION}.dmg"

# Ad-hoc подпись: без неё macOS считает скачанный бандл повреждённым.
codesign --force --deep --sign - "$APP_PATH"

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

cp -R "$APP_PATH" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

mkdir -p dist
rm -f "$DMG_PATH"

hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGE" \
  -fs HFS+ \
  -format UDZO \
  -ov \
  "$DMG_PATH"

echo "Готово: $DMG_PATH"

if [ -n "${GITHUB_OUTPUT:-}" ]; then
  {
    echo "dmg_path=$DMG_PATH"
    echo "dmg_name=$(basename "$DMG_PATH")"
  } >> "$GITHUB_OUTPUT"
fi
