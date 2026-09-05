import SwiftUI
import ApplicationServices

@main
struct KeydozeApp: App {
    @Environment(\.openWindow) private var openWindow
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var model = SessionModel()
    init() {
        #if DEBUG
        PermissionProbe.runIfRequested()
        #endif
    }
    var body: some Scene {
        Window("Keydoze", id: "main") {
            VStack(spacing: 0) {
                MainView(model: model)
                #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("--live-check") { DebugInputCheck(model: model) }
                #endif
            }.onAppear {
                delegate.model = model
                model.refreshPermission()
                #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("--request-permission") {
                    model.showPermission = true
                    model.requestPermission()
                }
                #endif
            }
        }
        .defaultPosition(.center)
        .windowResizability(.contentSize)
        // MainView hides the visible title/background, while the logical title and
        // native close/minimize controls remain available to macOS and Accessibility.
        .windowToolbarStyle(.unifiedCompact)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Keydoze") { openWindow(id: "about") }
            }
            CommandGroup(replacing: .newItem) { }
            CommandGroup(replacing: .help) {
                Button("How Keydoze Works") { model.showCoverage = true }.disabled(model.running)
            }
            #if DEBUG
            CommandMenu("Preview") {
                if model.isSimulation {
                    ForEach(["ready", "permission", "arming", "active", "recovery", "releasing", "done", "error"], id: \.self) { state in
                        Button(state.capitalized) { model.simulateState(state) }
                    }
                } else {
                    Text("Launch with --simulate for safe previews")
                }
            }
            #endif
        }

        Window("About Keydoze", id: "about") {
            AboutView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }
}

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var model: SessionModel?
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        #if DEBUG
        if let index = ProcessInfo.processInfo.arguments.firstIndex(of: "--appearance"),
           ProcessInfo.processInfo.arguments.count > index + 1 {
            let choice = ProcessInfo.processInfo.arguments[index + 1]
            let name: NSAppearance.Name = choice == "light" ? .aqua : choice == "contrast-light" ? .accessibilityHighContrastAqua : choice == "contrast-dark" ? .accessibilityHighContrastDarkAqua : .darkAqua
            NSApp.appearance = NSAppearance(named: name)
        }
        #endif
        NSApp.activate()
        NSWindow.allowsAutomaticWindowTabbing = false
    }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        model?.stopImmediately(.cancelled)
        return .terminateNow
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

#if DEBUG
enum PermissionProbe {
    static func runIfRequested() {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "--probe-permission"), args.count > index + 1 else { return }
        let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
            options: .defaultTap, eventsOfInterest: .max,
            callback: { _, _, event, _ in Unmanaged.passUnretained(event) }, userInfo: nil)
        let report: [String: Any] = ["accessibility": AXIsProcessTrusted(),
            "listenPreflight": CGPreflightListenEventAccess(), "activeTapCreated": tap != nil,
            "bundleID": Bundle.main.bundleIdentifier ?? "missing", "bundlePath": Bundle.main.bundlePath]
        if let tap { CFMachPortInvalidate(tap) }
        if let data = try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]) {
            let output = URL(fileURLWithPath: args[index + 1])
            try? FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? data.write(to: output)
        }
    }
}
#endif
