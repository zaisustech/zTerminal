import XCTest
@testable import zTerminal

final class TerminalSearchTests: XCTestCase {

    private let sampleLines = [
        "Server started",
        "Connecting to database",
        "database connection established",
        "Query executed",
        "Closing DATABASE",
    ]

    private func search(_ query: String, _ options: TerminalSearch.Options = .init(),
                        lines: [String]? = nil) -> TerminalSearch {
        var s = TerminalSearch()
        s.recompute(query: query, options: options, lines: lines ?? sampleLines)
        return s
    }

    // MARK: Substring (default, case-insensitive)

    func testCaseInsensitiveSubstring() {
        let s = search("database")
        // "database", "database", "DATABASE" → 3 matches, first active.
        XCTAssertEqual(s.total, 3)
        XCTAssertEqual(s.currentPosition, 1)
        XCTAssertEqual(s.matches.map(\.line), [1, 2, 4])
    }

    func testCaseSensitive() {
        let s = search("database", .init(caseSensitive: true))
        // Only exact-case "database" (lines 1 and 2), not "DATABASE".
        XCTAssertEqual(s.total, 2)
        XCTAssertEqual(s.matches.map(\.line), [1, 2])
    }

    func testMatchRangeColumns() {
        let s = search("database", .init(caseSensitive: true))
        // "Connecting to database" — "database" starts at column 14.
        XCTAssertEqual(s.matches.first?.range, 14 ..< 22)
    }

    func testNoMatches() {
        let s = search("nonexistent")
        XCTAssertTrue(s.isEmpty)
        XCTAssertEqual(s.total, 0)
        XCTAssertEqual(s.currentPosition, 0)
        XCTAssertNil(s.activeIndex)
    }

    func testEmptyQueryClears() {
        var s = search("database")
        s.recompute(query: "   ", options: .init(), lines: sampleLines)
        XCTAssertTrue(s.isEmpty)
        XCTAssertNil(s.activeIndex)
    }

    func testNonOverlappingSubstring() {
        let s = search("aa", lines: ["aaaa"])
        // "aaaa" → two non-overlapping "aa" at 0..2 and 2..4.
        XCTAssertEqual(s.matches.map(\.range), [0 ..< 2, 2 ..< 4])
    }

    // MARK: Whole word

    func testWholeWord() {
        let lines = ["err", "error", "stderr", "an err here"]
        let s = search("err", .init(wholeWord: true), lines: lines)
        // Standalone "err" only: line 0 and line 3, not inside "error"/"stderr".
        XCTAssertEqual(s.matches.map(\.line), [0, 3])
    }

    // MARK: Regex

    func testRegex() {
        let lines = ["error", "errno", "erroneous", "warning"]
        let s = search("err(or|no)", .init(regex: true), lines: lines)
        // Matches "error" (err+or) and "errno" (err+no); "erroneous" is err+"on…" → no match.
        XCTAssertEqual(s.matches.map(\.line), [0, 1])
    }

    func testInvalidRegexIsSafe() {
        var s = TerminalSearch()
        s.recompute(query: "err(", options: .init(regex: true), lines: sampleLines)
        XCTAssertFalse(s.isValid)
        XCTAssertTrue(s.isEmpty)
        XCTAssertNil(s.activeIndex)
    }

    func testRegexKeepsSpacesLiteral() {
        let lines = ["a b c", "database error"]
        let s = search("database error", .init(regex: true), lines: lines)
        // One pattern with a literal space, not two keywords.
        XCTAssertEqual(s.keywordCount, 1)
        XCTAssertEqual(s.matches.map(\.line), [1])
    }

    // MARK: Multi-keyword

    func testMultiKeyword() {
        let lines = ["database here", "an error occurred", "timeout reached", "nothing"]
        let s = search("database error timeout", lines: lines)
        XCTAssertEqual(s.keywordCount, 3)
        XCTAssertEqual(s.total, 3)
        // Each keyword tagged with its own index for coloring.
        XCTAssertEqual(s.matches.map(\.keyword).sorted(), [0, 1, 2])
    }

    func testMultiKeywordUnionInBufferOrder() {
        let lines = ["error database", "database again"]
        let s = search("database error", lines: lines)
        // Within line 0: "error"(kw1)@0, "database"(kw0)@6 → ordered by column.
        XCTAssertEqual(s.matches.map(\.line), [0, 0, 1])
        XCTAssertEqual(s.matches[0].range.lowerBound, 0)     // "error" first
        XCTAssertEqual(s.matches[1].range.lowerBound, 6)     // "database" second
    }

    // MARK: Navigation

    func testNextWrapsAround() {
        var s = search("database")   // 3 matches, active = index 0
        s.next(); XCTAssertEqual(s.currentPosition, 2)
        s.next(); XCTAssertEqual(s.currentPosition, 3)
        s.next(); XCTAssertEqual(s.currentPosition, 1)   // wrap
    }

    func testPreviousWrapsAround() {
        var s = search("database")   // active = index 0
        s.previous(); XCTAssertEqual(s.currentPosition, 3) // wrap to last
        s.previous(); XCTAssertEqual(s.currentPosition, 2)
    }

    func testActivateNearest() {
        var s = search("database")   // lines 1, 2, 4
        s.activateNearest(line: 4, col: 0)
        XCTAssertEqual(s.activeMatch?.line, 4)
        s.activateNearest(line: 0, col: 0)
        XCTAssertEqual(s.activeMatch?.line, 1)
    }

    // MARK: Recompute stability

    func testActiveMatchPreservedAcrossRecompute() {
        var s = search("database")
        s.next()                                  // active on line 2
        let activeLine = s.activeMatch?.line
        // New line prepended (simulating scrollback growth) shifts nothing about
        // the matched text; active match should still point at the same match.
        var grown = sampleLines
        grown.append("more database output")      // append keeps existing indices
        s.recompute(query: "database", options: .init(), lines: grown)
        XCTAssertEqual(s.activeMatch?.line, activeLine)
        XCTAssertEqual(s.total, 4)
    }

    func testActiveIndexClampedWhenMatchesShrink() {
        var s = search("database")
        s.next(); s.next()                        // active = last (index 2)
        s.recompute(query: "database", options: .init(), lines: ["database once"])
        XCTAssertEqual(s.total, 1)
        XCTAssertEqual(s.activeIndex, 0)          // clamped into range
    }
}
