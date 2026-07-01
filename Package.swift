// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "zTerminal",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "zTerminal", targets: ["zTerminal"])
    ],
    dependencies: [
        // Pinned per design decision (SwiftTerm API drift risk).
        .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", .upToNextMajor(from: "1.13.0"))
    ],
    targets: [
        .executableTarget(
            name: "zTerminal",
            dependencies: [
                .product(name: "SwiftTerm", package: "SwiftTerm")
            ],
            path: "Sources/zTerminal"
        ),
        .testTarget(
            name: "zTerminalTests",
            dependencies: ["zTerminal"],
            path: "Tests/zTerminalTests"
        )
    ]
)
