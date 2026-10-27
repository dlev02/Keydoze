# Keydoze
Native macOS 26+ SwiftUI/AppKit utility; Swift 6, no package dependencies or network access.

- Build and launch: `./script/build_and_run.sh`
- Build only: `./script/build_and_run.sh --build`
- Safe simulated UI: `./script/build_and_run.sh --simulate`
- Tests: `swift test --disable-sandbox`
- Release bundle (local, not notarized): `./script/build_and_run.sh --release`
- Stable development bundle: `dist/Keydoze.app`, ID `app.cleanmode.mac`.
- Live filtering check (debug only, 8-second cap): arm `python3 script/test_watchdog.py --seconds 30 --activate` and wait for ARMED, then start a session in an app launched with `--live-check --evidence /abs/path`. Details and fault flags in [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md).
- Icon: `./script/build_icon.sh` regenerates `Resources/Keydoze.icns` from `Resources/Brand/Keydoze-source.png`.

Code map: `Sources/KeydozeCore/Session.swift` (deterministic phases, deadlines, recovery; no AppKit), `Sources/Keydoze/InputEngine.swift` (event tap, run loop thread, watchdog), `SessionModel.swift` (presentation, preferences, permission, lifecycle), `MainView.swift` (UI). `Debug*.swift`, the Preview menu, and every `--flag` are inside `#if DEBUG` and absent from release builds. Tests: `KeydozeCoreTests` (pure) and `KeydozeAdapterTests` (builds real CGEvents in memory; needs a logged-in GUI session for WindowServer, so run outside a headless sandbox).

Permission identity: the bundle ID `app.cleanmode.mac` and a consistent Apple Development signing identity are what keep the Accessibility grant across rebuilds. Do not rename the ID. The build script uses the first `Apple Development:` identity or `KEYDOZE_SIGN_IDENTITY`; ad-hoc signing loses the grant on every rebuild.

Releases: version and build live only in `Resources/Info.plist` and are bumped by hand; also update CHANGELOG.md and the README download name. Distribution is a separate Developer ID copy (team 7BVMD7TA97), notarized with `asc` from the keychain, never the development bundle; follow [docs/RELEASING.md](docs/RELEASING.md). 0.1.0 shipped 2026-10-21 as a notarized DMG and ZIP. Evidence and limits are in [docs/VALIDATION.md](docs/VALIDATION.md).

New GitHub issues fire the "Bug report to draft PR" Claude routine through `.github/workflows/claude-issue-fix.yml` (3 per day; the `claude-fix` label re-fires it).

The engine owns event filtering and deadlines off the main thread. The deterministic core is in KeydozeCore. Never log typed content or raw events, replay blocked events, automatically restart an interrupted session, or request extra privacy permissions by habit. Idle means no event taps.

Live filtering tests require a short duration and an independent external process-kill watchdog armed before activation. UI simulation never creates a tap. Do not test TCC revocation, sleep, or session switching during live filtering on the user's primary Mac; use an isolated test account/device. Hardware gestures, Fn/media keys, Touch ID, and power/security paths must never be advertised as comprehensively blocked without evidence. Preserve unrelated workspace changes. Distribution signing, notarization, and publication require separately authorized credentials/targets.
