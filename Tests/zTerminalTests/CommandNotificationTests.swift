import XCTest
@testable import zTerminal

final class CommandNotificationTests: XCTestCase {

    func testNotifiesWhenUnfocusedAndLongEnough() {
        XCTAssertTrue(AttentionManager.shouldNotifyOnFinish(
            enabled: true, focused: false, duration: 45, threshold: 30))
    }

    func testNoNotifyWhenFocused() {
        XCTAssertFalse(AttentionManager.shouldNotifyOnFinish(
            enabled: true, focused: true, duration: 120, threshold: 30))
    }

    func testNoNotifyWhenTooShort() {
        XCTAssertFalse(AttentionManager.shouldNotifyOnFinish(
            enabled: true, focused: false, duration: 5, threshold: 30))
    }

    func testNoNotifyWhenDisabled() {
        XCTAssertFalse(AttentionManager.shouldNotifyOnFinish(
            enabled: false, focused: false, duration: 999, threshold: 30))
    }

    func testAtThresholdNotifies() {
        XCTAssertTrue(AttentionManager.shouldNotifyOnFinish(
            enabled: true, focused: false, duration: 30, threshold: 30))
    }

    // Result carries the command text for the notification body.
    func testCommandResultCarriesCommand() {
        let r = CommandResult(exitCode: 0, duration: 12, command: "npm run build")
        XCTAssertEqual(r.command, "npm run build")
        XCTAssertTrue(r.succeeded)
    }
}
