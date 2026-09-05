# Validation and remaining coverage

Recorded 6 September 2026. Compatibility target: macOS 26+. Actual environment: Apple silicon, macOS 27.0 beta (26A5421a), Xcode 27.0 beta (27A5228h). No Intel or macOS 26 runtime claims.

## Observed results

- Final optimized Apple-silicon bundle built successfully, passed strict code-signature verification and plist validation, includes the Apache 2.0 license and attribution, and reports hardened runtime. Debug live-check, fault-injection, evidence and permission-probe flags were absent from the release executable. It opened on the ready screen with the existing permission grant and no Preview menu. A separate read-only `CGGetEventTapList` check found **0 owned taps / 0 enabled taps** while idle.
- **32 tests passed: 22 core and 10 macOS adapter tests**, including parameterized cases. Coverage includes deadlines, scope selection, both-Shift recognition/cancellation, simultaneous/repeated input, held controls, arming limits, permission/tap failures, interruption, no automatic restart and callback-only deadline/recovery enforcement. Adapter tests construct real CGEvents and convertible NSEvents in memory without posting input or installing taps. Their constructors need WindowServer access: the shell sandbox stalled that connection; execution outside that sandbox passed.
- Independent review found and fixed a callback path that could exceed the release cap if its watchdog stalled, then a late Stop path that could move that cap forward. Regression cases cover both.
- The actual packaged process acquired Accessibility and created an active suppressing tap. Input Monitoring was not separately granted/requested. The stale permission row after changing code signatures was repaired with user approval, then repeated development builds retained authorization.
- A supervised eight-second **real Quartz stream** check suppressed 9 synthetic keyboard events and 5 synthetic pointing events; the app's local monitor received **0 keyboard and 0 pointing events** from that check. Includes ordinary, simultaneous/repeated keys, distinct Shift transitions, pointer movement, left click/drag/release and scroll. These are synthetic stream events, not physical hardware tests.
- Live run `live-10`: active at monotonic 13.892 s; synthetic check passed at 15.543 s; releasing at 21.892 s; finished at 22.142 s. Actual engine snapshots showed tap installed while active/releasing and absent at completion. The independent process-termination watchdog was armed before Start.
- A supervised debug fault held the app's main thread for four seconds while its real tap was active. The engine ended with `uiUnresponsive`, the next actual snapshot reported no tap, and the UI displayed the correct interruption explanation. The external watchdog remained armed, but was not needed to end this session. No other app or system process was stalled.
- Disabling only the app's own real tap ended the session with `tapDisabled` and no tap in the next snapshot, about 50 ms after injection. A later UI assertion ran after the external watchdog had terminated that test instance, so it observed a fresh ready window instead; the lifecycle record establishes the engine result, while the interruption UI was checked separately in simulation. Relaunch did not restore a session.
- Earlier computer-use keystrokes could reach the app without registering as filtered, or arrived outside the short active window. They are excluded as proof of physical suppression.

Local debug evidence is under ignored `docs/evidence/`; it contains lifecycle state, permission booleans and aggregate results only. Older completion records used a nil-engine fallback for the tap field; only the corrected `live-10` snapshot is cited as direct completion evidence.

## UI checks on the packaged native app

The final Keydoze design was inspected in actual native windows. Light and dark setup, duration selection, permission setup and its troubleshooting disclosure, countdown, pointing-only Escape recovery, keyboard-only Finish now, recovery progress, and coverage help were checked through Accessibility and screenshots. Increased-contrast, reduced-motion, and reduced-transparency preview paths were also exercised. The app's original permission grant survived the rename and the rebuilt app showed Start cleaning without another permission request.

The title and toolbar background are hidden while standard window controls remain. Content uses a continuous app surface. The native About panel showed the installed icon, version, Drew Levinson credit, Apache 2.0 attribution, and offline privacy information. The ready screen has no persistent footer. Safe development previews retain a small explicit nonblocking label.

Earlier UI checks also covered simulated arming cancellation, cleanup, completion, interruption errors, permission denial and retry, and return to setup. The final layout keeps those state paths; the input engine has not been changed by the design refinements. Simulation never installs a tap. The final recovery text column has a stable width so showing hold progress cannot shift the key symbols. A normal simulated cycle verified selection, preparation, active countdown, early finish, and return-to-setup with the final SwiftUI motion. These visual transitions do not gate engine actions.

The app exposes headings, selected choices, countdown values and recovery progress through Accessibility. State announcements are implemented; actual VoiceOver speech/navigation remains untested. System-wide accessibility preferences were not changed. Some captures briefly showed Stage Manager thumbnails; full-window captures and user-supplied native screenshots were used for layout assessment.

## Coverage matrix

| Behavior | Current evidence / limit |
| --- | --- |
| Ordinary keyboard, repeat, simultaneous input | Core + adapter tests; real synthetic Quartz suppression passed. Physical keys untested. |
| Left/right Shift recovery | Distinct device bits and hold/cancel logic tested. Physical two-key hold untested. |
| Other modifiers / Caps Lock | Core/adapter handling; Caps Lock treated as a latch. Physical modifier/latch effects untested. |
| Motion, click, drag, scroll | Real synthetic stream suppression passed. Physical trackpad/mouse untested. |
| Keyboard-only and pointing-only isolation | Core tests and UI checks; physical-device isolation untested. |
| External keyboard/mouse | Same selected event category by design; no device-specific isolation. Hardware untested. |
| Fn/Globe, brightness, volume/media | Public convertible events classified, but may be handled before a session tap. Hardware untested; no comprehensive blocking promise. |
| Mission Control, Spaces, pinch/rotate, other system gestures | Only events delivered to the public tap can be filtered. Gesture paths may bypass it; untested and not promised. |
| Touch ID, power, forced shutdown, login/security | Explicitly outside coverage. No security settings changed. |
| Normal timeout and tap teardown | Observed in packaged-app real sessions, with independent termination armed. |
| Held input across start/finish | Deterministic tests; normal startup/no-held-input and timed cleanup observed. Physical stuck/missing-release cases untested. |
| UI stall | A four-second main-thread stall in the packaged app ended with `uiUnresponsive` and no remaining tap. External termination was armed. |
| Tap disablement | Own-tap disablement observed ending with `tapDisabled` and no tap about 50 ms later; no automatic re-enable. |
| Tap creation failure, permission changes | Failure handling tested/reviewed. Live permission revocation and creation-failure injection remain open. |
| Sleep/wake, display sleep, user session change | Lifecycle handlers interrupt and do not resume. Not tested live on the primary Mac. |
| Exit/crash | External watchdog terminated the test process. No claim of live crash-under-held-input validation. |

## Precise product gap

A public session event tap cannot promise that every hardware or system gesture is delivered to it. The current implementation therefore offers an everyday-input guard, with that limitation visible before Start. It does not satisfy an absolute guarantee of “no gestures or system actions.” Extending that guarantee with private APIs, root helpers or persistent system-setting changes was deliberately excluded by the task. For hardware/security controls outside coverage, follow the Mac's own cleaning instructions and power-state precautions; this app cannot substitute for them.

Before public release, use a spare device/account to complete the hardware matrix and failure-injection checks. The smallest primary-device check is one watchdog-supervised eight-second session: ordinary keys and pointer/scroll, followed by a distinct-both-Shift hold. More disruptive system gestures and permission revocation belong in isolation. Record actual observed effects rather than inferring them from the countdown.

## Reproduce automated checks

```sh
swift test --disable-sandbox
bash -n script/build_and_run.sh
python3 -c "import ast, pathlib; ast.parse(pathlib.Path('script/test_watchdog.py').read_text())"
./script/build_and_run.sh --release
codesign --verify --strict 'dist/Keydoze.app'
plutil -lint 'dist/Keydoze.app/Contents/Info.plist'
```

The local release is development signed, not notarized or published. The repository contains no production service, credentials, network dependency or privileged helper.

The final archive checksum is recorded beside the local package in `dist/Keydoze-0.1.0-local-arm64.zip.sha256`. Generated bundles and local diagnostics are excluded from source control.
