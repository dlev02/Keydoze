import AppKit
import SwiftUI
@preconcurrency import Sparkle

/// Sparkle's standard updater and UI, kept out of the way of a cleaning session: while one runs,
/// no check starts, Sparkle's windows stay hidden, and a relaunch waits until input is back.
/// Quitting always ends a session first (`AppDelegate`), so an update can't leave input paused.
@MainActor @Observable
final class UpdateController: NSObject {
    private var updaterIsIdle = false
    private var sessionRunning = false
    var canCheck: Bool { updaterIsIdle && !sessionRunning }
    var checksAutomatically = false {
        didSet {
            guard let updater, updater.automaticallyChecksForUpdates != checksAutomatically else { return }
            updater.automaticallyChecksForUpdates = checksAutomatically
        }
    }
    @ObservationIgnored private var standard: SPUStandardUpdaterController?
    @ObservationIgnored private var canCheckObservation: NSKeyValueObservation?
    @ObservationIgnored private var hiddenWindows: [NSWindow] = []
    @ObservationIgnored private var hideTimer: Timer?
    @ObservationIgnored private var postponedRelaunch: (() -> Void)?

    private var updater: SPUUpdater? { standard?.updater }

    func start(session: SessionModel) {
        guard standard == nil else { return }
        session.onRunningChanged = { [weak self] running in self?.sessionChanged(running: running) }
        // A window Sparkle closes while it's hidden must not come back when the session ends.
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: nil, queue: .main) { [weak self] note in
            guard let window = note.object as? NSWindow else { return }
            MainActor.assumeIsolated { self?.hiddenWindows.removeAll { $0 === window } }
        }
        sessionChanged(running: session.running)
        #if DEBUG
        // Development copies stay off the real feed: see docs/DEVELOPMENT.md.
        guard Self.debugFeed != nil else { return }
        #endif
        let standard = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: self, userDriverDelegate: nil)
        self.standard = standard
        canCheckObservation = standard.updater.observe(\.canCheckForUpdates, options: [.initial, .new]) { [weak self] updater, _ in
            MainActor.assumeIsolated { self?.updaterIsIdle = updater.canCheckForUpdates }
        }
        standard.startUpdater()
        checksAutomatically = standard.updater.automaticallyChecksForUpdates
    }

    func checkForUpdates() {
        if canCheck { updater?.checkForUpdates() }
    }

    private func sessionChanged(running: Bool) {
        guard running != sessionRunning else { return }
        sessionRunning = running
        if running {
            hideUpdateWindows()
            let timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.hideUpdateWindows() }
            }
            RunLoop.main.add(timer, forMode: .common)
            hideTimer = timer
        } else {
            hideTimer?.invalidate()
            hideTimer = nil
            hiddenWindows.forEach { $0.makeKeyAndOrderFront(nil) }
            hiddenWindows = []
            let relaunch = postponedRelaunch
            postponedRelaunch = nil
            relaunch?()
        }
    }

    private func hideUpdateWindows() {
        // Sparkle's "up to date" and error alerts are its only modal windows, and they only inform.
        if NSApp.modalWindow != nil { NSApp.abortModal() }
        let sparkle = Bundle(for: SPUUpdater.self)
        for window in NSApp.windows where window.isVisible {
            guard let controller = window.windowController, Bundle(for: type(of: controller)) == sparkle else { continue }
            window.orderOut(nil)
            if !hiddenWindows.contains(window) { hiddenWindows.append(window) }
        }
    }

    #if DEBUG
    private static var debugFeed: String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "--update-feed"), arguments.count > index + 1 else { return nil }
        return arguments[index + 1]
    }
    #endif
}

extension UpdateController: SPUUpdaterDelegate {
    func updater(_ updater: SPUUpdater, mayPerform updateCheck: SPUUpdateCheck) throws {
        if sessionRunning {
            throw NSError(domain: "Keydoze.Updates", code: 1, userInfo: [NSLocalizedDescriptionKey: "A cleaning session is running."])
        }
    }

    func updater(_ updater: SPUUpdater, shouldPostponeRelaunchForUpdate item: SUAppcastItem, untilInvokingBlock installHandler: @escaping () -> Void) -> Bool {
        guard sessionRunning else { return false }
        postponedRelaunch = installHandler
        return true
    }

    #if DEBUG
    func feedURLString(for updater: SPUUpdater) -> String? { Self.debugFeed }
    #endif
}

struct SettingsView: View {
    @Bindable var updates: UpdateController

    var body: some View {
        Form {
            Toggle("Check for updates automatically", isOn: $updates.checksAutomatically)
            LabeledContent("Updates") {
                Button("Check Now") { updates.checkForUpdates() }
                    .disabled(!updates.canCheck)
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
        .frame(width: 400)
        .fixedSize(horizontal: false, vertical: true)
    }
}
