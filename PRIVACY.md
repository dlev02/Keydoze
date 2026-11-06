# Privacy

Last updated: 5 November 2026

Keydoze has no accounts, advertising, analytics, or remote logging. Cleaning sessions work without a network connection. The only network requests the app makes are update checks and update downloads, both to GitHub. Nothing is sent to the developer.

## Update checks

Keydoze uses [Sparkle](https://sparkle-project.org), an open-source update framework, to keep itself current.

- **When:** when you open Keydoze if the last check was more than a day ago, then once a day while it stays open. No check starts during a cleaning session.
- **What it requests:** one file, `appcast.xml`, from Keydoze's [GitHub releases](https://github.com/dlev02/Keydoze/releases). It downloads an update only after you choose **Install Update**.
- **What GitHub can see:** as with any web request, your IP address and the time, plus the app's name and version and Sparkle's version (for example `Keydoze/0.2.0 Sparkle/2.10.1`) and your Mac's language preference. GitHub handles this under [its privacy statement](https://docs.github.com/en/site-policy/privacy-policies/github-general-privacy-statement).
- **What is not sent:** typed input, input events, your session history, device identifiers, or a hardware or system profile.
- **What the developer can see:** GitHub shows repository owners a running total of downloads for each release file. Checks add to the total for `appcast.xml`. It does not show who made them.
- **What stays on your Mac:** the time of the last check, your choices about updates, and a downloaded update until it is installed. These are in Keydoze's local preferences and caches.

To turn automatic checks off, choose **Keydoze > Settings…** and turn off **Check for updates automatically**. Keydoze then makes no network requests unless you choose **Keydoze > Check for Updates…**.

Versions before 0.2.0 have no update checker and make no network requests.

## Input processing

During a cleaning session, Keydoze uses a macOS event tap to decide which keyboard and pointing events to suppress. It temporarily tracks key and button identities, held-input state, and timing so it can release input safely and recognize the recovery shortcut. It does not save typed characters, raw input events, clipboard contents, screenshots, or recordings. Blocked events are not replayed.

The event tap is removed when the session ends or is interrupted. There is no input event tap while the app is idle.

## What stays on your Mac

The app saves the selected input scope, session duration, and update settings in local macOS preferences. It does not sync those preferences or upload them. macOS manages the permission that allows Keydoze to intercept input; granting or revoking that permission happens in System Settings.

Development builds include optional diagnostics that are excluded from release builds:

- Launching with `--evidence <directory>` writes local lifecycle records, monotonic timestamps, permission and held-input booleans, and aggregate counts used by explicit development checks. These records contain no typed text or raw event payloads.
- Launching with `--probe-permission <file>` writes permission-check results and the app's bundle identifier and local bundle path. The path may include your Mac account name.

These files are written only when the corresponding development option is supplied. They are never uploaded automatically. You can delete them from the location chosen for the check.

## Reports you choose to share

GitHub issues and pull requests are public. If you submit a report, GitHub receives the text and attachments you choose to send under [GitHub's privacy statement](https://docs.github.com/en/site-policy/privacy-policies/github-general-privacy-statement). Review screenshots and diagnostics before sharing them; remove personal information, local account paths, and unrelated app content. Reports are optional and are not sent by Keydoze itself.

For security-sensitive findings, follow [SECURITY.md](SECURITY.md) instead of posting details in a public issue.
