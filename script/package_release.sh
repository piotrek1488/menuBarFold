#!/usr/bin/env bash
set -euo pipefail

APP_NAME="MenuBarFold"
APP_VERSION="${1:-${APP_VERSION:-}}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
SWIFT_BUILD_ARCHS="${SWIFT_BUILD_ARCHS:-arm64 x86_64}"
REQUIRE_DEVELOPER_ID="${REQUIRE_DEVELOPER_ID:-1}"
SKIP_NOTARIZATION="${SKIP_NOTARIZATION:-0}"
SIGNING_IDENTITY="${CODE_SIGN_IDENTITY:-}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/$APP_NAME"
DMG_ROOT="$DIST_DIR/dmg-root"
DMG_PATH="$DIST_DIR/$APP_NAME-$APP_VERSION.dmg"
CHECKSUM_PATH="$DMG_PATH.sha256"

cleanup() {
  /bin/rm -rf "$DMG_ROOT"
}

trap cleanup EXIT

if [[ ! "$APP_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "usage: $0 <version such as 0.2.0>" >&2
  exit 2
fi

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
fi

if [[ "$SKIP_NOTARIZATION" != "1" ]]; then
  : "${NOTARYTOOL_KEY:?NOTARYTOOL_KEY must point to an App Store Connect team API key}"
  : "${NOTARYTOOL_KEY_ID:?NOTARYTOOL_KEY_ID is required}"
  : "${NOTARYTOOL_ISSUER_ID:?NOTARYTOOL_ISSUER_ID is required}"

  if [[ ! -f "$NOTARYTOOL_KEY" ]]; then
    echo "Notary API key not found: $NOTARYTOOL_KEY" >&2
    exit 1
  fi
fi

APP_VERSION="$APP_VERSION" \
BUILD_NUMBER="$BUILD_NUMBER" \
BUILD_CONFIGURATION=release \
SWIFT_BUILD_ARCHS="$SWIFT_BUILD_ARCHS" \
ENABLE_HARDENED_RUNTIME=1 \
REQUIRE_DEVELOPER_ID="$REQUIRE_DEVELOPER_ID" \
CODE_SIGN_IDENTITY="$SIGNING_IDENTITY" \
  "$ROOT_DIR/script/build_app_bundle.sh"

/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

for architecture in $SWIFT_BUILD_ARCHS; do
  /usr/bin/lipo "$APP_BINARY" -verify_arch "$architecture"
done

/bin/rm -rf "$DMG_ROOT"
mkdir -p "$DMG_ROOT"
/usr/bin/ditto "$APP_BUNDLE" "$DMG_ROOT/$APP_NAME.app"
/bin/ln -s /Applications "$DMG_ROOT/Applications"
/bin/rm -f "$DMG_PATH" "$CHECKSUM_PATH"

/usr/sbin/diskutil image create from \
  --format UDZO \
  --volumeName "$APP_NAME $APP_VERSION" \
  "$DMG_ROOT" \
  "$DMG_PATH"

dmg_codesign_arguments=(--force --sign "$SIGNING_IDENTITY")
if [[ "$SIGNING_IDENTITY" == Developer\ ID\ Application:* ]]; then
  dmg_codesign_arguments+=(--timestamp)
fi
/usr/bin/codesign "${dmg_codesign_arguments[@]}" "$DMG_PATH"
/usr/bin/codesign --verify --strict --verbose=2 "$DMG_PATH"

if [[ "$SKIP_NOTARIZATION" == "1" ]]; then
  echo "Warning: notarization was skipped; this DMG is for local validation only." >&2
else
  /usr/bin/xcrun notarytool submit "$DMG_PATH" \
    --key "$NOTARYTOOL_KEY" \
    --key-id "$NOTARYTOOL_KEY_ID" \
    --issuer "$NOTARYTOOL_ISSUER_ID" \
    --wait
  /usr/bin/xcrun stapler staple "$DMG_PATH"
  /usr/bin/xcrun stapler validate "$DMG_PATH"
  /usr/sbin/spctl --assess --type open \
    --context context:primary-signature \
    --verbose=4 \
    "$DMG_PATH"
fi

(
  cd "$DIST_DIR"
  /usr/bin/shasum -a 256 "$(basename "$DMG_PATH")" >"$(basename "$CHECKSUM_PATH")"
)

echo "Release image: $DMG_PATH"
echo "Checksum: $CHECKSUM_PATH"
