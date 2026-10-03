# Release guide

The development script prefers a persistent certificate from the local keychain and falls back to an ad-hoc signature only when no suitable identity is available. Public downloads should use a stable Developer ID identity so Accessibility permission survives updates and Gatekeeper can validate the app.

## Before the first public build

1. Replace `io.github.menubarfold.MenuBarFold` in `script/build_and_run.sh` with your own stable reverse-DNS bundle identifier.
2. Join the Apple Developer Program and create a Developer ID Application certificate.
3. Keep App Sandbox disabled. Do not add private entitlements.
4. Update the version in the build script, About screen, changelog, and release notes.

## Verification

```sh
./script/build_and_run.sh --test
./script/build_and_run.sh --diagnose
./script/build_and_run.sh --verify
codesign -d --entitlements - dist/MenuBarFold.app
```

The entitlements output must not contain `com.apple.security.app-sandbox`. Test on a clean user account and verify:

- first-run Accessibility onboarding;
- installation and relaunch from `/Applications` before filtering is enabled;
- visible, hidden, and always-hidden placement;
- the native `«` button opens always-hidden icons while the MenuBarFold arrow controls only regular hidden icons;
- expand, collapse, auto fold, hover and global shortcut;
- microphone and camera safety pause;
- external-display connect and disconnect;
- wake from sleep;
- launch at login;
- English and Polish layouts;
- failure behavior after Accessibility access is revoked.

## Sign, notarize, and staple

Use your Developer ID identity instead of the ad-hoc signature:

```sh
codesign --force --deep --options runtime --timestamp \
  --sign "Developer ID Application: YOUR TEAM" dist/MenuBarFold.app

ditto -c -k --keepParent dist/MenuBarFold.app MenuBarFold.zip

xcrun notarytool submit MenuBarFold.zip \
  --keychain-profile "notarytool-profile" --wait

xcrun stapler staple dist/MenuBarFold.app
spctl --assess --type execute --verbose=4 dist/MenuBarFold.app
```

Never upload a sandboxed build as the direct release: icon hiding on macOS 27 will not work.
