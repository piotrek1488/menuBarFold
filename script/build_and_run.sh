#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="MenuBarFold"
BUNDLE_ID="io.github.menubarfold.MenuBarFold"
MIN_SYSTEM_VERSION="27.0"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
MODULE_CACHE="$ROOT_DIR/.build/module-cache"

export CLANG_MODULE_CACHE_PATH="$MODULE_CACHE/clang"
export SWIFTPM_MODULECACHE_OVERRIDE="$MODULE_CACHE/swiftpm"
mkdir -p "$CLANG_MODULE_CACHE_PATH" "$SWIFTPM_MODULECACHE_OVERRIDE"

build_app() {
  swift build --disable-sandbox
  local bin_path
  bin_path="$(swift build --disable-sandbox --show-bin-path)"
  local build_binary="$bin_path/$APP_NAME"
  local resource_bundle="$bin_path/MenuBarFold_MenuBarFold.bundle"

  rm -rf "$APP_BUNDLE"
  mkdir -p "$APP_MACOS" "$APP_RESOURCES"
  cp "$build_binary" "$APP_BINARY"
  chmod +x "$APP_BINARY"

  if [[ -d "$resource_bundle" ]]; then
    cp -R "$resource_bundle" "$APP_RESOURCES/"
  fi

  swift "$ROOT_DIR/script/generate_icon.swift" "$APP_RESOURCES"
  cp "$APP_RESOURCES/MenuBarFold.iconset/icon_512x512@2x.png" "$APP_RESOURCES/MenuBarFold.png"
  rm -rf "$APP_RESOURCES/MenuBarFold.iconset"

  cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleIconFile</key>
  <string>MenuBarFold.png</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleLocalizations</key>
  <array>
    <string>en</string>
    <string>pl</string>
  </array>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundleDisplayName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSApplicationCategoryType</key>
  <string>public.app-category.utilities</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>LSMultipleInstancesProhibited</key>
  <true/>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

  printf 'APPL????' >"$APP_CONTENTS/PkgInfo"
  codesign --force --deep --sign - "$APP_BUNDLE" >/dev/null
}

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

pkill -x "$APP_NAME" >/dev/null 2>&1 || true

case "$MODE" in
  run)
    build_app
    open_app
    ;;
  --debug|debug)
    build_app
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    build_app
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    build_app
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\" OR process == \"$APP_NAME\""
    ;;
  --verify|verify)
    build_app
    open_app
    sleep 2
    pgrep -x "$APP_NAME" >/dev/null
    echo "$APP_NAME launched successfully: $APP_BUNDLE"
    ;;
  --diagnose|diagnose)
    build_app
    "$APP_BINARY" --diagnose
    ;;
  --test|test)
    swift test --disable-sandbox
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify|--diagnose|--test]" >&2
    exit 2
    ;;
esac
