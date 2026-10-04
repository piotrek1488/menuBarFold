#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="MenuBarFold"
BUNDLE_ID="${BUNDLE_ID:-io.github.menubarfold.MenuBarFold}"
APP_VERSION="${APP_VERSION:-0.1.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
INSTALLED_APP_BUNDLE="/Applications/$APP_NAME.app"
MODULE_CACHE="$ROOT_DIR/.build/module-cache"

export CLANG_MODULE_CACHE_PATH="$MODULE_CACHE/clang"
export SWIFTPM_MODULECACHE_OVERRIDE="$MODULE_CACHE/swiftpm"
mkdir -p "$CLANG_MODULE_CACHE_PATH" "$SWIFTPM_MODULECACHE_OVERRIDE"

build_app() {
  APP_VERSION="$APP_VERSION" \
  BUILD_NUMBER="$BUILD_NUMBER" \
  BUILD_CONFIGURATION=debug \
  BUNDLE_ID="$BUNDLE_ID" \
    "$ROOT_DIR/script/build_app_bundle.sh"
}

install_app() {
  local staging_bundle="/Applications/.$APP_NAME-installing-$$.app"
  /bin/rm -rf "$staging_bundle"
  /usr/bin/ditto "$APP_BUNDLE" "$staging_bundle"
  codesign --verify --deep --strict "$staging_bundle"
  /bin/rm -rf "$INSTALLED_APP_BUNDLE"
  /bin/mv "$staging_bundle" "$INSTALLED_APP_BUNDLE"
  echo "Installed $APP_NAME: $INSTALLED_APP_BUNDLE"
}

open_app() {
  /usr/bin/open "$INSTALLED_APP_BUNDLE"
}

pkill -x "$APP_NAME" >/dev/null 2>&1 || true

case "$MODE" in
  run)
    build_app
    install_app
    open_app
    ;;
  --debug|debug)
    build_app
    install_app
    lldb -- "$INSTALLED_APP_BUNDLE/Contents/MacOS/$APP_NAME"
    ;;
  --logs|logs)
    build_app
    install_app
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    build_app
    install_app
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\" OR process == \"$APP_NAME\""
    ;;
  --verify|verify)
    build_app
    install_app
    open_app
    sleep 2
    pgrep -x "$APP_NAME" >/dev/null
    echo "$APP_NAME launched successfully: $INSTALLED_APP_BUNDLE"
    ;;
  --diagnose|diagnose)
    build_app
    install_app
    "$INSTALLED_APP_BUNDLE/Contents/MacOS/$APP_NAME" --diagnose
    ;;
  --test|test)
    swift test --disable-sandbox
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify|--diagnose|--test]" >&2
    exit 2
    ;;
esac
