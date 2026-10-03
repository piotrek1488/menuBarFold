# Security policy

## Supported versions

Security fixes are applied to the latest release and the `main` branch.

## Reporting

Please do not open a public issue for a vulnerability. Use GitHub's private vulnerability reporting feature for the repository after it is published.

## Security posture

MenuBarFold is intentionally local:

- no network requests or analytics;
- no account or cloud storage;
- no file-system access beyond its own bundle and `UserDefaults`;
- no shell commands or subprocesses from the app;
- no helper, XPC service, daemon, or inbound IPC;
- Accessibility data is kept in memory only;
- a private framework is resolved dynamically and every failure releases the menu bar restriction.

The build is intentionally not sandboxed because its macOS 27 function cannot work inside App Sandbox. Release builds should still use Hardened Runtime, Developer ID signing, and notarization.
