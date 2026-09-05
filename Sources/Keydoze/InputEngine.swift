import AppKit
import ApplicationServices
import Carbon
import IOKit.hidsystem
import Synchronization
import KeydozeCore

/// A monotonic clock that advances across system sleep. Wall-clock edits cannot extend a session.
enum SessionClock {
    private static let origin = ContinuousClock.now
    static var now: Double {
        let value = origin.duration(to: .now).components
        return Double(value.seconds) + Double(value.attoseconds) / 1e18
    }
}

/// One run owns one tap. All shared mutable state is behind the mutex. The callback runs
/// on a dedicated CFRunLoop thread; a separate dispatch queue owns the watchdog.
/// Neither path synchronously calls UI, writes logs, stores characters, or waits on an actor.
final class InputEngine: Sendable {
    struct Snapshot: Sendable {
        let session: Session
        let tapInstalled: Bool
        let keysHeld: Bool
        let buttonsHeld: Bool
        #if DEBUG
        let suppressedKeyboardEvents: Int
        let suppressedPointingEvents: Int
        #endif
    }
    // CF run loops and Mach ports support cross-thread stop/invalidation. This narrow
    // wrapper shares only those handles; all ownership changes remain mutex-protected.
    private struct TapResources: @unchecked Sendable {
        let tap: CFMachPort
        let loop: CFRunLoop
    }
    private struct State {
        var session: Session
        var resources: TapResources?
        var uiHeartbeat: Double
        var lastPermissionCheck: Double
        var lastTapHeartbeat: Double
        var keysHeld = false
        var buttonsHeld = false
        #if DEBUG
        var suppressedKeyboardEvents = 0
        var suppressedPointingEvents = 0
        #endif
    }
    private let state: Mutex<State>
    private let watchdogQueue = DispatchQueue(label: "app.cleanmode.watchdog", qos: .userInteractive)
    private let watchdog: DispatchSourceTimer

    init(scope: InputScope, duration: Double) {
        let now = SessionClock.now
        state = Mutex(State(session: Session(scope: scope, duration: duration, now: now,
                                             permitted: AXIsProcessTrusted()),
                            uiHeartbeat: now, lastPermissionCheck: now, lastTapHeartbeat: now))
        watchdog = DispatchSource.makeTimerSource(queue: watchdogQueue)
        // Arm this before the filtering thread can create its tap.
        watchdog.schedule(deadline: .now(), repeating: .milliseconds(25), leeway: .milliseconds(5))
        watchdog.setEventHandler { [weak self] in self?.watchdogTick() }
        watchdog.resume()
        let thread = Thread { [self] in runTap() }
        thread.name = "Keydoze event filter"
        thread.qualityOfService = .userInteractive
        thread.start()
    }

    deinit { watchdog.cancel() }

    func snapshot() -> Snapshot {
        state.withLock {
            #if DEBUG
            Snapshot(session: $0.session, tapInstalled: $0.resources != nil, keysHeld: $0.keysHeld, buttonsHeld: $0.buttonsHeld,
                     suppressedKeyboardEvents: $0.suppressedKeyboardEvents, suppressedPointingEvents: $0.suppressedPointingEvents)
            #else
            Snapshot(session: $0.session, tapInstalled: $0.resources != nil, keysHeld: $0.keysHeld, buttonsHeld: $0.buttonsHeld)
            #endif
        }
    }
    func uiHeartbeat() { state.withLock { $0.uiHeartbeat = SessionClock.now } }
    func requestStop() {
        state.withLock { $0.session.requestStop(now: SessionClock.now) }
        closeIfFinished()
    }
    func interrupt(_ reason: EndReason = .interrupted) {
        state.withLock { $0.session.interrupt(reason) }
        closeIfFinished()
    }

    #if DEBUG
    /// Test-only fault injection; disable this session's tap, never another process's.
    func debugDisableTap() {
        if let resources = state.withLock({ $0.resources }) {
            CGEvent.tapEnable(tap: resources.tap, enable: false)
        }
    }
    #endif

    private func runTap() {
        guard !snapshot().session.phase.isFinished else { closeIfFinished(); return }
        // AX is tested in this packaged process, never inferred from Terminal/Xcode's grants.
        guard AXIsProcessTrusted(), !IsSecureEventInputEnabled() else {
            interrupt(.permissionDenied); return
        }
        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
                                         options: .defaultTap, eventsOfInterest: .max,
                                         callback: { _, type, event, context in
            guard let context else { return Unmanaged.passUnretained(event) }
            return Unmanaged<InputEngine>.fromOpaque(context).takeUnretainedValue().receive(type, event)
        }, userInfo: context) else { interrupt(.tapFailed); return }
        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            CFMachPortInvalidate(tap); interrupt(.tapFailed); return
        }
        let loop = CFRunLoopGetCurrent()!
        let resources = TapResources(tap: tap, loop: loop)
        let installed = state.withLock { value in
            guard !value.session.phase.isFinished else { return false }
            value.resources = resources
            return true
        }
        guard installed else { CFMachPortInvalidate(tap); return }
        CFRunLoopAddSource(loop, source, .commonModes)
        // Tap creation enables it. Never re-enable after an interruption or timeout.
        while !snapshot().session.phase.isFinished {
            state.withLock { $0.lastTapHeartbeat = SessionClock.now }
            CFRunLoopRunInMode(.defaultMode, 0.05, false)
        }
        CFRunLoopRemoveSource(loop, source, .commonModes)
        closeIfFinished()
    }

    private func receive(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            interrupt(.tapDisabled)
            return Unmanaged.passUnretained(event)
        }
        let now = SessionClock.now
        let input = Self.classify(type, event)
        let suppress = state.withLock { value in
            value.lastTapHeartbeat = now
            let suppress = value.session.filter(input, now: now)
            #if DEBUG
            if suppress {
                switch input {
                case .key, .shift, .keyboardSystem: value.suppressedKeyboardEvents += 1
                case .button, .pointer: value.suppressedPointingEvents += 1
                default: break
                }
            }
            #endif
            return suppress
        }
        if input == .systemTransition { closeIfFinished() }
        return suppress ? nil : Unmanaged.passUnretained(event)
    }

    private func watchdogTick() {
        let now = SessionClock.now
        let preflight = state.withLock { value -> (Bool, Bool, InputScope) in
            let check = now - value.lastPermissionCheck >= 0.5
            if check { value.lastPermissionCheck = now }
            return (!value.session.phase.isFinished, check, value.session.scope)
        }
        guard preflight.0 else { closeIfFinished(); return }
        // No keystrokes are collected: this is only a boolean held-input safety check.
        let held = Self.physicalInputState()
        let accessOK = !preflight.1 || (AXIsProcessTrusted() && !IsSecureEventInputEnabled())
        state.withLock { value in
            value.keysHeld = held.keys
            value.buttonsHeld = held.buttons
            if !accessOK { value.session.interrupt(.permissionDenied) }
            else if now - value.uiHeartbeat > 2.5 { value.session.interrupt(.uiUnresponsive) }
            else if now - value.lastTapHeartbeat > 1 { value.session.interrupt(.tapDisabled) }
            else if let resources = value.resources, !CGEvent.tapIsEnabled(tap: resources.tap) {
                value.session.interrupt(.tapDisabled)
            } else if value.resources != nil {
                value.session.tick(now: now, physicalInputHeld: held.keys || held.buttons)
            }
        }
        closeIfFinished()
    }

    /// Take ownership under the mutex, then tear down outside it. This also runs from the
    /// watchdog if the event thread/UI stop servicing work. CFMachPort invalidation is idempotent.
    private func closeIfFinished() {
        let resources = state.withLock { value -> TapResources? in
            guard value.session.phase.isFinished else { return nil }
            let resources = value.resources
            value.resources = nil
            return resources
        }
        if let resources {
            CGEvent.tapEnable(tap: resources.tap, enable: false)
            CFMachPortInvalidate(resources.tap)
            CFRunLoopStop(resources.loop)
        }
        if snapshot().session.phase.isFinished { watchdog.cancel() }
    }

    private static func physicalInputState() -> (keys: Bool, buttons: Bool) {
        // Caps Lock is a latch, not a key that repeats. Its enabled state must not
        // prevent a session. Other modifiers are included so a preexisting chord cannot leak.
        let keys = (UInt16(0)..<128).contains { code in
            code != 57 && CGEventSource.keyState(.hidSystemState, key: code)
        }
        let buttons = (UInt32(0)..<32).contains { code in
            guard let button = CGMouseButton(rawValue: code) else { return false }
            return CGEventSource.buttonState(.hidSystemState, button: button)
        }
        return (keys, buttons)
    }

    // Internal so adapter tests can exercise real CGEvent conversion without installing a tap.
    static func classify(_ type: CGEventType, _ event: CGEvent) -> Input {
        switch type {
        case .keyDown, .keyUp:
            return .key(code: UInt16(clamping: event.getIntegerValueField(.keyboardEventKeycode)), down: type == .keyDown)
        case .flagsChanged:
            let code = UInt16(clamping: event.getIntegerValueField(.keyboardEventKeycode))
            // Caps Lock flags are a latch transition, not a down/up pair to drain.
            if code == 57 { return .keyboardSystem }
            if code == 56 || code == 60 {
                let mask = code == 56 ? NX_DEVICELSHIFTKEYMASK : NX_DEVICERSHIFTKEYMASK
                return .shift(left: code == 56, down: event.flags.rawValue & UInt64(mask) != 0)
            }
            return .key(code: code, down: CGEventSource.keyState(.hidSystemState, key: code))
        case .leftMouseDown, .rightMouseDown, .otherMouseDown, .leftMouseUp, .rightMouseUp, .otherMouseUp:
            return .button(code: UInt32(clamping: event.getIntegerValueField(.mouseEventButtonNumber)),
                           down: type == .leftMouseDown || type == .rightMouseDown || type == .otherMouseDown)
        case .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged, .scrollWheel, .tabletPointer, .tabletProximity:
            return .pointer
        default:
            // Conversion is optional. Public AppKit gestures may have no Quartz event at all.
            if let native = NSEvent(cgEvent: event) {
                switch native.type {
                case .gesture, .magnify, .swipe, .rotate, .beginGesture, .endGesture, .smartMagnify, .pressure, .directTouch:
                    return .pointer
                case .systemDefined:
                    switch Int32(native.subtype.rawValue) {
                    case NX_SUBTYPE_AUX_CONTROL_BUTTONS: return .keyboardSystem
                    case NX_SUBTYPE_AUX_MOUSE_BUTTONS: return .pointer
                    case NX_SUBTYPE_POWER_KEY, NX_SUBTYPE_SLEEP_EVENT, NX_SUBTYPE_RESTART_EVENT,
                         NX_SUBTYPE_SHUTDOWN_EVENT, NX_SUBTYPE_ACCESSIBILITY: return .systemTransition
                    default: break
                    }
                default: break
                }
            }
            return .other
        }
    }
}
