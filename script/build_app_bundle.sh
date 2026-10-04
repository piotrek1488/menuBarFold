#!/usr/bin/env bash
set -euo pipefail

APP_NAME="MenuBarFold"
BUNDLE_ID="${BUNDLE_ID:-io.github.menubarfold.MenuBarFold}"
MIN_SYSTEM_VERSION="${MIN_SYSTEM_VERSION:-27.0}"
APP_VERSION="${APP_VERSION:-0.1.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
BUILD_CONFIGURATION="${BUILD_CONFIGURATION:-debug}"
SWIFT_BUILD_ARCHS="${SWIFT_BUILD_ARCHS:-}"
ENABLE_HARDENED_RUNTIME="${ENABLE_HARDENED_RUNTIME:-0}"
REQUIRE_DEVELOPER_ID="${REQUIRE_DEVELOPER_ID:-0}"
SIGNING_IDENTITY="${CODE_SIGN_IDENTITY:-}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
MODULE_CACHE="$ROOT_DIR/.build/module-cache"

if [[ ! "$APP_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "APP_VERSION must contain three numeric components, for example 0.2.0." >&2
  exit 2
fi

if [[ ! "$BUILD_NUMBER" =~ ^[0-9]+$ ]]; then
  echo "BUILD_NUMBER must be numeric." >&2
  exit 2
fi

if [[ "$BUILD_CONFIGURATION" != "debug" && "$BUILD_CONFIGURATION" != "release" ]]; then
  echo "BUILD_CONFIGURATION must be debug or release." >&2
  exit 2
fi

export CLANG_MODULE_CACHE_PATH="$MODULE_CACHE/clang"
export SWIFTPM_MODULECACHE_OVERRIDE="$MODULE_CACHE/swiftpm"
mkdir -p "$CLANG_MODULE_CACHE_PATH" "$SWIFTPM_MODULECACHE_OVERRIDE" "$DIST_DIR"

resolve_signing_identity() {
  if [[ -n "$SIGNING_IDENTITY" ]]; then
    return
  fi

  if [[ "$REQUIRE_DEVELOPER_ID" == "1" ]]; then
    SIGNING_IDENTITY="$({
      security find-identity -v -p codesigning 2>/dev/null || true
    } | awk -F'"' '/Developer ID Application:/ { print $2; exit }')"
  else
    SIGNING_IDENTITY="$({
      security find-identity -v -p codesigning 2>/dev/null || true
    } | awk -F'"' '/^[[:space:]]*[0-9]+\)/ { print $2; exit }')"
  fi
}

resolve_signing_identity

if [[ "$REQUIRE_DEVELOPER_ID" == "1" && "$SIGNING_IDENTITY" != Developer\ ID\ Application:* ]]; then
  echo "A Developer ID Application certificate is required for a public release." >&2
  exit 1
fi

if [[ -z "$SIGNING_IDENTITY" ]]; then
  SIGNING_IDENTITY="-"
  echo "Warning: no persistent signing identity found; using an ad-hoc signature." >&2
fi

swift_build_arguments=(
  build
  --disable-sandbox
  --configuration "$BUILD_CONFIGURATION"
)

if [[ -n "$SWIFT_BUILD_ARCHS" ]]; then
  read -r -a requested_architectures <<<"$SWIFT_BUILD_ARCHS"
  for architecture in "${requested_architectures[@]}"; do
    swift_build_arguments+=(--arch "$architecture")
  done
fi

swift "${swift_build_arguments[@]}"
bin_path="$(swift "${swift_build_arguments[@]}" --show-bin-path)"
build_binary="$bin_path/$APP_NAME"
resource_bundle="$bin_path/MenuBarFold_MenuBarFold.bundle"

if [[ ! -x "$build_binary" ]]; then
  echo "Built executable not found: $build_binary" >&2
  exit 1
fi

/bin/rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS" "$APP_RESOURCES"
/usr/bin/ditto "$build_binary" "$APP_BINARY"
chmod +x "$APP_BINARY"

if [[ -d "$resource_bundle" ]]; then
  /usr/bin/ditto "$resource_bundle" "$APP_RESOURCES/$(basename "$resource_bundle")"
fi

swift "$ROOT_DIR/script/generate_icon.swift" "$APP_RESOURCES"
/usr/bin/ditto \
  "$APP_RESOURCES/MenuBarFold.iconset/icon_512x512@2x.png" \
  "$APP_RESOURCES/MenuBarFold.png"
/bin/rm -rf "$APP_RESOURCES/MenuBarFold.iconset"

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
  <string>$APP_VERSION</string>
  <key>CFBundleVersion</key>
  <string>$BUILD_NUMBER</string>
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

codesign_arguments=(--force --sign "$SIGNING_IDENTITY")
if [[ "$ENABLE_HARDENED_RUNTIME" == "1" ]]; then
  codesign_arguments+=(--options runtime)
  if [[ "$SIGNING_IDENTITY" == Developer\ ID\ Application:* ]]; then
    codesign_arguments+=(--timestamp)
  fi
fi

/usr/bin/codesign "${codesign_arguments[@]}" "$APP_BUNDLE"
/usr/bin/codesign --verify --deep --strict "$APP_BUNDLE"

echo "Built $APP_BUNDLE"
echo "Version: $APP_VERSION ($BUILD_NUMBER)"
echo "Configuration: $BUILD_CONFIGURATION"
echo "Architectures: $(/usr/bin/lipo -archs "$APP_BINARY")"
echo "Signing identity: $SIGNING_IDENTITY"
