import AppKit
import IOKit.hidsystem
import Testing
import KeydozeCore
@testable import Keydoze

/// Constructs events in memory only. No event is posted and no InputEngine instance or tap is created.
@Suite("macOS event classification without input interception")
struct EventClassificationTests {
    private func event(_ type: CGEventType, key: Int64 = 0, flags: UInt64 = 0) throws -> CGEvent {
        let event = try #require(CGEvent(source: nil))
        event.type = type
        event.setIntegerValueField(.keyboardEventKeycode, value: key)
        event.flags = CGEventFlags(rawValue: flags)
        return event
    }

    private func classify(_ event: CGEvent) -> Input {
        InputEngine.classify(event.type, event)
    }

    private func systemEvent(subtype: Int32, data: Int = 0) throws -> CGEvent {
        let native = try #require(NSEvent.otherEvent(with: .systemDefined, location: .zero,
            modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil,
            subtype: Int16(subtype), data1: data, data2: 0))
        return try #require(native.cgEvent)
    }

    @Test("Key down and up preserve virtual key identity", arguments: [UInt16(0), 53, 123, 126])
    func keyPairs(code: UInt16) throws {
        let down = try #require(CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: true))
        let up = try #require(CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: false))
        #expect(classify(down) == .key(code: code, down: true))
        #expect(classify(up) == .key(code: code, down: false))
        down.setIntegerValueField(.keyboardEventAutorepeat, value: 1)
        #expect(classify(down) == .key(code: code, down: true))
    }

    @Test("Each Shift uses its device-specific flag, not the shared Shift flag")
    func distinctShiftFlags() throws {
        let aggregate = CGEventFlags.maskShift.rawValue
        let left = UInt64(NX_DEVICELSHIFTKEYMASK)
        let right = UInt64(NX_DEVICERSHIFTKEYMASK)
        for (code, isLeft, own, other) in [(Int64(56), true, left, right), (60, false, right, left)] {
            #expect(classify(try event(.flagsChanged, key: code, flags: aggregate | own)) == .shift(left: isLeft, down: true))
            #expect(classify(try event(.flagsChanged, key: code, flags: aggregate | own | other)) == .shift(left: isLeft, down: true))
            // Releasing one Shift while the other stays held keeps the aggregate flag set.
            #expect(classify(try event(.flagsChanged, key: code, flags: aggregate | other)) == .shift(left: isLeft, down: false))
            #expect(classify(try event(.flagsChanged, key: code, flags: aggregate)) == .shift(left: isLeft, down: false))
            #expect(classify(try event(.flagsChanged, key: code)) == .shift(left: isLeft, down: false))
        }
    }

    @Test("Actual Shift event conversion starts and cancels the two-key recovery hold")
    func shiftRecoveryThroughAdapter() throws {
        var session = Session(scope: .both, duration: 60, now: 0)
        session.tick(now: 3, physicalInputHeld: false)
        let left = UInt64(NX_DEVICELSHIFTKEYMASK) | CGEventFlags.maskShift.rawValue
        let both = left | UInt64(NX_DEVICERSHIFTKEYMASK)
        let leftSuppressed = session.filter(classify(try event(.flagsChanged, key: 56, flags: left)), now: 4)
        #expect(leftSuppressed)
        #expect(session.recoveryBegan == nil)
        let rightSuppressed = session.filter(classify(try event(.flagsChanged, key: 60, flags: both)), now: 5)
        #expect(rightSuppressed)
        #expect(session.recoveryBegan == 5)
        let releaseSuppressed = session.filter(classify(try event(.flagsChanged, key: 60, flags: left)), now: 6)
        #expect(releaseSuppressed)
        #expect(session.recoveryBegan == nil)
        #expect(session.phase == .active)
    }

    @Test("Caps Lock latch transitions never become a held key", arguments: [UInt64(0), CGEventFlags.maskAlphaShift.rawValue])
    func capsLockLatch(flags: UInt64) throws {
        let input = classify(try event(.flagsChanged, key: 57, flags: flags))
        #expect(input == .keyboardSystem)
        var session = Session(scope: .keyboard, duration: 60, now: 0)
        session.tick(now: 3, physicalInputHeld: false)
        let suppressed = session.filter(input, now: 4)
        #expect(suppressed)
        #expect(session.heldKeys.isEmpty)
        // CoreGraphics normalizes a Caps Lock keyboard constructor to flagsChanged too.
        for down in [true, false] {
            let caps = try #require(CGEvent(keyboardEventSource: nil, virtualKey: 57, keyDown: down))
            #expect(classify(caps) == .keyboardSystem)
        }
    }

    @Test("Mouse button pairs retain each button number")
    func mouseButtons() throws {
        let pairs: [(CGEventType, CGEventType, UInt32)] = [
            (.leftMouseDown, .leftMouseUp, 0), (.rightMouseDown, .rightMouseUp, 1),
            (.otherMouseDown, .otherMouseUp, 2), (.otherMouseDown, .otherMouseUp, 7)
        ]
        for (downType, upType, code) in pairs {
            for (type, down) in [(downType, true), (upType, false)] {
                let event = try event(type)
                event.setIntegerValueField(.mouseEventButtonNumber, value: Int64(code))
                #expect(classify(event) == .button(code: code, down: down))
            }
        }
    }

    @Test("Movement, all drags, scrolling, and tablet events map to pointing input")
    func pointingEvents() throws {
        for type: CGEventType in [.mouseMoved, .leftMouseDragged, .rightMouseDragged,
                                 .otherMouseDragged, .scrollWheel, .tabletPointer, .tabletProximity] {
            #expect(classify(try event(type)) == .pointer)
        }
        let scroll = try #require(CGEvent(scrollWheelEvent2Source: nil, units: .pixel,
                                         wheelCount: 2, wheel1: 20, wheel2: -5, wheel3: 0))
        #expect(classify(scroll) == .pointer)
    }

    @Test("Convertible media button down and up are keyboard system input", arguments: [0xA, 0xB])
    func mediaButtons(state: Int) throws {
        let event = try systemEvent(subtype: NX_SUBTYPE_AUX_CONTROL_BUTTONS,
                                    data: (Int(NX_KEYTYPE_SOUND_UP) << 16) | (state << 8))
        #expect(classify(event) == .keyboardSystem)
    }

    @Test("Convertible auxiliary mouse events map to pointing input")
    func auxiliaryMouse() throws {
        #expect(classify(try systemEvent(subtype: NX_SUBTYPE_AUX_MOUSE_BUTTONS)) == .pointer)
    }

    @Test("Convertible power and security events stay on the system transition path", arguments: [
        Int32(NX_SUBTYPE_POWER_KEY), NX_SUBTYPE_SLEEP_EVENT, NX_SUBTYPE_RESTART_EVENT,
        NX_SUBTYPE_SHUTDOWN_EVENT, NX_SUBTYPE_ACCESSIBILITY
    ])
    func systemTransitions(subtype: Int32) throws {
        let input = classify(try systemEvent(subtype: subtype))
        #expect(input == .systemTransition)
        var session = Session(scope: .both, duration: 60, now: 0)
        session.tick(now: 3, physicalInputHeld: false)
        let suppressed = session.filter(input, now: 4)
        #expect(!suppressed)
        #expect(session.phase == .finished(.interrupted))
    }

    @Test("Unknown system subtypes remain unclassified")
    func unknownSystemSubtype() throws {
        #expect(classify(try systemEvent(subtype: 1234)) == .other)
    }
}
