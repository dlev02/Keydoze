# Privacy

Keydoze works offline. It has no accounts, advertising, analytics, remote logging, update checker, or network requests. The app does not collect or send personal data to its developer or any third party.

## Input processing

During a cleaning session, Keydoze uses a macOS event tap to decide which keyboard and pointing events to suppress. It temporarily tracks key and button identities, held-input state, and timing so it can release input safely and recognize the recovery shortcut. It does not save typed characters, raw input events, clipboard contents, screenshots, or recordings. Blocked events are not replayed.

The event tap is removed when the session ends or is interrupted. There is no input event tap while the app is idle.

## What stays on your Mac

The app saves the selected input scope and session duration in local macOS preferences. It does not sync those preferences or upload them. macOS manages the permission that allows Keydoze to intercept input; granting or revoking that permission happens in System Settings.

Development builds include optional diagnostics that are excluded from release builds:

- Launching with `--evidence <directory>` writes local lifecycle records, monotonic timestamps, permission and held-input booleans, and aggregate counts used by explicit development checks. These records contain no typed text or raw event payloads.
- Launching with `--probe-permission <file>` writes permission-check results and the app's bundle identifier and local bundle path. The path may include your Mac account name.

These files are written only when the corresponding development option is supplied. They are never uploaded automatically. You can delete them from the location chosen for the check.

## Reports you choose to share

GitHub issues and pull requests are public. If you submit a report, GitHub receives the text and attachments you choose to send under [GitHub's privacy statement](https://docs.github.com/en/site-policy/privacy-policies/github-general-privacy-statement). Review screenshots and diagnostics before sharing them; remove personal information, local account paths, and unrelated app content. Reports are optional and are not sent by Keydoze itself.

For security-sensitive findings, follow [SECURITY.md](SECURITY.md) instead of posting details in a public issue.
