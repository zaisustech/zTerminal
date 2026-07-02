import XCTest
@testable import zTerminal

final class FuzzyMatchTests: XCTestCase {

    func testSubsequenceMatches() {
        XCTAssertNotNil(FuzzyMatch.score(query: "dev", candidate: "dev"))
        XCTAssertNotNil(FuzzyMatch.score(query: "dv", candidate: "dev"))          // subsequence
        XCTAssertNotNil(FuzzyMatch.score(query: "bd", candidate: "build:docs"))
    }

    func testNonSubsequenceFails() {
        XCTAssertNil(FuzzyMatch.score(query: "xyz", candidate: "dev"))
        XCTAssertNil(FuzzyMatch.score(query: "devv", candidate: "dev"))           // too long
    }

    func testEmptyQueryScoresZero() {
        XCTAssertEqual(FuzzyMatch.score(query: "", candidate: "anything"), 0)
    }

    func testCaseInsensitive() {
        XCTAssertNotNil(FuzzyMatch.score(query: "DEV", candidate: "dev server"))
    }

    func testContiguousBeatsScattered() {
        let contiguous = FuzzyMatch.score(query: "dev", candidate: "dev")!
        let scattered = FuzzyMatch.score(query: "dev", candidate: "d_e_v")!
        XCTAssertGreaterThan(contiguous, scattered)
    }

    func testPrefixBeatsMiddle() {
        let prefix = FuzzyMatch.score(query: "run", candidate: "run tests")!
        let middle = FuzzyMatch.score(query: "run", candidate: "prerun")!
        XCTAssertGreaterThan(prefix, middle)
    }
}

final class PaletteRankerTests: XCTestCase {

    private func item(_ title: String, _ cat: PaletteItem.Category, subtitle: String = "") -> PaletteItem {
        PaletteItem(id: title, category: cat, title: title, subtitle: subtitle, icon: "x", activate: { _ in })
    }

    func testEmptyQueryOrdersByCategory() {
        let items = [item("z", .app), item("a", .bookmark), item("t", .tab)]
        let out = PaletteRanker.ranked(items, query: "").map(\.title)
        // Category order: bookmark < tab < app.
        XCTAssertEqual(out, ["a", "t", "z"])
    }

    func testQueryFiltersAndRanks() {
        let items = [item("deploy", .task), item("dev", .task), item("readme", .bookmark)]
        let out = PaletteRanker.ranked(items, query: "dev").map(\.title)
        XCTAssertEqual(out.first, "dev")            // best match first
        XCTAssertFalse(out.contains("readme"))       // non-match filtered out
    }

    func testTitleBeatsSubtitleMatch() {
        let titled = item("build", .task)
        let subOnly = item("xyz", .task, subtitle: "build project")
        let out = PaletteRanker.ranked([subOnly, titled], query: "build").map(\.title)
        XCTAssertEqual(out.first, "build")           // title match outranks subtitle match
    }
}

final class RecentDirectoriesTests: XCTestCase {
    private func make(cap: Int = 20) -> RecentDirectories {
        RecentDirectories(defaults: UserDefaults(suiteName: "test.recentDirs.\(UUID())")!, cap: cap)
    }

    func testMostRecentFirstDedup() {
        let r = make()
        r.record("/a"); r.record("/b"); r.record("/a")
        XCTAssertEqual(r.paths, ["/a", "/b"])
    }

    func testIgnoresRootAndEmpty() {
        let r = make()
        r.record("/"); r.record("   ")
        XCTAssertTrue(r.paths.isEmpty)
    }

    func testCap() {
        let r = make(cap: 2)
        r.record("/a"); r.record("/b"); r.record("/c")
        XCTAssertEqual(r.paths, ["/c", "/b"])
    }
}
