import Foundation

public enum InputScope: String, CaseIterable, Sendable {
    case both, keyboard, pointing
    public var keyboard: Bool { self != .pointing }
    public var pointing: Bool { self != .keyboard }
}

public enum EndReason: String, Sendable {
    case timedOut, recovered, cancelled, permissionDenied, tapFailed, interrupted, tapDisabled, uiUnresponsive, heldInput
}

public enum Phase: Equatable, Sendable {
    case arming, active, releasing, finished(EndReason)
    public var isFinished: Bool { if case .finished = self { true } else { false } }
}

public enum Input: Equatable, Sendable {
    case key(code: UInt16, down: Bool)
    case shift(left: Bool, down: Bool)
    case button(code: UInt32, down: Bool)
    case pointer, keyboardSystem, systemTransition, other
}

/// No characters, event payloads, or sequence history. Only transient held identities.
public struct Session: Sendable {
    public let scope: InputScope
    public let duration: Double
    public private(set) var phase: Phase = .arming
    public private(set) var deadline: Double?
    public private(set) var recoveryBegan: Double?
    public private(set) var heldKeys: Set<UInt16> = []
    public private(set) var heldButtons: Set<UInt32> = []
    private var leftShift = false
    private var rightShift = false
    private let armedAt: Double
    private var quietSince: Double
    private var releaseBegan: Double?
    private var endReason: EndReason = .timedOut

    public init(scope: InputScope, duration: Double, now: Double, permitted: Bool = true, tapCreated: Bool = true) {
        self.scope = scope
        self.duration = duration.isFinite ? min(120, max(1, duration)) : 60
        self.armedAt = now
        self.quietSince = now
        if !permitted { phase = .finished(.permissionDenied) }
        else if !tapCreated { phase = .finished(.tapFailed) }
    }

    public func remaining(at now: Double) -> Double {
        if phase == .arming { return max(0, 3 - (now - armedAt)) }
        return max(0, (deadline ?? now) - now)
    }
    public func recoveryProgress(at now: Double) -> Double {
        guard let recoveryBegan else { return 0 }
        return min(1, max(0, (now - recoveryBegan) / 2))
    }

    /// Called by the engine's independent watchdog, including when no events arrive.
    public mutating func tick(now: Double, physicalInputHeld: Bool) {
        guard !phase.isFinished else { return }
        if phase == .arming {
            if physicalInputHeld { quietSince = now }
            if now - armedAt >= 10 { interrupt(.heldInput); return }
            if now - armedAt >= 3 && now - quietSince >= 0.35 && !physicalInputHeld {
                heldKeys.removeAll(); heldButtons.removeAll()
                leftShift = false; rightShift = false
                phase = .active
                deadline = now + duration
            }
        }
        advanceTime(now: now)
        if phase == .releasing {
            if physicalInputHeld { quietSince = now }
            if !physicalInputHeld && heldKeys.isEmpty && heldButtons.isEmpty && now - quietSince >= 0.25 {
                interrupt(endReason)
            } else if now - (releaseBegan ?? now) >= 2 {
                // Hard bound beats indefinite suppression when hardware never sends release.
                interrupt(.heldInput)
            }
        }
    }

    /// true means delete this event. Nothing is buffered for subsequent replay.
    public mutating func filter(_ input: Input, now: Double) -> Bool {
        guard !phase.isFinished else { return false }
        if input == .systemTransition { interrupt(.interrupted); return false }
        if phase == .arming {
            // All-event taps also receive non-input bookkeeping events. Those must not
            // perpetually restart the hands-off preparation interval.
            if input != .other { quietSince = now }
            return false
        }
        // The callback independently enforces recovery and the absolute cleanup cap if
        // watchdog scheduling is delayed. Anchor release to the actual deadline, not now.
        advanceTime(now: now)
        if phase == .releasing, now - (releaseBegan ?? now) >= 2 {
            interrupt(heldKeys.isEmpty && heldButtons.isEmpty ? endReason : .heldInput)
        }
        guard !phase.isFinished else { return false }
        let suppress: Bool
        switch input {
        case let .key(code, down):
            suppress = scope.keyboard || code == 53 // Escape reserved in pointing mode.
            if suppress { if down { heldKeys.insert(code) } else { heldKeys.remove(code) } }
            if scope == .pointing && code == 53 && down && phase == .active {
                beginRelease(.recovered, now: now)
            }
        case let .shift(left, down):
            suppress = scope.keyboard
            if suppress {
                if left { leftShift = down } else { rightShift = down }
                let code: UInt16 = left ? 56 : 60
                if down { heldKeys.insert(code) } else { heldKeys.remove(code) }
                if leftShift && rightShift {
                    if recoveryBegan == nil { recoveryBegan = now }
                } else { recoveryBegan = nil }
            }
        case let .button(code, down):
            suppress = scope.pointing
            if suppress { if down { heldButtons.insert(code) } else { heldButtons.remove(code) } }
        case .pointer: suppress = scope.pointing
        case .keyboardSystem: suppress = scope.keyboard
        case .systemTransition:
            interrupt(.interrupted)
            return false
        case .other: suppress = scope == .both
        }
        if suppress { quietSince = now }
        return suppress
    }

    public mutating func requestStop(now: Double) {
        // A delayed UI stop must not extend a deadline or recovery already reached.
        advanceTime(now: now)
        if phase == .releasing, now - (releaseBegan ?? now) >= 2 {
            interrupt(heldKeys.isEmpty && heldButtons.isEmpty ? endReason : .heldInput)
        }
        if phase == .arming { interrupt(.cancelled) }
        else if phase == .active { beginRelease(.cancelled, now: now) }
    }

    public mutating func interrupt(_ reason: EndReason) {
        phase = .finished(reason)
        heldKeys.removeAll(); heldButtons.removeAll()
        leftShift = false; rightShift = false; recoveryBegan = nil
    }

    private mutating func advanceTime(now: Double) {
        guard phase == .active else { return }
        if let recoveryBegan, now >= recoveryBegan + 2,
           recoveryBegan + 2 < (deadline ?? .infinity) {
            beginRelease(.recovered, now: recoveryBegan + 2)
        } else if let deadline, now >= deadline {
            beginRelease(.timedOut, now: deadline)
        }
    }

    private mutating func beginRelease(_ reason: EndReason, now: Double) {
        phase = .releasing
        releaseBegan = now
        quietSince = now
        endReason = reason
        recoveryBegan = nil
    }
}
