// swift-tools-version: 6.2
import PackageDescription
let package = Package(
    name: "Keydoze",
    platforms: [.macOS("26.0")],
    products: [.executable(name: "Keydoze", targets: ["Keydoze"])],
    dependencies: [.package(url: "https://github.com/sparkle-project/Sparkle", from: "2.0.0")],
    targets: [
        .target(name: "KeydozeCore"),
        .executableTarget(name: "Keydoze", dependencies: ["KeydozeCore", .product(name: "Sparkle", package: "Sparkle")]),
        .testTarget(name: "KeydozeCoreTests", dependencies: ["KeydozeCore"]),
        .testTarget(name: "KeydozeAdapterTests", dependencies: ["Keydoze", "KeydozeCore"])
    ]
)
