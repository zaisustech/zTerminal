import XCTest
@testable import zTerminal

final class CommandMarkerTests: XCTestCase {

    func testParseStart() {
        XCTAssertEqual(CommandMarker.parse(osc133: "C"), .start)
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

    func testParseIgnoresPromptMarkers() {
        XCTAssertNil(CommandMarker.parse(osc133: "A"))   // prompt start
        XCTAssertNil(CommandMarker.parse(osc133: "B"))   // prompt end
        XCTAssertNil(CommandMarker.parse(osc133: ""))
    }

    func testDurationFormatting() {
        XCTAssertEqual(BottomToolbar.durationString(0.4), "0.4s")
        XCTAssertEqual(BottomToolbar.durationString(3.24), "3.2s")
        XCTAssertEqual(BottomToolbar.durationString(65), "1m 05s")
        XCTAssertEqual(BottomToolbar.durationString(3661), "61m 01s")
    }
}
