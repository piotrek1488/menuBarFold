# Changelog

## Unreleased

- Added a tag-driven, no-cost GitHub Actions release flow for ad-hoc-signed Apple-silicon DMG files.
- Added reusable app-bundle and release-packaging scripts.
- Made the About version follow the built bundle version.
- Documented the first-launch Gatekeeper approval and Accessibility limitations of free releases.
- Kept Developer ID signing and notarization available as an optional future packaging mode.
- Updated English and Polish installation, behavior, and release documentation.

## 0.1.0

- Initial macOS 27 implementation.
- Visible, hidden, and always-hidden menu bar sections.
- Accessibility onboarding and fail-open behavior.
- Auto fold, hover reveal, global shortcuts, and launch at login.
- Microphone and camera privacy-indicator protection.
- Multi-display layout projection.
- Stable status-item identities that preserve the user's relative icon order during folding.
- Predictable two-stage reveal: the main arrow shows regular hidden icons and a fixed second arrow controls always-hidden icons on every display.
- English and Polish interface.
