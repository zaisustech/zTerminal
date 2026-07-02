// swift-tools-version:5.9
import PackageDescription

// Vendored fork of SwiftTerm 1.13.0 (migueldeicaza/SwiftTerm @ 8e7a1e1).
//
// Trimmed to just the `SwiftTerm` library target — the upstream Fuzz / Termcast /
// Benchmarks targets (and their swift-argument-parser / package-benchmark /
// swift-docc-plugin dependencies) are omitted, so this fork pulls in nothing
// external. Local modifications live in the sources and are listed in
// `MODIFICATIONS.md`.
let package = Package(
    name: "SwiftTerm",
    platforms: [
        .iOS(.v14),
        .macOS(.v13),
        .tvOS(.v13),
        .visionOS(.v1)
    ],
    products: [
        .library(name: "SwiftTerm", targets: ["SwiftTerm"])
    ],
    targets: [
        .target(
            name: "SwiftTerm",
            path: "Sources/SwiftTerm",
            exclude: ["Mac/README.md"],
            resources: [
                .process("Apple/Metal/Shaders.metal")
            ]
        )
    ],
    swiftLanguageVersions: [.v5]
)
