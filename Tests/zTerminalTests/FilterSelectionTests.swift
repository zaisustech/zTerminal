import XCTest
@testable import zTerminal

final class FilterSelectionTests: XCTestCase {

    // Snapshot: 0 info, 1 error, 2 plain, 3 error, 4 warning
    private let snapshot: [(text: String, severity: LogSeverity)] = [
        ("INFO starting up", .info),
        ("ERROR database timeout", .error),
        ("just a plain line", .none),
        ("ERROR database closed", .error),
        ("WARN slow query", .warning),
    ]
    // "database" matched lines 1 and 3.
    private let matched: Set<Int> = [1, 3]

    private func select(hasQuery: Bool, invert: Bool = false, severity: LogSeverity? = nil) -> [Int] {
        SearchController.select(snapshot: snapshot, matched: matched,
                                hasQuery: hasQuery, invert: invert, severity: severity).map(\.id)
    }

    func testQueryOnly() {
        XCTAssertEqual(select(hasQuery: true), [1, 3])
    }

    func testInvert() {
        XCTAssertEqual(select(hasQuery: true, invert: true), [0, 2, 4])
    }

    func testSeverityOnlyNoQuery() {
        XCTAssertEqual(select(hasQuery: false, severity: .error), [1, 3])
        XCTAssertEqual(select(hasQuery: false, severity: .warning), [4])
    }

    func testQueryAndSeverity() {
        // matched (1,3) AND error → both are error, so [1,3]
        XCTAssertEqual(select(hasQuery: true, severity: .error), [1, 3])
        // matched (1,3) AND warning → none are warning
        XCTAssertEqual(select(hasQuery: true, severity: .warning), [])
    }

    func testInvertAndSeverity() {
        // non-matched (0,2,4) AND warning → [4]
        XCTAssertEqual(select(hasQuery: true, invert: true, severity: .warning), [4])
    }

    func testEmptyQueryAllSeverities() {
        XCTAssertEqual(select(hasQuery: false), [0, 1, 2, 3, 4])
    }

    func testEmptyQueryIgnoresInvert() {
        // Empty query shows all lines regardless of invert.
        XCTAssertEqual(select(hasQuery: false, invert: true), [0, 1, 2, 3, 4])
    }
}
