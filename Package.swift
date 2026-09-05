// swift-tools-version: 6.2
import PackageDescription
let package = Package(
    name: "Keydoze",
    platforms: [.macOS("26.0")],
    products: [.executable(name: "Keydoze", targets: ["Keydoze"])],
    targets: [
        .target(name: "KeydozeCore"),
        .executableTarget(name: "Keydoze", dependencies: ["KeydozeCore"]),
        .testTarget(name: "KeydozeCoreTests", dependencies: ["KeydozeCore"]),
        .testTarget(name: "KeydozeAdapterTests", dependencies: ["Keydoze", "KeydozeCore"])
    ]
)
