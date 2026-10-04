# Contributing

1. Create a focused branch from `main`.
2. Keep menu bar behavior fail-open: uncertain state must show all items.
3. Add or update tests for layout, persistence, localization, or engine behavior.
4. Run `./script/build_and_run.sh --test`.
5. Test the real app on macOS 27 before changing visibility behavior.
6. Update both English and Polish strings for user-facing text.
7. Keep `README.md`, `docs/README.pl.md`, and both release guides consistent when behavior or packaging changes.

Do not add network dependencies, analytics, private entitlements, or App Sandbox without first explaining how the macOS 27 hiding mechanism will continue to work.

Public releases are created only from annotated `vMAJOR.MINOR.PATCH` tags. Do not upload locally ad-hoc-signed DMG files. Follow [docs/RELEASING.md](docs/RELEASING.md) so GitHub Actions can apply Developer ID signing, notarization, stapling, and checksum generation.
