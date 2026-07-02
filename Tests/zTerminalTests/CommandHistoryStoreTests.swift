import XCTest
@testable import zTerminal

final class CommandHistoryStoreTests: XCTestCase {

    private var fileURL: URL!

    override func setUpWithError() throws {
        fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("history-\(UUID().uuidString).json")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: fileURL)
    }

    private func makeStore(cap: Int = 2000) -> CommandHistoryStore {
        CommandHistoryStore(cap: cap, fileURL: fileURL)
    }

    // MARK: Recording semantics

    func testRecordsMostRecentFirst() {
        let store = makeStore()
        store.record("first")
        store.record("second")
        XCTAssertEqual(store.entries, ["second", "first"])
    }

    func testRerunningDeduplicatesMostRecentWins() {
        let store = makeStore()
        store.record("git status")
        store.record("ls")
        store.record("git status")   // re-run → moves to front, no duplicate
        XCTAssertEqual(store.entries, ["git status", "ls"])
    }

    func testCapTrimsOldest() {
        let store = makeStore(cap: 3)
        ["a", "b", "c", "d"].forEach { store.record($0) }
        XCTAssertEqual(store.entries, ["d", "c", "b"])
    }

    func testLeadingSpaceIsNotRecorded() {
        let store = makeStore()
        store.record(" secret-token-command")
        XCTAssertTrue(store.entries.isEmpty)
    }

    func testEmptyAndWhitespaceAreNotRecorded() {
        let store = makeStore()
        store.record("")
        store.record("\n")
        store.record("\t")
        XCTAssertTrue(store.entries.isEmpty)
    }

    func testInternalHelpersAreNotRecorded() {
        let store = makeStore()
        store.record("_zt_osc7")
        store.record("__zt_preexec")
        store.record("_zt_preview split README.md")
        XCTAssertTrue(store.entries.isEmpty)
    }

    // MARK: Suggestion semantics

    func testSuggestionPrefersMostRecentPrefixMatch() {
        let store = makeStore()
        store.record("git push origin main")
        store.record("git pull")
        XCTAssertEqual(store.suggestion(forPrefix: "git p"), "git pull")
        store.record("git push origin main")   // re-run flips recency
        XCTAssertEqual(store.suggestion(forPrefix: "git p"), "git push origin main")
    }

    func testSuggestionRequiresStrictlyLongerMatch() {
        let store = makeStore()
        store.record("ls")
        XCTAssertNil(store.suggestion(forPrefix: "ls"), "exact match has no suffix to suggest")
        XCTAssertEqual(store.suggestion(forPrefix: "l"), "ls")
    }

    func testEmptyPrefixYieldsNothing() {
        let store = makeStore()
        store.record("ls")
        XCTAssertNil(store.suggestion(forPrefix: ""))
    }

    func testNoMatchYieldsNothing() {
        let store = makeStore()
        store.record("ls")
        XCTAssertNil(store.suggestion(forPrefix: "docker"))
    }

    func testMultilineEntriesAreStoredButNotSuggested() {
        let store = makeStore()
        store.record("echo one\necho two")
        XCTAssertEqual(store.entries.count, 1, "multiline commands are kept in history")
        XCTAssertNil(store.suggestion(forPrefix: "echo"), "single-line ghost can't render them")
    }

    // MARK: Persistence

    func testPersistsAndReloads() {
        let store = makeStore()
        store.record("swift build")
        store.record("swift test")
        store.persistNow()
        // Background write — poll briefly.
        let deadline = Date().addingTimeInterval(2)
        while !FileManager.default.fileExists(atPath: fileURL.path), Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        }
        let reloaded = makeStore()
        XCTAssertEqual(reloaded.entries, ["swift test", "swift build"])
    }

    func testCorruptFileLoadsAsEmpty() throws {
        try Data("not json{{{".utf8).write(to: fileURL)
        XCTAssertTrue(makeStore().entries.isEmpty)
    }

    func testMissingFileLoadsAsEmpty() {
        XCTAssertTrue(makeStore().entries.isEmpty)
    }

    // MARK: Ghost source integration

    func testGhostSourceReturnsSuffixOnly() {
        let store = makeStore()
        store.record("swift build -c release")
        let source = CommandHistorySource(store: store)
        XCTAssertEqual(source.ghostSuffix(forInput: "swift b", cwd: "/tmp"), "uild -c release")
        XCTAssertNil(source.ghostSuffix(forInput: "cargo", cwd: "/tmp"))
        XCTAssertNil(source.ghostSuffix(forInput: "", cwd: "/tmp"))
    }
}
