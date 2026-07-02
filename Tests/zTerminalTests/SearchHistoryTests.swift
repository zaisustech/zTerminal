import XCTest
@testable import zTerminal

final class SearchHistoryTests: XCTestCase {

    private func makeHistory(cap: Int = 20) -> SearchHistory {
        // Isolated defaults so tests don't touch the real store or each other.
        let suite = "test.searchHistory.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        return SearchHistory(defaults: defaults, cap: cap)
    }

    func testRecordMostRecentFirst() {
        let h = makeHistory()
        h.record("database")
        h.record("error")
        h.record("timeout")
        XCTAssertEqual(h.terms, ["timeout", "error", "database"])
    }

    func testDeduplicatesCaseInsensitively() {
        let h = makeHistory()
        h.record("Error")
        h.record("database")
        h.record("error")               // same as "Error" → moves to front, no dup
        XCTAssertEqual(h.terms, ["error", "database"])
    }

    func testIgnoresBlank() {
        let h = makeHistory()
        h.record("   ")
        h.record("")
        XCTAssertTrue(h.terms.isEmpty)
    }

    func testTrimsWhitespace() {
        let h = makeHistory()
        h.record("  database  ")
        XCTAssertEqual(h.terms, ["database"])
    }

    func testCap() {
        let h = makeHistory(cap: 3)
        h.record("a"); h.record("b"); h.record("c"); h.record("d")
        XCTAssertEqual(h.terms, ["d", "c", "b"])   // oldest ("a") dropped
    }

    func testPersistsAcrossInstances() {
        let suite = "test.searchHistory.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        SearchHistory(defaults: defaults).record("persisted")
        let reloaded = SearchHistory(defaults: defaults)
        XCTAssertEqual(reloaded.terms, ["persisted"])
    }

    func testClear() {
        let h = makeHistory()
        h.record("database")
        h.clear()
        XCTAssertTrue(h.terms.isEmpty)
    }
}
