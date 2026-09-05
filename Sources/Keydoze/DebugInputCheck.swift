#if DEBUG
import AppKit
import SwiftUI
import Observation
import IOKit.hidsystem

/// Development-only, in-app receipt counters. No characters or raw events are retained.
/// A real session still requires clicking Start; launching this view never blocks input.
@MainActor @Observable final class DebugInputReceipt {
    var keyboardEvents = 0
    var pointerEvents = 0
    private var monitor: Any?
    private var syntheticTask: Task<Void, Never>?
    func start() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged, .leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp, .scrollWheel, .mouseMoved]) { [weak self] event in
            MainActor.assumeIsolated {
                switch event.type {
                case .keyDown, .keyUp, .flagsChanged: self?.keyboardEvents += 1
                default: self?.pointerEvents += 1
                }
            }
            return event
        }
    }
    func stop() { syntheticTask?.cancel(); if let monitor { NSEvent.removeMonitor(monitor) }; monitor = nil }

    /// Explicit development flag only. Public session-stream injection is distinct from
    /// hardware validation. The user must still start a watchdog-supervised session.
    func checkSyntheticInput(model: SessionModel) {
        guard ProcessInfo.processInfo.arguments.contains("--synthetic-check"), model.screen == .active else { return }
        syntheticTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled, model.screen == .active, NSApp.isActive, let window = NSApp.keyWindow else { return }
            let keysBefore = keyboardEvents
            let pointerBefore = pointerEvents
            let filteredKeysBefore = model.filteredKeyboardEvents
            let filteredPointerBefore = model.filteredPointingEvents
            let source = CGEventSource(stateID: .privateState)
            var events: [CGEvent] = []
            // Ordinary, simultaneous and repeated down events, followed by their releases.
            for (code, down) in [(UInt16(0), true), (1, true), (0, true), (0, false), (1, false)] {
                if let event = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: down) { events.append(event) }
            }
            for (code, flags) in [(UInt16(56), UInt64(NX_DEVICELSHIFTKEYMASK)), (60, UInt64(NX_DEVICELSHIFTKEYMASK | NX_DEVICERSHIFTKEYMASK)), (56, UInt64(NX_DEVICERSHIFTKEYMASK)), (60, 0)] {
                if let event = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: false) {
                    event.type = .flagsChanged; event.flags = CGEventFlags(rawValue: flags); events.append(event)
                }
            }
            // Harmless area inside our own window; no external application's controls.
            guard let screen = NSScreen.screens.first else { return }
            let point = CGPoint(x: window.frame.midX, y: screen.frame.maxY - window.frame.midY)
            for type in [CGEventType.mouseMoved, .leftMouseDown, .leftMouseDragged, .leftMouseUp] {
                if let event = CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: point, mouseButton: .left) { events.append(event) }
            }
            if let event = CGEvent(scrollWheelEvent2Source: source, units: .pixel, wheelCount: 1, wheel1: 1, wheel2: 0, wheel3: 0) { events.append(event) }
            for event in events { event.post(tap: .cgSessionEventTap) }
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            let filteredKeys = model.filteredKeyboardEvents - filteredKeysBefore
            let filteredPointer = model.filteredPointingEvents - filteredPointerBefore
            let deliveredKeys = keyboardEvents - keysBefore
            let deliveredPointer = pointerEvents - pointerBefore
            DebugEvidence.record("synthetic-stream-check", details: [
                "filteredKeyboard": String(filteredKeys), "filteredPointing": String(filteredPointer),
                "deliveredKeyboard": String(deliveredKeys), "deliveredPointing": String(deliveredPointer),
                "passed": String(filteredKeys >= 9 && filteredPointer >= 5 && deliveredKeys == 0 && deliveredPointer == 0)
            ])
        }
    }
}

struct DebugInputCheck: View {
    var model: SessionModel
    @State private var receipt = DebugInputReceipt()
    var body: some View {
        VStack(spacing: 6) {
            Text("SUPERVISED TEST · 8 SECONDS").font(.system(size: 11, weight: .bold)).foregroundStyle(.orange)
            Text("Delivered to app — key: \(receipt.keyboardEvents) · pointer: \(receipt.pointerEvents)")
                .font(.system(size: 12, design: .monospaced)).accessibilityIdentifier("eventReceipt")
            Text("Filtered by tap — key: \(model.filteredKeyboardEvents) · pointer: \(model.filteredPointingEvents)")
                .font(.system(size: 12, design: .monospaced)).accessibilityIdentifier("tapReceipt")
            Text("Arm external termination before Start. Counts are transient.").font(.system(size: 10)).foregroundStyle(.secondary)
        }.frame(width: 440).padding(.vertical, 12)
            .onAppear { receipt.start() }.onDisappear { receipt.stop() }
            .onChange(of: model.screen) { _, _ in receipt.checkSyntheticInput(model: model) }
    }
}
#endif
