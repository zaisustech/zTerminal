import XCTest
@testable import zTerminal

final class CommandMarkerTests: XCTestCase {

    func testParseStart() {
        XCTAssertEqual(CommandMarker.parse(osc133: "C"), .start(command: nil))
    }

    func testParseStartWithCommandPayload() {
        // "git status" base64-encoded rides the C marker.
        let b64 = Data("git status".utf8).base64EncodedString()
        XCTAssertEqual(CommandMarker.parse(osc133: "C;\(b64)"), .start(command: "git status"))
    }

    func testParseStartPreservesQuotesAndNewlines() {
        let cmd = "echo \"a b\" '$HOME'\nls -la"
        let b64 = Data(cmd.utf8).base64EncodedString()
        XCTAssertEqual(CommandMarker.parse(osc133: "C;\(b64)"), .start(command: cmd))
    }

    func testParseStartMalformedPayloadDegradesToNil() {
        // Invalid base64 → the lifecycle marker still parses, capture is dropped.
        XCTAssertEqual(CommandMarker.parse(osc133: "C;!!!not-base64!!!"), .start(command: nil))
        // Oversized payload is ignored, not decoded.
        let huge = String(repeating: "A", count: 70_000)
        XCTAssertEqual(CommandMarker.parse(osc133: "C;\(huge)"), .start(command: nil))
    }

    func testParseEndWithExitCode() {
        XCTAssertEqual(CommandMarker.parse(osc133: "D;0"), .end(exitCode: 0))
        XCTAssertEqual(CommandMarker.parse(osc133: "D;1"), .end(exitCode: 1))
        XCTAssertEqual(CommandMarker.parse(osc133: "D;130"), .end(exitCode: 130))
    }

    func testParseEndWithoutExitCode() {
        // "D" alone means finished with unknown status → treated as success.
        XCTAssertEqual(CommandMarker.parse(osc133: "D"), .end(exitCode: 0))
    }

    func testParseGarbageExitDefaultsToZero() {
        XCTAssertEqual(CommandMarker.parse(osc133: "D;abc"), .end(exitCode: 0))
    }

    func testParsePromptEnd() {
        // 133;B marks the end of the prompt — where the user's input begins.
        XCTAssertEqual(CommandMarker.parse(osc133: "B"), .promptEnd)
    }

    func testParseIgnoresUnhandledMarkers() {
        XCTAssertNil(CommandMarker.parse(osc133: "A"))   // prompt start (unused)
        XCTAssertNil(CommandMarker.parse(osc133: ""))
    }

    func testDurationFormatting() {
        XCTAssertEqual(BottomToolbar.durationString(0.4), "0.4s")
        XCTAssertEqual(BottomToolbar.durationString(3.24), "3.2s")
        XCTAssertEqual(BottomToolbar.durationString(65), "1m 05s")
        XCTAssertEqual(BottomToolbar.durationString(3661), "61m 01s")
    }
}
