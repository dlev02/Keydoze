import AppKit
@preconcurrency import ApplicationServices
import Observation
import KeydozeCore

@MainActor @Observable
final class SessionModel {
    enum Screen: Equatable { case ready, arming, active, releasing, finished(EndReason) }
    var screen: Screen = .ready
    var scope: InputScope {
        didSet { if !isSimulation { UserDefaults.standard.set(scope.rawValue, forKey: "inputScope") } }
    }
    var duration: Double {
        didSet { if !isSimulation { UserDefaults.standard.set(duration, forKey: "duration") } }
    }
    var permitted = false
    var permissionRequested = false
    var showPermission = false
    var showCoverage = false
    var settingsLinkFailed = false
    var remaining: Double = 60
    var totalDuration: Double = 60
    var recoveryProgress: Double = 0
    let isSimulation: Bool
    #if DEBUG
    var filteredKeyboardEvents = 0
    var filteredPointingEvents = 0
    #endif
    @ObservationIgnored private var engine: InputEngine?
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var observers: [(NotificationCenter, NSObjectProtocol)] = []
    @ObservationIgnored private var simulatedSession: Session?
    @ObservationIgnored private var simulatedNow: Double = 0
    @ObservationIgnored private var frozenSimulation = false
    #if DEBUG
    @ObservationIgnored private var lastArmingEvidence = -1
    #endif

    init() {
        #if DEBUG
        isSimulation = ProcessInfo.processInfo.arguments.contains("--simulate")
        #else
        isSimulation = false
        #endif
        scope = InputScope(rawValue: UserDefaults.standard.string(forKey: "inputScope") ?? "") ?? .both
        let stored = UserDefaults.standard.double(forKey: "duration")
        duration = [30.0, 60, 120].contains(stored) ? stored : 60
        if isSimulation { scope = .both; duration = 60 }
        permitted = isSimulation || AXIsProcessTrusted()
        #if DEBUG
        DebugEvidence.record("initialized", details: ["permitted": String(permitted), "simulation": String(isSimulation)])
        #endif
        observe(NotificationCenter.default, NSApplication.didBecomeActiveNotification) { model in model.refreshPermission() }
        observe(NotificationCenter.default, NSApplication.willTerminateNotification) { model in model.stopImmediately() }
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.screensDidSleepNotification,
                     NSWorkspace.sessionDidResignActiveNotification, NSWorkspace.didWakeNotification] {
            observe(NSWorkspace.shared.notificationCenter, name) { model in model.stopImmediately() }
        }
        #if DEBUG
        if let index = ProcessInfo.processInfo.arguments.firstIndex(of: "--state"),
           ProcessInfo.processInfo.arguments.count > index + 1, isSimulation {
            simulateState(ProcessInfo.processInfo.arguments[index + 1])
        }
        #endif
    }

    private func observe(_ center: NotificationCenter, _ name: Notification.Name,
                         action: @escaping @MainActor (SessionModel) -> Void) {
        let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { if let self { action(self) } }
        }
        observers.append((center, token))
    }

    private func startUITimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshSession() }
        }
        if let timer { RunLoop.main.add(timer, forMode: .common) }
    }

    private func stopUITimer() { timer?.invalidate(); timer = nil }

    var running: Bool { screen == .arming || screen == .active || screen == .releasing }
    var scopeDescription: String {
        switch scope {
        case .both: "Keyboard, trackpad & mouse"
        case .keyboard: "Keyboard"
        case .pointing: "Trackpad & mouse"
        }
    }
    var recoveryInstruction: String {
        scope == .pointing ? "Press Escape to finish early." : "Hold both Shift keys for 2 seconds to finish early."
    }
    var timeLabel: String {
        let seconds = Int(ceil(max(0, remaining)))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    func refreshPermission() {
        permitted = isSimulation ? permitted : AXIsProcessTrusted()
        #if DEBUG
        DebugEvidence.record("permission-refreshed", details: ["permitted": String(permitted)])
        #endif
        if permitted { showPermission = false }
        if !permitted && engine != nil { stopImmediately(.permissionDenied) }
    }

    func begin() {
        #if DEBUG
        DebugEvidence.record("start-requested")
        #endif
        guard !running else { return }
        if isSimulation {
            guard permitted else { showPermission = true; return }
            simulatedNow = 0
            frozenSimulation = false
            simulatedSession = Session(scope: scope, duration: duration, now: 0)
            screen = .arming; remaining = 3; recoveryProgress = 0
            startUITimer()
            return
        }
        refreshPermission()
        guard permitted else { showPermission = true; return }
        var sessionDuration = duration
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--live-check") { sessionDuration = 8 }
        #endif
        engine = InputEngine(scope: scope, duration: sessionDuration)
        screen = .arming; remaining = 3; recoveryProgress = 0
        startUITimer()
        announce("Preparing. Release all keys and lift your hands. Input is still available.")
    }

    func requestPermission() {
        guard !isSimulation else { permitted = true; showPermission = false; return }
        permissionRequested = true
        // The imported SDK global is an immutable CFString in practice; never write it.
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        refreshPermission()
    }

    func openPermissionSettings() {
        guard !isSimulation else { return }
        // The legacy Accessibility deep link is best-effort, including renamed macOS 27 panes.
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        settingsLinkFailed = !NSWorkspace.shared.open(url)
    }

    func revealApp() { NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL]) }

    func cancel() {
        if isSimulation {
            simulatedSession?.requestStop(now: simulatedNow)
            if frozenSimulation { reset() }
            return
        }
        engine?.requestStop()
        refreshSession()
    }

    func stopImmediately(_ reason: EndReason = .interrupted) {
        guard running || engine != nil else { return }
        engine?.interrupt(reason)
        stopUITimer()
        engine = nil
        simulatedSession = nil
        screen = .finished(reason)
        recoveryProgress = 0
    }

    func reset() {
        engine?.interrupt(.cancelled); engine = nil
        stopUITimer()
        simulatedSession = nil; frozenSimulation = false
        screen = .ready; recoveryProgress = 0
        refreshPermission()
    }

    private func refreshSession() {
        let session: Session
        let now: Double
        #if DEBUG
        var observedTapInstalled = false
        #endif
        if isSimulation {
            guard !frozenSimulation, simulatedSession != nil else { return }
            simulatedNow += 0.05
            simulatedSession?.tick(now: simulatedNow, physicalInputHeld: false)
            session = simulatedSession!
            now = simulatedNow
        } else {
            guard let engine else { return }
            engine.uiHeartbeat()
            let snapshot = engine.snapshot()
            #if DEBUG
            observedTapInstalled = snapshot.tapInstalled
            #endif
            session = snapshot.session
            now = SessionClock.now
            #if DEBUG
            filteredKeyboardEvents = snapshot.suppressedKeyboardEvents
            filteredPointingEvents = snapshot.suppressedPointingEvents
            if session.phase == .arming && Int(now) != lastArmingEvidence {
                lastArmingEvidence = Int(now)
                DebugEvidence.record("preparing", details: ["keysHeld": String(snapshot.keysHeld), "buttonsHeld": String(snapshot.buttonsHeld)])
            }
            #endif
        }
        let old = screen
        totalDuration = session.duration
        remaining = session.remaining(at: now)
        recoveryProgress = session.recoveryProgress(at: now)
        switch session.phase {
        case .arming: screen = .arming
        case .active: screen = .active
        case .releasing: screen = .releasing
        case let .finished(reason):
            screen = .finished(reason)
            stopUITimer()
            engine = nil; simulatedSession = nil
        }
        if old != screen {
            #if DEBUG
            DebugEvidence.record("state", details: ["screen": String(describing: screen), "tapInstalled": String(observedTapInstalled)])
            #endif
            switch screen {
            case .active: announce("Keydoze is on. \(scopeDescription) paused. \(Int(session.duration)) seconds. \(recoveryInstruction)")
            case .releasing: announce("Lift your hands. Release all keys and buttons to finish.")
            case .finished: announce("Keydoze ended. Input is available.")
            default: break
            }
            #if DEBUG
            if screen == .active && !isSimulation && ProcessInfo.processInfo.arguments.contains("--live-check") {
                if ProcessInfo.processInfo.arguments.contains("--fault-ui-stall") {
                    DebugEvidence.record("fault-injected", details: ["kind": "ui-stall"])
                    // Deliberately stall only this app's main thread. The independent
                    // filtering thread and watchdog must restore input without it.
                    Thread.sleep(forTimeInterval: 4)
                } else if ProcessInfo.processInfo.arguments.contains("--fault-tap-disabled") {
                    DebugEvidence.record("fault-injected", details: ["kind": "tap-disabled"])
                    engine?.debugDisableTap()
                }
            }
            #endif
        }
    }

    private func announce(_ text: String) {
        guard let window = NSApp.mainWindow else { return }
        NSAccessibility.post(element: window, notification: .announcementRequested,
                             userInfo: [.announcement: text, .priority: NSAccessibilityPriorityLevel.high.rawValue])
    }

    #if DEBUG
    func simulateState(_ name: String) {
        guard isSimulation else { return }
        reset(); frozenSimulation = true; permitted = true
        switch name {
        case "permission": permitted = false; showPermission = true
        case "arming": screen = .arming; remaining = 3
        case "active": screen = .active; remaining = 48
        case "recovery": screen = .active; remaining = 34; recoveryProgress = 0.65
        case "releasing": screen = .releasing; remaining = 0
        case "done": screen = .finished(.timedOut)
        case "error": screen = .finished(.tapDisabled)
        default: screen = .ready
        }
    }
    #endif
}
