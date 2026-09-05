# Developing Keydoze

## Safe UI previews

```sh
./script/build_and_run.sh --simulate
# After building debug, quit the app before launching a different preview:
open -n 'dist/Keydoze.app' --args --simulate --state recovery --appearance dark
```

Debug-only states: `ready`, `permission`, `arming`, `active`, `recovery`, `releasing`, `done`, `error`. The Preview menu changes states without creating a tap. `--appearance` accepts `light`, `dark`, `contrast-light`, `contrast-dark`; `--reduce-motion` and `--reduce-transparency` exercise app-only fallbacks in simulation without modifying system preferences. Frozen previews render states; normal `--simulate` can run the model's simulated timer. All are visibly marked as nonblocking previews and excluded from optimized builds.

## Live development checks

Only short, supervised checks are appropriate on a primary Mac. First launch a debug build with `--live-check --evidence /absolute/local/path`. This limits a session to eight seconds and shows transient aggregate counters; launching it does **not** start blocking. In another terminal, run:

```sh
python3 script/test_watchdog.py --seconds 30 --activate
```

Wait for **ARMED** before clicking Start. This separate process terminates only this project's app at its deadline. Adding `--synthetic-check` to the app arguments runs a public Quartz-stream injection check after an explicitly started session becomes active. It measures suppression and delivery of synthetic events, not physical-device coverage. Evidence stores lifecycle results and aggregate counts, never input content or raw events. Do not run permission-revocation/sleep/session-switch stress tests on a primary session; use an isolated device/account.

For supervised recovery checks, `--fault-ui-stall` deliberately stalls only the app's main thread for four seconds, and `--fault-tap-disabled` disables only its own tap. Both flags require `--live-check`, take effect only after Start becomes active, and are excluded from release builds. Use one fault per session, always with the external watchdog armed first.

## Code map

- `Sources/KeydozeCore/Session.swift`: deterministic phases, deadlines, recovery and held-input drain.
- `Sources/Keydoze/InputEngine.swift`: event tap, dedicated run loop, independent watchdog and cleanup.
- `Sources/Keydoze/SessionModel.swift`: presentation, local preferences, permissions and system lifecycle.
- `Sources/Keydoze/MainView.swift`: native UI and recovery guidance.
- `Tests/`: deterministic safety and macOS adapter coverage, without installing taps.

## Development signing

The stable local bundle is `dist/Keydoze.app`. Its historical identifier, `app.cleanmode.mac`, is retained from the original prototype to preserve existing Accessibility authorization. The product and source modules are named Keydoze.

The build script uses an available Apple Development identity consistently for debug and release. Set `KEYDOZE_SIGN_IDENTITY` to select a certificate explicitly. Without one it uses ad-hoc signing, whose permission identity can change on rebuild. Prefer a stable development certificate and do not reset unrelated privacy grants. See [permissions and signing](RESEARCH.md#permissions-and-signing).

## Icon

The original generated PNG and exact ImageGen prompt are in `Resources/Brand/`. Run `./script/build_icon.sh` to regenerate the macOS icon and README image with native `sips` and `iconutil`. This only resizes and packages the artwork. No image-generation service is called by the build or app.
