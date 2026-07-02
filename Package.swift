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
        // Vendored fork of SwiftTerm 1.13.0 (path dependency) so our public-API
        // additions for terminal-search survive `swift package resolve`.
        // See ThirdParty/SwiftTerm/MODIFICATIONS.md.
        .package(path: "ThirdParty/SwiftTerm")
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
