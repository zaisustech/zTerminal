import XCTest
@testable import zTerminal

final class GitStatusTests: XCTestCase {

    func testAheadBehindParsing() {
        // `rev-list --left-right --count @{upstream}...HEAD` → "<behind>\t<ahead>"
        XCTAssertEqual(Git.parseAheadBehind("2\t1").behind, 2)
        XCTAssertEqual(Git.parseAheadBehind("2\t1").ahead, 1)
        XCTAssertEqual(Git.parseAheadBehind("0\t0").behind, 0)
        XCTAssertEqual(Git.parseAheadBehind("0 0").ahead, 0)     // space separator too
    }

    func testAheadBehindNoUpstream() {
        // nil (command failed / no upstream) → zeros
        XCTAssertEqual(Git.parseAheadBehind(nil).behind, 0)
        XCTAssertEqual(Git.parseAheadBehind(nil).ahead, 0)
    }

    func testAheadBehindGarbage() {
        XCTAssertEqual(Git.parseAheadBehind("nonsense").ahead, 0)
        XCTAssertEqual(Git.parseAheadBehind("1 2 3").ahead, 0)   // wrong arity → zeros
    }

    func testDirtyDetection() {
        XCTAssertFalse(Git.isDirty(porcelain: nil))
        XCTAssertFalse(Git.isDirty(porcelain: ""))
        XCTAssertFalse(Git.isDirty(porcelain: "   \n "))
        XCTAssertTrue(Git.isDirty(porcelain: " M Sources/App.swift"))
        XCTAssertTrue(Git.isDirty(porcelain: "?? new.txt"))
    }
}
