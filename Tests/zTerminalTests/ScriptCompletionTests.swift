import XCTest
@testable import zTerminal

final class ScriptCompletionTests: XCTestCase {

    private let scripts = ["build", "dev", "start", "test"]

    // MARK: - Manager-aware matching (lockfile-detected managers)

    func testBunProjectCompletesBunRun() {
        XCTAssertEqual(ScriptCompletion.ghostSuffix(forInput: "bun run d",
                                                    managers: [.bun], scripts: scripts), "ev")
    }

    func testNpmProjectCompletesNpmRun() {
        XCTAssertEqual(ScriptCompletion.ghostSuffix(forInput: "npm run bu",
                                                    managers: [.npm], scripts: scripts), "ild")
    }

    func testYarnProjectCompletesBareYarn() {
        // yarn runs scripts without `run`.
        XCTAssertEqual(ScriptCompletion.ghostSuffix(forInput: "yarn te",
                                                    managers: [.yarn], scripts: scripts), "st")
        XCTAssertEqual(ScriptCompletion.ghostSuffix(forInput: "yarn run te",
                                                    managers: [.yarn], scripts: scripts), "st")
    }

    func testPnpmProjectCompletesBareAndRun() {
        XCTAssertEqual(ScriptCompletion.ghostSuffix(forInput: "pnpm de",
                                                    managers: [.pnpm], scripts: scripts), "v")
        XCTAssertEqual(ScriptCompletion.ghostSuffix(forInput: "pnpm run de",
                                                    managers: [.pnpm], scripts: scripts), "v")
    }

    // MARK: - The lockfile gate (the reported bug)

    func testCommandWordMustMatchADetectedManager() {
        // A yarn.lock project: `bun run …` must NOT complete (bun not detected).
        XCTAssertNil(ScriptCompletion.ghostSuffix(forInput: "bun run d",
                                                  managers: [.yarn], scripts: scripts))
        // An npm project: `yarn …` must NOT complete.
        XCTAssertNil(ScriptCompletion.ghostSuffix(forInput: "yarn dev",
                                                  managers: [.npm], scripts: scripts))
    }

    func testNpmDoesNotCompleteBareScript() {
        // npm needs `run`; `npm dev` is not a script slot.
        XCTAssertNil(ScriptCompletion.ghostSuffix(forInput: "npm de",
                                                  managers: [.npm], scripts: scripts))
    }

    func testMultipleDetectedManagersEachComplete() {
        let mgrs: [PackageManager] = [.bun, .npm]
        XCTAssertEqual(ScriptCompletion.ghostSuffix(forInput: "bun de", managers: mgrs, scripts: scripts), "v")
        XCTAssertEqual(ScriptCompletion.ghostSuffix(forInput: "npm run de", managers: mgrs, scripts: scripts), "v")
    }

    // MARK: - Prefix / ranking semantics

    func testEmptyPartialSuggestsRankedFirst() {
        XCTAssertEqual(ScriptCompletion.ghostSuffix(forInput: "bun run ",
                                                    managers: [.bun],
                                                    scripts: ScriptCompletion.ranked(scripts)), "dev")
    }

    func testCompleteWordYieldsNoGhostOfItself() {
        XCTAssertNil(ScriptCompletion.ghostSuffix(forInput: "bun run dev",
                                                  managers: [.bun], scripts: scripts))
    }

    func testAmbiguousPrefixPicksRankedFirst() {
        let s = ["stage", "start", "stop"]
        XCTAssertEqual(ScriptCompletion.ghostSuffix(forInput: "npm run st",
                                                    managers: [.npm],
                                                    scripts: ScriptCompletion.ranked(s)), "art")
    }

    // MARK: - No-suggestion cases

    func testNonManagerCommandIsIgnored() {
        XCTAssertNil(ScriptCompletion.ghostSuffix(forInput: "git s", managers: [.bun], scripts: scripts))
        XCTAssertNil(ScriptCompletion.ghostSuffix(forInput: "", managers: [.bun], scripts: scripts))
    }

    func testNoMatchingScriptYieldsNil() {
        XCTAssertNil(ScriptCompletion.ghostSuffix(forInput: "bun run zzz", managers: [.bun], scripts: scripts))
    }

    func testNoScriptsOrNoManagersYieldsNil() {
        XCTAssertNil(ScriptCompletion.ghostSuffix(forInput: "bun run d", managers: [.bun], scripts: []))
        XCTAssertNil(ScriptCompletion.ghostSuffix(forInput: "bun run d", managers: [], scripts: scripts))
    }

    func testSecondArgumentIsNotAScriptSlot() {
        XCTAssertNil(ScriptCompletion.ghostSuffix(forInput: "bun run dev ", managers: [.bun], scripts: scripts))
        XCTAssertNil(ScriptCompletion.ghostSuffix(forInput: "npm run test extra", managers: [.npm], scripts: scripts))
    }

    func testLeadingWhitespaceTolerated() {
        XCTAssertEqual(ScriptCompletion.ghostSuffix(forInput: "  bun run d",
                                                    managers: [.bun], scripts: scripts), "ev")
    }

    // MARK: - ranked

    func testRankedFloatsPreferredNamesInPriorityOrder() {
        XCTAssertEqual(ScriptCompletion.ranked(["build", "test", "start", "dev"]),
                       ["dev", "start", "build", "test"])
    }

    func testRankedKeepsTailOrderAndOmitsAbsentPreferred() {
        XCTAssertEqual(ScriptCompletion.ranked(["lint", "build", "test"]),
                       ["lint", "build", "test"])
    }
}
