# Research and implementation decisions

Inspected 6 September 2026 on macOS 27.0 (26A5421a), Xcode 27.0 (27A5228h), macOS 27 SDK. Deployment target is macOS 26.0; that is a compatibility target, not a claim of testing on macOS 26.

## Plan

1. Establish public-API filtering, independent recovery and packaged-app permission identity.
2. Build a compact native SwiftUI interface with AppKit lifecycle integration and explicit permission states.
3. Exercise deterministic safety logic, bounded live sessions, and visibly labelled simulation states.
4. Inspect actual native windows, refine accessibility/layout, then document coverage and package for local use.

## Filtering and recovery

Use a session-level, head-insert, active Quartz event tap. A listen-only tap cannot suppress events. The SDK documents returning `nil` to delete a delivered event and still documents HID-level tap creation as requiring root; the app does not use root, drivers or private APIs.

The all-events mask can receive events beyond public keyboard/mouse cases. Combined mode drops delivered input; partial modes classify documented Quartz cases and convertible public AppKit gesture/media types. This does not imply that upstream system gestures, Fn/Globe actions, or hardware controls are prevented. Power, sleep, shutdown and security-related public system-event subtypes are passed through and end the session.

The event callback runs on a dedicated CFRunLoop thread. A separate dispatch watchdog advances a `ContinuousClock` deadline, checks tap health and permission, and watches UI responsiveness. The callback independently applies the deadline and cleanup bound. Unexpected interruption always ends the run; the tap is never silently re-enabled.

Preparation requires three seconds and a 350 ms quiet interval with no held keys/buttons, with a ten-second preparation limit. Non-input bookkeeping events cannot extend preparation. Caps Lock is treated as a latch rather than a held/repeating key. Both Shift keys held for two seconds provide early recovery when keyboard input is selected; pointing-only mode reserves Escape instead. Normal completion drains held input for at most two additional seconds. Missing releases or a platform-level failure cannot be made absolutely safe by an app; input availability takes priority over keeping a session active.

Authoritative sources:

- [CGEvent tap creation](https://developer.apple.com/documentation/coregraphics/cgevent/tapcreate(tap:place:options:eventsofinterest:callback:userinfo:)) and installed `CoreGraphics.framework/Headers/CGEvent.h`.
- [CGEvent tap callback](https://developer.apple.com/documentation/coregraphics/cgeventtapcallback).
- Installed `AppKit.framework/Headers/NSEvent.h`: nullable Quartz/AppKit conversion and public gesture types.
- Installed `IOKit.framework/Headers/hidsystem/IOLLEvent.h`: distinct Shift masks and system-defined subtypes.

## Permissions and signing

Request Accessibility only. Apple DTS explains that Accessibility supplies event posting and listening; Input Monitoring supplies listening and is not additionally required for this design. On this installed macOS 27 build, Settings labels the relevant pane **Device Control and Data Access**. Its capabilities are broader than the app's actual usage; Keydoze does not access mail, contacts, photos, or the screen.

The first ad-hoc prototype lost authorization after rebuilding. The app correctly saw AX denial even though Settings displayed an enabled row. With user approval, only `app.cleanmode.mac`'s Accessibility record was reset and the development-signed build reauthorized. The app then reported permission granted, and subsequent builds retained it. The build script uses an existing Apple Development identity consistently for both local debug and optimized builds, or an explicit `KEYDOZE_SIGN_IDENTITY`. It does not silently switch an authorized local release back to ad-hoc signing.

- [Apple DTS: Accessibility versus Input Monitoring](https://developer.apple.com/forums/thread/828052).
- [TN3127: code signing requirements and privacy identity](https://developer.apple.com/documentation/technotes/tn3127-inside-code-signing-requirements).
- [Apple DTS: targeted tccutil reset](https://developer.apple.com/forums/thread/696174).

A developer has reported a systemwide input hang when Accessibility is revoked during an active tap, with Apple DTS requesting a sysdiagnose for FB24619068. This is a reported platform issue, not a bug reproduced or ruled out here. Live revocation testing belongs on an isolated account/device, not the user's primary session. [Report and DTS discussion](https://developer.apple.com/forums/thread/844416).

## Native design references

The composition draws from the quiet chrome and hierarchy in [Arc](https://arc.net/), whitespace and readable typography in [Craft](https://www.craft.do/write), compact utility controls in [Raycast](https://www.raycast.com/), cohesive surfaces in [Liqoria](https://www.liqoria.com/), visual priority in [Wallper](https://www.wallper.app/), and direct action/result feedback in [CleanShot X](https://cleanshot.com/).

The implementation uses one native window, semantic backgrounds/text, a restrained mint accent, locally drawn device feedback, a native segmented selection and duration control, and a single prominent glass action. During cleaning the timer and recovery instruction take priority. Increased contrast/reduced transparency use a solid native action style; reduced motion removes view-state transitions.

- [Apple materials HIG](https://developer.apple.com/design/human-interface-guidelines/materials).
- [Adopting Liquid Glass](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass).
- Installed Apple `SwiftUI-Implementing-Liquid-Glass-Design.md`.

## Evidence discipline

UI simulation never creates a tap and is labelled on screen. Computer-use actions may use Accessibility or process-targeted injection; they must not be treated as physical keyboard/trackpad validation. The debug receipt view compares aggregate events delivered to the app against events suppressed by the tap, without storing characters or raw events. All such instrumentation is excluded from release builds.

The Stage Manager thumbnail was initially mistaken by capture tooling for the full app window. Opening the app normally before inspection resolved that observation problem. Existing development screen-capture access was verified without requesting a new grant; the utility itself does not request Screen Recording.
