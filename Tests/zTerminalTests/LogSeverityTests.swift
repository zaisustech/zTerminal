import XCTest
@testable import zTerminal

final class LogSeverityTests: XCTestCase {

    func testError() {
        XCTAssertEqual(LogSeverity.classify("2026-07-02 ERROR connection refused"), .error)
        XCTAssertEqual(LogSeverity.classify("Fatal: cannot allocate"), .error)
        XCTAssertEqual(LogSeverity.classify("Unhandled exception in worker"), .error)
        XCTAssertEqual(LogSeverity.classify("level=error msg=timeout"), .error)
    }

    func testWarning() {
        XCTAssertEqual(LogSeverity.classify("[warn] deprecated API"), .warning)
        XCTAssertEqual(LogSeverity.classify("WARNING: low disk space"), .warning)
    }

    func testInfo() {
        XCTAssertEqual(LogSeverity.classify("INFO server started on :8080"), .info)
        XCTAssertEqual(LogSeverity.classify("notice: config reloaded"), .info)
    }

    func testDebugAndTrace() {
        XCTAssertEqual(LogSeverity.classify("DEBUG cache hit"), .debug)
        XCTAssertEqual(LogSeverity.classify("TRACE entering fn"), .trace)
        XCTAssertEqual(LogSeverity.classify("verbose: handshake bytes"), .trace)
    }

    func testUnclassified() {
        XCTAssertEqual(LogSeverity.classify("Server started"), .none)
        XCTAssertEqual(LogSeverity.classify("connecting to database"), .none)
        XCTAssertEqual(LogSeverity.classify(""), .none)
    }

    func testHighestSeverityWins() {
        // A line mentioning both error and warn is classified as the higher one.
        XCTAssertEqual(LogSeverity.classify("ERROR while handling warning queue"), .error)
    }

    func testChipLevelsExcludeNone() {
        XCTAssertFalse(LogSeverity.chipLevels.contains(.none))
        XCTAssertEqual(LogSeverity.chipLevels, [.error, .warning, .info, .debug, .trace])
    }
}
