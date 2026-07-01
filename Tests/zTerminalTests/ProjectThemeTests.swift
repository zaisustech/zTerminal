import XCTest
@testable import zTerminal

final class ProjectThemeTests: XCTestCase {
    private var dir: String!
    override func setUpWithError() throws {
        dir = NSTemporaryDirectory() + "zt-theme-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(atPath: dir) }
    private func writeConfig(_ contents: String) {
        try? contents.write(toFile: ZTerminalConfig.path(in: dir), atomically: true, encoding: .utf8)
    }

    /// Establish the ambient theme for a directory with no project config (which is
    /// the global `~/.zTerminal.json` if the developer has one, else user Settings),
    /// so assertions stay stable regardless of the machine's home config.
    @MainActor private func ambientBaseline(_ theme: ThemeManager) -> (accent: String, mode: AppearanceMode) {
        let amb = NSTemporaryDirectory() + "zt-amb-\(UUID().uuidString)"
        try? FileManager.default.createDirectory(atPath: amb, withIntermediateDirectories: true)
        theme.applyProjectTheme(from: amb)
        return (theme.effectiveTokens.accentHex, theme.effectiveMode)
    }

    @MainActor
    func testOverrideAppliesThenReverts() {
        let theme = ThemeManager()
        let baseAccent = theme.tokens.accentHex
        let baseMode = theme.mode
        let ambient = ambientBaseline(theme)

        writeConfig(##"{ "theme": { "mode": "glass", "accentHex": "#EC4899", "cornerRadius": 24 } }"##)
        theme.applyProjectTheme(from: dir)

        // Effective values reflect the project override...
        XCTAssertEqual(theme.effectiveTokens.accentHex, "#EC4899")
        XCTAssertEqual(theme.effectiveTokens.cornerRadius, 24)
        XCTAssertEqual(theme.effectiveMode, .glass)
        // ...but the user's base/persisted Settings are untouched.
        XCTAssertEqual(theme.tokens.accentHex, baseAccent)
        XCTAssertEqual(theme.mode, baseMode)

        // Leaving the project reverts to the ambient (global-or-Settings) theme.
        let empty = NSTemporaryDirectory() + "zt-empty-\(UUID().uuidString)"
        try? FileManager.default.createDirectory(atPath: empty, withIntermediateDirectories: true)
        theme.applyProjectTheme(from: empty)
        XCTAssertEqual(theme.effectiveTokens.accentHex, ambient.accent)
        XCTAssertEqual(theme.effectiveMode, ambient.mode)
    }

    func testCombineLayersProjectOverGlobal() {
        let global = ProjectTheme(mode: "dark", accentHex: "#111111", cornerRadius: 10)
        let project = ProjectTheme(accentHex: "#EC4899")   // only overrides accent
        let r = ProjectTheme.combine(project, over: global)
        XCTAssertEqual(r?.accentHex, "#EC4899")   // project wins
        XCTAssertEqual(r?.mode, "dark")           // global shows through
        XCTAssertEqual(r?.cornerRadius, 10)       // global shows through
    }

    func testCombineBothNilIsNil() {
        XCTAssertNil(ProjectTheme.combine(nil, over: nil))
    }

    @MainActor
    func testPartialOverrideKeepsAmbientFields() {
        let theme = ThemeManager()
        // Blur is specified by neither the project nor (assumed) the global config,
        // so it should equal the ambient value for a no-config directory.
        let amb = NSTemporaryDirectory() + "zt-amb-\(UUID().uuidString)"
        try? FileManager.default.createDirectory(atPath: amb, withIntermediateDirectories: true)
        theme.applyProjectTheme(from: amb)
        let ambientBlur = theme.effectiveTokens.blur
        let ambientMode = theme.effectiveMode

        writeConfig(##"{ "theme": { "accentHex": "#10B981" } }"##)
        theme.applyProjectTheme(from: dir)
        XCTAssertEqual(theme.effectiveTokens.accentHex, "#10B981")
        // Unspecified fields fall through to the ambient (global-or-Settings) theme.
        XCTAssertEqual(theme.effectiveTokens.blur, ambientBlur)
        XCTAssertEqual(theme.effectiveMode, ambientMode)
    }
}
