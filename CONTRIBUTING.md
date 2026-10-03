# Contributing

1. Create a focused branch from `main`.
2. Keep menu bar behavior fail-open: uncertain state must show all items.
3. Add or update tests for layout, persistence, localization, or engine behavior.
4. Run `./script/build_and_run.sh --test`.
5. Test the real app on macOS 27 before changing visibility behavior.
6. Update both English and Polish strings for user-facing text.

Do not add network dependencies, analytics, private entitlements, or App Sandbox without first explaining how the macOS 27 hiding mechanism will continue to work.
