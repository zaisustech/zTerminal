import XCTest
@testable import zTerminal

final class EnvVarTests: XCTestCase {

    // MARK: - Key validation

    func testValidKeys() {
        for k in ["NODE_ENV", "A", "_x", "PATH", "AWS_PROFILE", "X1", "_", "a_b_2"] {
            XCTAssertTrue(EnvVar.isValidKey(k), "\(k) should be valid")
        }
    }

    func testInvalidKeys() {
        // No leading digit, no spaces, no hyphens/dots/slashes (unlike shortcut names).
        for k in ["", "   ", "2FOO", "9", "a b", "MY-VAR", "a.b", "foo bar", "-x", "a/b", "FOO!"] {
            XCTAssertFalse(EnvVar.isValidKey(k), "\(k) should be invalid")
        }
    }

    func testKeysAreTrimmed() {
        XCTAssertTrue(EnvVar.isValidKey("  NODE_ENV  "))
    }

    func testDuplicateKeys() {
        let list = [
            EnvVar(key: "FOO", value: "1"),
            EnvVar(key: "FOO", value: "2"),
            EnvVar(key: "BAR", value: "3"),
            EnvVar(key: " ", value: "4"),
        ]
        XCTAssertEqual(EnvVar.duplicateKeys(in: list), ["FOO"])
    }

    // MARK: - Shadowing detection

    func testShadowsInheritedEnv() {
        let env = ["PATH": "/usr/bin", "HOME": "/Users/x"]
        XCTAssertTrue(EnvVar.shadowsInheritedEnv("PATH", environment: env))
        XCTAssertTrue(EnvVar.shadowsInheritedEnv("  HOME  ", environment: env))
        XCTAssertFalse(EnvVar.shadowsInheritedEnv("NODE_ENV", environment: env))
        XCTAssertFalse(EnvVar.shadowsInheritedEnv("", environment: env))
    }

    // MARK: - Export line (injection safety)

    func testExportLinePlain() {
        XCTAssertEqual(EnvVar(key: "NODE_ENV", value: "development").exportLine(),
                       "export NODE_ENV='development'")
    }

    func testExportLineEmptyValueAllowed() {
        XCTAssertEqual(EnvVar(key: "EMPTY", value: "").exportLine(), "export EMPTY=''")
    }

    func testExportLineQuotesSpecialCharsVerbatim() {
        // $, backticks, and command substitution are literal inside single quotes.
        let v = EnvVar(key: "X", value: "a'b\"c $(whoami) `date`")
        XCTAssertEqual(v.exportLine(), "export X='a'\\''b\"c $(whoami) `date`'")
    }

    func testExportLineNilForInvalidKey() {
        XCTAssertNil(EnvVar(key: "2bad", value: "x").exportLine())
        XCTAssertNil(EnvVar(key: "", value: "x").exportLine())
    }

    func testExportLineNilWhenDisabled() {
        XCTAssertNil(EnvVar(key: "OK", value: "x", enabled: false).exportLine())
    }

    // MARK: - Shell block (skip bad/disabled entries, dedupe)

    func testShellBlockSkipsInvalidDisabledAndDedupes() {
        let list = [
            EnvVar(key: "NODE_ENV", value: "development"),
            EnvVar(key: "2bad", value: "nope"),                 // invalid key → skipped
            EnvVar(key: "OFF", value: "x", enabled: false),      // disabled → skipped
            EnvVar(key: "NODE_ENV", value: "production"),        // duplicate → first wins
            EnvVar(key: "EDITOR", value: "nvim"),
        ]
        let block = EnvVar.shellBlock(for: list)
        XCTAssertTrue(block.contains("export NODE_ENV='development'"))
        XCTAssertTrue(block.contains("export EDITOR='nvim'"))
        XCTAssertFalse(block.contains("2bad"))
        XCTAssertFalse(block.contains("OFF"))
        XCTAssertFalse(block.contains("'production'"), "first duplicate should win")
    }

    func testShellBlockEmptyForNoValidVars() {
        XCTAssertEqual(EnvVar.shellBlock(for: []), "")
        XCTAssertEqual(EnvVar.shellBlock(for: [EnvVar(key: "2x", value: "y")]), "")
        XCTAssertEqual(EnvVar.shellBlock(for: [EnvVar(key: "X", value: "y", enabled: false)]), "")
    }

    // MARK: - Export dictionary (pre-spawn env seed)

    func testExportDictionarySkipsAndDedupes() {
        let list = [
            EnvVar(key: "NODE_ENV", value: "development"),
            EnvVar(key: "2bad", value: "nope"),
            EnvVar(key: "OFF", value: "x", enabled: false),
            EnvVar(key: "NODE_ENV", value: "production"),   // first wins
        ]
        let dict = EnvVar.exportDictionary(for: list)
        XCTAssertEqual(dict, ["NODE_ENV": "development"])
    }

    // MARK: - Persistence tolerance

    func testDecodeTolerantOfMissingEnvVars() throws {
        // Older settings blobs have no envVars key → decode to [].
        let json = ##"{"accentHex":"#123456"}"##.data(using: .utf8)!
        let tokens = try JSONDecoder().decode(DesignTokens.self, from: json)
        XCTAssertEqual(tokens.envVars, [])
    }

    func testDecodeTolerantOfMissingEnabledDefaultsTrue() throws {
        // An EnvVar written before `enabled` existed decodes as enabled.
        let json = ##"{"id":"1B4E28BA-2FA1-11D2-883F-0016D3CCA427","key":"FOO","value":"bar"}"##.data(using: .utf8)!
        let v = try JSONDecoder().decode(EnvVar.self, from: json)
        XCTAssertTrue(v.enabled)
        XCTAssertEqual(v.key, "FOO")
    }

    func testEnvVarRoundTrips() throws {
        let original = DesignTokens(envVars: [EnvVar(key: "NODE_ENV", value: "development", enabled: false)])
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(DesignTokens.self, from: data)
        XCTAssertEqual(decoded.envVars.map(\.key), ["NODE_ENV"])
        XCTAssertEqual(decoded.envVars.map(\.value), ["development"])
        XCTAssertEqual(decoded.envVars.map(\.enabled), [false])
    }
}
