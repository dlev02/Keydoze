import SwiftUI
import KeydozeCore

struct MainView: View {
    @Bindable var model: SessionModel
    @State private var showPermissionHelp = false
    @Namespace private var selectionMotion
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.accessibilityReduceTransparency) private var systemReduceTransparency
    @Environment(\.colorSchemeContrast) private var systemContrast
    @Environment(\.colorScheme) private var colorScheme
    private var palette: KeydozePalette { KeydozePalette(dark: colorScheme == .dark) }
    private var accent: Color { palette.accent }
    private var contrast: ColorSchemeContrast {
        #if DEBUG
        if model.isSimulation && ProcessInfo.processInfo.arguments.contains(where: { $0 == "contrast-light" || $0 == "contrast-dark" }) { return .increased }
        #endif
        return systemContrast
    }
    private var reduceMotion: Bool {
        #if DEBUG
        systemReduceMotion || (model.isSimulation && ProcessInfo.processInfo.arguments.contains("--reduce-motion"))
        #else
        systemReduceMotion
        #endif
    }
    private var reduceTransparency: Bool {
        #if DEBUG
        systemReduceTransparency || (model.isSimulation && ProcessInfo.processInfo.arguments.contains("--reduce-transparency"))
        #else
        systemReduceTransparency
        #endif
    }

    var body: some View {
        VStack(spacing: 0) {
            // Transitions affect presentation only. The engine has already changed state;
            // no completion handler, delay, or animation controls input availability.
            ZStack {
                switch model.screen {
                case .ready: ready.transition(screenTransition)
                case .arming, .active, .releasing: session.transition(screenTransition)
                case let .finished(reason): finished(reason).transition(screenTransition)
                }
            }
            .padding(.horizontal, KeydozeLayout.inset)
            .padding(.top, 24)
            .padding(.bottom, 28)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            if model.isSimulation {
                Text("Preview · Input stays available")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
                    .padding(.bottom, 12)
                    .accessibilityIdentifier("simulationBanner")
            }
        }
        .frame(width: KeydozeLayout.width, height: KeydozeLayout.height)
        .background(palette.canvas)
        .containerBackground(palette.canvas, for: .window)
        .toolbar(removing: .title)
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        .tint(accent)
        .animation(reduceMotion ? nil : KeydozeMotion.screen, value: model.screen)
        // Also suppress inherited/native child animations in the reduced-motion path.
        .transaction { if reduceMotion { $0.disablesAnimations = true } }
        .sheet(isPresented: $model.showPermission) { permissionSheet }
        .sheet(isPresented: $model.showCoverage) { coverageSheet }
    }

    private var screenTransition: AnyTransition {
        reduceMotion ? .identity : .asymmetric(
            insertion: .opacity.combined(with: .offset(y: 6)),
            removal: .opacity)
    }

    private var ready: some View {
        VStack(spacing: 0) {
            DeviceArtwork(scope: model.scope, palette: palette, highContrast: contrast == .increased, reduceMotion: reduceMotion)
                .frame(height: 116)
                .offset(x: -8)
                .contentShape(Rectangle()).gesture(WindowDragGesture())
                .allowsWindowActivationEvents(true)
            Text("Clean your Mac.")
                .font(.system(size: 29, weight: .semibold, design: .rounded)).tracking(-0.7)
                .accessibilityAddTraits(.isHeader).padding(.top, 12)
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    scopeChoice(.both, title: "Both", symbol: "keyboard")
                    scopeChoice(.keyboard, title: "Keyboard", symbol: "keyboard")
                    scopeChoice(.pointing, title: "Trackpad & mouse", symbol: "computermouse")
                }.accessibilityElement(children: .contain).accessibilityLabel("Input to pause")
                    .accessibilityIdentifier("inputScope")
                VStack(alignment: .leading, spacing: 8) {
                    Text("Duration").font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary).padding(.leading, 4)
                    HStack(spacing: 4) {
                        durationChoice(30, title: "30 sec")
                        durationChoice(60, title: "1 min")
                        durationChoice(120, title: "2 min")
                    }
                    .padding(4)
                    .background(Color.primary.opacity(0.035), in: Capsule())
                    .accessibilityElement(children: .contain).accessibilityLabel("Duration")
                    .accessibilityIdentifier("durationPicker")
                }.padding(.top, 8)
            }.padding(.top, 22)
            Spacer(minLength: 28)
            primaryButton(model.permitted ? "Start cleaning" : "Set up Keydoze", symbol: model.permitted ? "play.fill" : "lock.open") { model.begin() }
                .accessibilityIdentifier("startButton")
            Text("Some system controls may still respond.")
                .font(.system(size: 11)).foregroundStyle(.secondary).padding(.top, 12)
            Button { model.showCoverage = true } label: {
                Label("What Keydoze does", systemImage: "info.circle")
                    .font(.system(size: 11))
                    .frame(minHeight: 24)
            }
            .buttonStyle(.plain).foregroundStyle(.secondary).padding(.top, 2)
            .help("Learn which input Keydoze can pause")
            .accessibilityIdentifier("coverageButton")
        }
        .animation(reduceMotion ? nil : KeydozeMotion.selection, value: model.scope)
        .animation(reduceMotion ? nil : KeydozeMotion.selection, value: model.duration)
    }

    private func scopeChoice(_ scope: InputScope, title: String, symbol: String) -> some View {
        let selected = model.scope == scope
        return Button { model.scope = scope } label: {
            VStack(spacing: 8) {
                HStack(spacing: 3) {
                    Image(systemName: symbol)
                    if scope == .both { Image(systemName: "computermouse").font(.system(size: 16)) }
                }
                .font(.system(size: 19, weight: .regular))
                .symbolRenderingMode(.hierarchical)
                .frame(height: 23)
                .accessibilityHidden(true)
                Text(title).font(.system(size: 11, weight: selected ? .semibold : .medium))
                    .lineLimit(1).minimumScaleFactor(0.9)
            }
            .foregroundStyle(selected ? accent : Color.primary.opacity(0.72))
            .frame(maxWidth: .infinity).frame(height: 65)
            .background(selected ? palette.surface : Color.primary.opacity(colorScheme == .dark ? 0.035 : 0.025), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(selected ? accent.opacity(contrast == .increased ? 0.9 : 0.5) : palette.edge.opacity(0.55), lineWidth: selected ? 1.2 : 0.5))
            .shadow(color: .black.opacity(selected && contrast != .increased ? 0.045 : 0), radius: 4, y: 2)
        }.buttonStyle(.plain)
            .accessibilityLabel(title).accessibilityAddTraits(selected ? .isSelected : [])
            .accessibilityIdentifier("scope-\(scope.rawValue)")
    }

    private func durationChoice(_ seconds: Double, title: String) -> some View {
        Button { model.duration = seconds } label: {
            Text(title).font(.system(size: 12, weight: model.duration == seconds ? .semibold : .medium))
                .frame(maxWidth: .infinity).frame(height: 32)
                .background {
                    if model.duration == seconds {
                        Capsule().fill(palette.surface)
                            .overlay(Capsule().strokeBorder(accent.opacity(contrast == .increased ? 0.9 : 0.3), lineWidth: 1))
                            .matchedGeometryEffect(id: "durationSelection", in: selectionMotion)
                    }
                }
        }
        .buttonStyle(DurationChoiceStyle(selected: model.duration == seconds, palette: palette))
        .accessibilityLabel(title).accessibilityAddTraits(model.duration == seconds ? .isSelected : [])
        .accessibilityIdentifier("duration-\(Int(seconds))")
    }

    private var session: some View {
        VStack(spacing: 0) {
            Label(statusTitle, systemImage: model.screen == .active ? "pause.circle.fill" : "hand.raised")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(model.screen == .active ? accent : .secondary)
                .accessibilityAddTraits(.isHeader).accessibilityIdentifier("sessionStatus")
                .padding(.top, 12)
                .frame(maxWidth: .infinity).contentShape(Rectangle())
                .gesture(WindowDragGesture()).allowsWindowActivationEvents(true)
            ZStack {
                Circle().stroke(Color.primary.opacity(0.055), lineWidth: 5)
                Circle().trim(from: 0, to: ringProgress)
                    .stroke(accent.opacity(model.screen == .active ? 0.8 : 0.3), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 4) {
                    Text(model.screen == .releasing ? "0:00" : model.timeLabel)
                        .font(.system(size: 65, weight: .medium, design: .rounded)).monospacedDigit().tracking(-2)
                        .contentTransition(reduceMotion ? .identity : .numericText(countsDown: true))
                        .animation(reduceMotion ? nil : KeydozeMotion.digits, value: model.timeLabel)
                        .accessibilityLabel(model.screen == .arming ? "Preparing" : "Time remaining")
                        .accessibilityValue("\(Int(ceil(model.remaining))) seconds")
                        .accessibilityIdentifier("countdown")
                    Text(model.screen == .arming ? "until input pauses" : model.screen == .releasing ? "finishing" : "until input returns")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
            }.frame(width: 202, height: 202).padding(.top, 24)
            if model.screen != .active {
                Text(model.screen == .arming ? "Release your keys and lift your hands." : "Release all keys and buttons.")
                    .font(.system(size: 13)).foregroundStyle(.secondary).padding(.top, 24)
                if model.screen == .releasing {
                    Text("Input returns within 2 seconds.")
                        .font(.system(size: 12)).foregroundStyle(.secondary).padding(.top, 8)
                }
            }
            Spacer(minLength: 22)
            if model.screen == .active {
                HStack(spacing: 14) {
                    if model.scope != .pointing {
                        HStack(spacing: 5) { shiftKey("left"); shiftKey("right") }.accessibilityHidden(true)
                    } else {
                        Image(systemName: "escape").font(.system(size: 25, weight: .regular))
                            .foregroundStyle(accent).frame(width: 48, height: 48).accessibilityHidden(true)
                    }
                    VStack(alignment: .leading, spacing: 5) {
                        Text(model.scope == .pointing ? "Press Escape" : model.recoveryProgress > 0 ? "Keep holding…" : "Hold both Shift keys")
                            .font(.system(size: 12, weight: .semibold))
                        Text(model.scope == .pointing ? "to finish early" : "for 2 seconds to finish early")
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                        if model.recoveryProgress > 0 {
                            ProgressView(value: model.recoveryProgress).progressViewStyle(.linear)
                                .accessibilityLabel("Early finish hold")
                                .transition(.opacity)
                        }
                    }
                    // Keep key symbols stationary when the hold-progress bar appears.
                    .frame(width: 200, alignment: .leading)
                }.frame(maxWidth: .infinity).frame(height: 78)
                if model.scope == .keyboard {
                    Button("Finish now") { model.cancel() }.controlSize(.large).padding(.top, 10)
                }
            } else if model.screen == .arming {
                Button("Cancel") { model.cancel() }.controlSize(.large).keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("cancelButton").frame(height: 91)
            } else {
                Image(systemName: "hand.raised.fingers.spread")
                    .font(.system(size: 30, weight: .regular)).foregroundStyle(.secondary).frame(height: 91)
                    .accessibilityHidden(true)
            }
            Spacer(minLength: 6)
        }
    }

    private var ringProgress: CGFloat {
        if model.screen == .releasing { return 0 }
        if model.screen == .arming { return CGFloat(max(0, min(1, model.remaining / 3))) }
        return CGFloat(max(0, min(1, model.remaining / max(1, model.totalDuration))))
    }

    private var statusTitle: String {
        switch model.screen {
        case .arming: "Getting ready"
        case .releasing: "Lift your hands"
        default: model.scope == .both ? "Input paused" : model.scope == .keyboard ? "Keyboard paused" : "Trackpad & mouse paused"
        }
    }

    private func finished(_ reason: EndReason) -> some View {
        let success = reason == .timedOut || reason == .recovered || reason == .cancelled
        return VStack(spacing: 0) {
            Spacer()
            Image(systemName: success ? "checkmark.circle" : "exclamationmark.circle")
                .font(.system(size: 48, weight: .regular)).foregroundStyle(success ? accent : .orange)
                .accessibilityHidden(true)
            Text(success ? "Back to you." : "Keydoze stopped.")
                .font(.system(size: 26, weight: .semibold, design: .rounded)).tracking(-0.5)
                .padding(.top, 25).accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("completionTitle")
            Text(success ? "Your input is available." : explanation(reason))
                .font(.system(size: 13)).foregroundStyle(.secondary).multilineTextAlignment(.center)
                .lineSpacing(4).padding(.top, 12).fixedSize(horizontal: false, vertical: true)
            Spacer()
            primaryButton(success ? "Clean again" : "Back to setup", symbol: success ? "arrow.counterclockwise" : "arrow.left") { model.reset() }
                .accessibilityIdentifier("resetButton")
        }
    }

    private func explanation(_ reason: EndReason) -> String {
        switch reason {
        case .permissionDenied: "Access changed or macOS is protecting secure input. Input is available. Check permission before trying again."
        case .tapFailed: "macOS couldn’t start input protection. Nothing was blocked. Check permission, then try again."
        case .heldInput: "Input is available. Release all keys and buttons before continuing; a held control can still respond."
        case .uiUnresponsive: "The window stopped responding, so input protection ended automatically."
        case .tapDisabled: "macOS interrupted input protection. Input is available; the session won’t restart on its own."
        default: "A system transition ended the session. Input is available; start again when you’re ready."
        }
    }

    private func shiftKey(_ side: String) -> some View {
        VStack(spacing: 3) {
            Image(systemName: "shift").font(.system(size: 18, weight: .medium))
            Text(side).font(.system(size: 9))
        }.frame(width: 43, height: 47)
            .background(palette.keyTop, in: RoundedRectangle(cornerRadius: 8))
            .shadow(color: .black.opacity(0.10), radius: 0, y: 2)
            .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(model.recoveryProgress > 0 ? accent : Color.primary.opacity(contrast == .increased ? 0.5 : 0.12)))
            .foregroundStyle(model.recoveryProgress > 0 ? accent : .primary)
    }

    @ViewBuilder private func primaryButton(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        if reduceTransparency || contrast == .increased {
            Button(action: action) { Label(title, systemImage: symbol).font(.system(size: 14, weight: .semibold)).frame(maxWidth: .infinity).frame(height: 29) }
                .buttonStyle(.borderedProminent).controlSize(.large)
        } else {
            Button(action: action) { Label(title, systemImage: symbol).font(.system(size: 14, weight: .semibold)).frame(maxWidth: .infinity).frame(height: 29) }
                .buttonStyle(.glassProminent).controlSize(.large)
        }
    }

    private var permissionSheet: some View {
        VStack(alignment: .leading, spacing: 0) {
            Image(systemName: "hand.raised")
                .font(.system(size: 34, weight: .regular)).foregroundStyle(accent)
                .accessibilityHidden(true)
            Text("Allow input access")
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .tracking(-0.5).accessibilityAddTraits(.isHeader).padding(.top, 20)
            Text("Keydoze needs Accessibility access to pause your keyboard and pointer. Nothing you type is saved.")
                .font(.system(size: 13)).foregroundStyle(.secondary).lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true).padding(.top, 12)

            if model.permissionRequested {
                Label("Enable Keydoze, then return here.", systemImage: "switch.2")
                    .font(.system(size: 13, weight: .medium)).padding(.top, 24)
            }

            primaryButton(model.permissionRequested ? "Open System Settings" : "Allow Access…", symbol: "lock.open") {
                if model.permissionRequested { model.openPermissionSettings() }
                else { model.requestPermission() }
            }.padding(.top, 28)
            Button("Not now") { model.showPermission = false }
                .buttonStyle(.plain).font(.system(size: 12)).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 28).padding(.top, 8)
                .keyboardShortcut(.cancelAction)

            // Keep recovery instructions available without front-loading setup details.
            DisclosureGroup("Having trouble?", isExpanded: $showPermissionHelp) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("In System Settings, open Privacy & Security → Accessibility and enable Keydoze. On macOS 27, look for Device Control and Data Access.")
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Access is checked automatically when you return.")
                    HStack {
                        Button("Show app in Finder") { model.revealApp() }
                        Spacer()
                        Button("Check again") { model.refreshPermission() }
                    }.buttonStyle(.borderless).tint(accent)
                }.font(.system(size: 12)).foregroundStyle(.secondary).lineSpacing(3).padding(.top, 10)
            }
            .font(.system(size: 12)).foregroundStyle(.secondary).padding(.top, 20)
            if model.settingsLinkFailed {
                Text("The shortcut couldn’t open. Use System Settings → Privacy & Security to enable Keydoze.")
                    .font(.system(size: 12)).foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true).padding(.top, 12)
            }
        }
        .padding(32).frame(width: 420)
        .background(palette.canvas).tint(accent)
    }

    private var coverageSheet: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("What Keydoze does")
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .tracking(-0.5).accessibilityAddTraits(.isHeader)
            Text("Made for a small, familiar annoyance: wiping your MacBook’s keyboard and trackpad without accidental typing or clicks. Choose what to pause, set a timer, and give your Mac a clean.")
            Text("Keydoze pauses everyday keys, clicks, movement, and scrolling—including external keyboards and mice.")
            Text("Some system gestures, Fn/Globe, and media keys may still respond. Touch ID, power, and security controls stay outside Keydoze’s coverage.")
            Text("Input returns automatically. Hold both Shift keys for 2 seconds to finish early, or press Escape in trackpad-and-mouse mode. Release held keys and buttons when prompted; this takes at most 2 extra seconds.")
            Text("Keydoze is a cleaning aid, not a security lock. Interrupted sessions never restart automatically.")
                .foregroundStyle(.secondary)
            primaryButton("Got it", symbol: "checkmark") { model.showCoverage = false }
                .keyboardShortcut(.defaultAction)
        }
        .font(.system(size: 13)).lineSpacing(3).padding(32).frame(width: 420)
        .fixedSize(horizontal: false, vertical: true)
        .background(palette.canvas).tint(accent)
    }
}
