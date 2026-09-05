import Testing
@testable import KeydozeCore

@Suite("Session safety with synthetic input")
struct SessionTests {
    private func active(scope: InputScope = .both, duration: Double = 60) -> Session {
        var session = Session(scope: scope, duration: duration, now: 0)
        session.tick(now: 3, physicalInputHeld: false)
        return session
    }

    private func expectFilter(_ input: Input, by session: inout Session, now: Double,
                              suppressed expected: Bool = true,
                              sourceLocation: SourceLocation = #_sourceLocation) {
        let suppressed = session.filter(input, now: now)
        #expect(suppressed == expected, sourceLocation: sourceLocation)
    }

    @Test("Arming passes input and waits for release and a quiet interval")
    func armingWaitsForQuiet() {
        var session = Session(scope: .both, duration: 60, now: 0)
        expectFilter(.key(code: 0, down: true), by: &session, now: 2.9, suppressed: false)
        session.tick(now: 3, physicalInputHeld: true)
        #expect(session.phase == .arming)
        expectFilter(.key(code: 0, down: false), by: &session, now: 3.1, suppressed: false)
        session.tick(now: 3.4, physicalInputHeld: false)
        #expect(session.phase == .arming)
        session.tick(now: 3.5, physicalInputHeld: false)
        #expect(session.phase == .active)
        #expect(session.deadline == 63.5)
        #expect(session.heldKeys.isEmpty)
    }

    @Test("A held input cannot keep arming alive indefinitely")
    func armingHasHardLimit() {
        var session = Session(scope: .both, duration: 60, now: 0)
        session.tick(now: 9.9, physicalInputHeld: true)
        #expect(session.phase == .arming)
        session.tick(now: 10, physicalInputHeld: true)
        #expect(session.phase == .finished(.heldInput))
        expectFilter(.pointer, by: &session, now: 11, suppressed: false)
    }

    @Test("Deadline and release complete without incoming events")
    func deadlineNeedsNoInput() {
        var session = active(duration: 10)
        #expect(session.remaining(at: 12.5) == 0.5)
        session.tick(now: 12.9, physicalInputHeld: false)
        #expect(session.phase == .active)
        session.tick(now: 13, physicalInputHeld: false)
        #expect(session.phase == .releasing)
        session.tick(now: 13.25, physicalInputHeld: false)
        #expect(session.phase == .finished(.timedOut))
        #expect(session.remaining(at: 100) == 0)
    }

    @Test("An arriving event enforces a deadline even before the watchdog ticks")
    func callbackEnforcesDeadline() {
        var session = active(duration: 10)
        expectFilter(.key(code: 0, down: true), by: &session, now: 13.1)
        #expect(session.phase == .releasing)
        expectFilter(.key(code: 0, down: false), by: &session, now: 13.2)
        session.tick(now: 13.5, physicalInputHeld: false)
        #expect(session.phase == .finished(.timedOut))
    }

    @Test("Duration is bounded and nonfinite input gets a safe default", arguments: [
        (-10.0, 1.0), (0.0, 1.0), (1.0, 1.0), (60.0, 60.0),
        (120.0, 120.0), (121.0, 120.0), (Double.infinity, 60.0),
        (-Double.infinity, 60.0), (Double.nan, 60.0)
    ])
    func durationClamp(values: (Double, Double)) {
        let session = active(duration: values.0)
        #expect(session.duration == values.1)
        #expect(session.deadline == 3 + values.1)
    }

    @Test("Both distinct Shift keys recover only after the full hold")
    func bothShiftRecovery() {
        var session = active()
        expectFilter(.shift(left: true, down: true), by: &session, now: 4)
        expectFilter(.shift(left: true, down: true), by: &session, now: 4.1)
        #expect(session.recoveryBegan == nil)
        expectFilter(.shift(left: false, down: true), by: &session, now: 5)
        #expect(session.recoveryProgress(at: 6) == 0.5)
        session.tick(now: 6.99, physicalInputHeld: true)
        #expect(session.phase == .active)
        session.tick(now: 7, physicalInputHeld: true)
        #expect(session.phase == .releasing)
        expectFilter(.shift(left: true, down: false), by: &session, now: 7.1)
        expectFilter(.shift(left: false, down: false), by: &session, now: 7.2)
        session.tick(now: 7.5, physicalInputHeld: false)
        #expect(session.phase == .finished(.recovered))
    }

    @Test("Releasing either Shift cancels progress and a new hold starts over")
    func recoveryCancellation() {
        var session = active()
        _ = session.filter(.shift(left: true, down: true), now: 4)
        _ = session.filter(.shift(left: false, down: true), now: 4.1)
        _ = session.filter(.shift(left: true, down: false), now: 5.9)
        #expect(session.recoveryProgress(at: 6.1) == 0)
        session.tick(now: 6.1, physicalInputHeld: true)
        #expect(session.phase == .active)
        _ = session.filter(.shift(left: true, down: true), now: 7)
        session.tick(now: 8.9, physicalInputHeld: true)
        #expect(session.phase == .active)
        session.tick(now: 9, physicalInputHeld: true)
        #expect(session.phase == .releasing)
    }

    @Test("Keyboard-only leaves pointer input usable")
    func keyboardScope() {
        var session = active(scope: .keyboard)
        expectFilter(.button(code: 0, down: true), by: &session, now: 4, suppressed: false)
        expectFilter(.pointer, by: &session, now: 4.1, suppressed: false)
        expectFilter(.key(code: 0, down: true), by: &session, now: 4.2)
        expectFilter(.keyboardSystem, by: &session, now: 4.3)
        #expect(session.heldButtons.isEmpty)
        session.requestStop(now: 5)
        #expect(session.phase == .releasing)
    }

    @Test("Pointing-only leaves typing and Shift usable, but consumes Escape recovery")
    func pointingScope() {
        var session = active(scope: .pointing)
        expectFilter(.key(code: 0, down: true), by: &session, now: 4, suppressed: false)
        expectFilter(.shift(left: true, down: true), by: &session, now: 4.1, suppressed: false)
        expectFilter(.shift(left: false, down: true), by: &session, now: 4.2, suppressed: false)
        expectFilter(.keyboardSystem, by: &session, now: 4.3, suppressed: false)
        #expect(session.recoveryBegan == nil)
        #expect(session.heldKeys.isEmpty)
        expectFilter(.pointer, by: &session, now: 4.4)
        expectFilter(.key(code: 53, down: true), by: &session, now: 5)
        #expect(session.phase == .releasing)
        expectFilter(.key(code: 53, down: false), by: &session, now: 5.1)
        session.tick(now: 5.4, physicalInputHeld: false)
        #expect(session.phase == .finished(.recovered))
    }

    @Test("Repeats retain one held identity and the final release is consumed")
    func repeatedAndSimultaneousKeysDrain() {
        var session = active()
        for time in [4.0, 4.1, 4.2] {
            expectFilter(.key(code: 0, down: true), by: &session, now: time)
        }
        expectFilter(.key(code: 1, down: true), by: &session, now: 4.3)
        #expect(session.heldKeys == [0, 1])
        session.requestStop(now: 5)
        expectFilter(.key(code: 0, down: false), by: &session, now: 5.1)
        session.tick(now: 5.4, physicalInputHeld: true)
        #expect(session.phase == .releasing)
        expectFilter(.key(code: 1, down: false), by: &session, now: 5.5)
        session.tick(now: 5.8, physicalInputHeld: false)
        #expect(session.phase == .finished(.cancelled))
        #expect(session.heldKeys.isEmpty)
        expectFilter(.key(code: 0, down: true), by: &session, now: 6, suppressed: false)
    }

    @Test("Drag button releases are consumed before restoring pointing input")
    func heldButtonDrains() {
        var session = active()
        expectFilter(.button(code: 0, down: true), by: &session, now: 4)
        session.requestStop(now: 5)
        expectFilter(.pointer, by: &session, now: 5.1)
        session.tick(now: 5.4, physicalInputHeld: true)
        #expect(session.phase == .releasing)
        expectFilter(.button(code: 0, down: false), by: &session, now: 5.5)
        session.tick(now: 5.8, physicalInputHeld: false)
        #expect(session.phase == .finished(.cancelled))
        #expect(session.heldButtons.isEmpty)
    }

    @Test("Missing release events cannot cause indefinite suppression")
    func releaseHasHardLimit() {
        var session = active()
        _ = session.filter(.key(code: 0, down: true), now: 4)
        _ = session.filter(.button(code: 0, down: true), now: 4.1)
        session.requestStop(now: 5)
        session.tick(now: 6.99, physicalInputHeld: true)
        #expect(session.phase == .releasing)
        session.tick(now: 7, physicalInputHeld: true)
        #expect(session.phase == .finished(.heldInput))
        #expect(session.heldKeys.isEmpty)
        #expect(session.heldButtons.isEmpty)
        expectFilter(.pointer, by: &session, now: 7.1, suppressed: false)
    }

    @Test("Permission denial and tap failure never begin suppression", arguments: [
        (false, true, EndReason.permissionDenied),
        (true, false, EndReason.tapFailed),
        (false, false, EndReason.permissionDenied)
    ])
    func startupFailure(values: (Bool, Bool, EndReason)) {
        var session = Session(scope: .both, duration: 60, now: 0,
                              permitted: values.0, tapCreated: values.1)
        #expect(session.phase == .finished(values.2))
        #expect(session.deadline == nil)
        session.tick(now: 3, physicalInputHeld: false)
        expectFilter(.key(code: 0, down: true), by: &session, now: 4, suppressed: false)
        #expect(session.phase == .finished(values.2))
    }

    @Test("Interruption clears transient input and cannot automatically restart", arguments: [
        EndReason.interrupted, .tapDisabled, .uiUnresponsive, .permissionDenied, .tapFailed
    ])
    func interruptionFailsOpen(reason: EndReason) {
        var session = active()
        _ = session.filter(.key(code: 0, down: true), now: 4)
        _ = session.filter(.button(code: 0, down: true), now: 4.1)
        _ = session.filter(.shift(left: true, down: true), now: 4.2)
        _ = session.filter(.shift(left: false, down: true), now: 4.3)
        session.interrupt(reason)
        #expect(session.phase == .finished(reason))
        #expect(session.heldKeys.isEmpty)
        #expect(session.heldButtons.isEmpty)
        #expect(session.recoveryBegan == nil)
        for time in [5.0, 20.0, 100.0] {
            session.tick(now: time, physicalInputHeld: false)
            session.requestStop(now: time)
            expectFilter(.pointer, by: &session, now: time, suppressed: false)
            expectFilter(.key(code: 0, down: true), by: &session, now: time, suppressed: false)
            #expect(session.phase == .finished(reason))
        }
        let relaunched = Session(scope: .both, duration: 60, now: 200)
        #expect(relaunched.phase == .arming)
        #expect(relaunched.heldKeys.isEmpty)
        #expect(relaunched.deadline == nil)
    }

    @Test("Cancel during arming finishes immediately without filtering")
    func cancelArming() {
        var session = Session(scope: .both, duration: 60, now: 0)
        session.requestStop(now: 1)
        #expect(session.phase == .finished(.cancelled))
        session.tick(now: 3, physicalInputHeld: false)
        expectFilter(.pointer, by: &session, now: 4, suppressed: false)
        #expect(session.deadline == nil)
    }
}

@Test("Callbacks enforce the absolute release cap when the watchdog stalls")
func callbackOnlyDeadlineCap() {
    var session = Session(scope: .both, duration: 1, now: 0)
    session.tick(now: 3, physicalInputHeld: false)
    let decision1 = session.filter(.key(code: 0, down: true), now: 4.1)
    #expect(decision1)
    #expect(session.phase == .releasing)
    let decision2 = session.filter(.key(code: 0, down: true), now: 6.01)
    #expect(!decision2)
    #expect(session.phase == .finished(.heldInput))
    #expect(session.heldKeys.isEmpty)
}

@Test("A first callback long after the deadline fails open immediately")
func callbackAfterLongDelay() {
    var session = Session(scope: .both, duration: 1, now: 0)
    session.tick(now: 3, physicalInputHeld: false)
    let decision3 = session.filter(.pointer, now: 100)
    #expect(!decision3)
    #expect(session.phase == .finished(.timedOut))
}

@Test("Callbacks recognize both-Shift recovery without watchdog ticks")
func callbackOnlyRecovery() {
    var session = Session(scope: .both, duration: 60, now: 0)
    session.tick(now: 3, physicalInputHeld: false)
    let decision4 = session.filter(.shift(left: true, down: true), now: 4)
    #expect(decision4)
    let decision5 = session.filter(.shift(left: false, down: true), now: 4.1)
    #expect(decision5)
    let decision6 = session.filter(.pointer, now: 6.11)
    #expect(decision6)
    #expect(session.phase == .releasing)
    let decision7 = session.filter(.pointer, now: 8.11)
    #expect(!decision7)
    #expect(session.phase == .finished(.heldInput))
}

@Test("A late Stop preserves the deadline and its absolute release cap",
      arguments: [4.1, 6.0, 100.0], [false, true])
func lateStopPreservesDeadline(stopAt: Double, keyHeld: Bool) {
    var session = Session(scope: .both, duration: 1, now: 0)
    session.tick(now: 3, physicalInputHeld: false)
    if keyHeld { _ = session.filter(.key(code: 0, down: true), now: 3.5) }
    session.requestStop(now: stopAt)
    let reason: EndReason = keyHeld ? .heldInput : .timedOut
    #expect(session.phase == (stopAt < 6 ? .releasing : .finished(reason)))
    let suppressed = session.filter(.key(code: 1, down: true), now: max(6.01, stopAt + 0.1))
    #expect(!suppressed)
    #expect(session.phase == .finished(reason))
    #expect(session.heldKeys.isEmpty)
}

@Test("Power and security transitions are passed through and end protection", arguments: InputScope.allCases)
func systemTransitionFailsOpen(scope: InputScope) {
    var session = Session(scope: scope, duration: 60, now: 0)
    session.tick(now: 3, physicalInputHeld: false)
    let suppressed = session.filter(.systemTransition, now: 4)
    #expect(!suppressed)
    #expect(session.phase == .finished(.interrupted))
}

@Test("Non-input bookkeeping cannot perpetually prevent preparation")
func preparationIgnoresBookkeeping() {
    var session = Session(scope: .both, duration: 60, now: 0)
    for step in 1...60 {
        let now = Double(step) / 20
        let suppressed = session.filter(.other, now: now)
        #expect(!suppressed)
        session.tick(now: now, physicalInputHeld: false)
    }
    #expect(session.phase == .active)
    #expect(session.deadline == 63)
}

@Test("System transitions cancel preparation too")
func systemTransitionDuringPreparation() {
    var session = Session(scope: .both, duration: 60, now: 0)
    let suppressed = session.filter(.systemTransition, now: 1)
    #expect(!suppressed)
    #expect(session.phase == .finished(.interrupted))
}
