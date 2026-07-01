import XCTest
@testable import zTerminal

final class KeepAwakeTests: XCTestCase {
    func testOffNeverActive() {
        XCTAssertFalse(KeepAwakeManager.desiredActive(mode: .off, busy: false))
        XCTAssertFalse(KeepAwakeManager.desiredActive(mode: .off, busy: true))
    }
    func testAlwaysActive() {
        XCTAssertTrue(KeepAwakeManager.desiredActive(mode: .always, busy: false))
        XCTAssertTrue(KeepAwakeManager.desiredActive(mode: .always, busy: true))
    }
    func testWhileBusyTracksActivity() {
        XCTAssertFalse(KeepAwakeManager.desiredActive(mode: .whileBusy, busy: false))
        XCTAssertTrue(KeepAwakeManager.desiredActive(mode: .whileBusy, busy: true))
    }
    func testModeCycle() {
        XCTAssertEqual(KeepAwakeMode.off.next, .whileBusy)
        XCTAssertEqual(KeepAwakeMode.whileBusy.next, .always)
        XCTAssertEqual(KeepAwakeMode.always.next, .off)
    }
}
