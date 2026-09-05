import SwiftUI

struct AboutView: View {
    private var version: String {
        let info = Bundle.main.infoDictionary ?? [:]
        let version = info["CFBundleShortVersionString"] as? String ?? ""
        let build = info["CFBundleVersion"] as? String ?? ""
        return "Version \(version) (\(build))"
    }

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .frame(width: 80, height: 80)
                    .accessibilityHidden(true)

                VStack(spacing: 4) {
                    Text("Keydoze")
                        .font(.system(size: 24, weight: .semibold))
                        .accessibilityAddTraits(.isHeader)
                    Text(version)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(spacing: 8) {
                Text("A quiet moment for your Mac.")
                    .font(.body)
                Text("Works offline. No accounts or tracking.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 10) {
                HStack(spacing: 16) {
                    Link("Source Code", destination: URL(string: "https://github.com/dlev02/Keydoze")!)
                    Link("Apache 2.0 License", destination: URL(string: "https://github.com/dlev02/Keydoze/blob/main/LICENSE")!)
                }
                .font(.callout)

                Text("© 2026 Drew Levinson")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 28)
        .padding(.top, 36)
        .padding(.bottom, 28)
        .frame(width: 340)
    }
}
