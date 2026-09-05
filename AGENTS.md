# Keydoze
Native macOS 26+ SwiftUI/AppKit utility; Swift 6, no package dependencies or network access.

- Build and launch: `./script/build_and_run.sh`
- Build only: `./script/build_and_run.sh --build`
- Safe simulated UI: `./script/build_and_run.sh --simulate`
- Tests: `swift test --disable-sandbox`
- Release bundle (local, not notarized): `./script/build_and_run.sh --release`
- Stable development bundle: `dist/Keydoze.app`, ID `app.cleanmode.mac`.

The engine owns event filtering and deadlines off the main thread. The deterministic core is in KeydozeCore. Never log typed content or raw events, replay blocked events, automatically restart an interrupted session, or request extra privacy permissions by habit. Idle means no event taps.

Live filtering tests require a short duration and an independent external process-kill watchdog armed before activation. UI simulation never creates a tap. Do not test TCC revocation, sleep, or session switching during live filtering on the user's primary Mac; use an isolated test account/device. Hardware gestures, Fn/media keys, Touch ID, and power/security paths must never be advertised as comprehensively blocked without evidence. Preserve unrelated workspace changes. Distribution signing, notarization, and publication require separately authorized credentials/targets.
