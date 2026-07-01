import XCTest
@testable import zTerminal

final class CwdLogicTests: XCTestCase {

    // MARK: parseOSC7

    func testParseLocalFileURL() {
        let r = CwdLogic.parseOSC7("file:///Users/alex/dev")
        XCTAssertEqual(r, CwdLogic.HostedPath(host: "", path: "/Users/alex/dev"))
    }

    func testParseHostedFileURL() {
        let r = CwdLogic.parseOSC7("file://mymac.local/Users/alex")
        XCTAssertEqual(r?.host, "mymac.local")
        XCTAssertEqual(r?.path, "/Users/alex")
    }

    func testParsePercentDecoding() {
        let r = CwdLogic.parseOSC7("file:///Users/alex/My%20Project")
        XCTAssertEqual(r?.path, "/Users/alex/My Project")
    }

    func testParseUnicode() {
        let r = CwdLogic.parseOSC7("file:///Users/alex/%E9%A1%B9%E7%9B%AE")
        XCTAssertEqual(r?.path, "/Users/alex/项目")
    }

    func testParseBarePath() {
        XCTAssertEqual(CwdLogic.parseOSC7("/tmp/x")?.path, "/tmp/x")
    }

    func testParseEmptyIsNil() {
        XCTAssertNil(CwdLogic.parseOSC7("   "))
        XCTAssertNil(CwdLogic.parseOSC7("file://host"))
    }

    // MARK: isLocalHost

    func testLocalHostDetection() {
        let names: Set<String> = ["mymac", "mymac.local"]
        XCTAssertTrue(CwdLogic.isLocalHost("", localNames: names))
        XCTAssertTrue(CwdLogic.isLocalHost("localhost", localNames: names))
        XCTAssertTrue(CwdLogic.isLocalHost("mymac.local", localNames: names))
        XCTAssertTrue(CwdLogic.isLocalHost("mymac", localNames: names))
        XCTAssertFalse(CwdLogic.isLocalHost("build-server", localNames: names))
    }

    // MARK: abbreviatingHome

    func testHomeAbbreviation() {
        XCTAssertEqual(CwdLogic.abbreviatingHome("/Users/alex/dev", home: "/Users/alex"), "~/dev")
        XCTAssertEqual(CwdLogic.abbreviatingHome("/Users/alex", home: "/Users/alex"), "~")
        XCTAssertEqual(CwdLogic.abbreviatingHome("/opt/x", home: "/Users/alex"), "/opt/x")
        // Must not treat /Users/alexander as under /Users/alex.
        XCTAssertEqual(CwdLogic.abbreviatingHome("/Users/alexander/x", home: "/Users/alex"), "/Users/alexander/x")
    }

    // MARK: validateOpenPath

    func testValidateExistingDirectory() {
        XCTAssertEqual(CwdLogic.validateOpenPath("/tmp"), URL(fileURLWithPath: "/tmp").resolvingSymlinksInPath().path)
    }

    func testValidateRejectsNonexistent() {
        XCTAssertNil(CwdLogic.validateOpenPath("/no/such/dir/zzz"))
    }

    func testValidateRejectsFile() {
        // A file, not a directory.
        let file = "/etc/hosts"
        if FileManager.default.fileExists(atPath: file) {
            XCTAssertNil(CwdLogic.validateOpenPath(file))
        }
    }

    func testValidateRejectsEmpty() {
        XCTAssertNil(CwdLogic.validateOpenPath("   "))
    }

    // MARK: openPath(fromURL:)

    func testOpenURLExtractsValidatedPath() {
        let url = URL(string: "zterminal://open?path=/tmp")!
        XCTAssertEqual(CwdLogic.openPath(fromURL: url),
                       URL(fileURLWithPath: "/tmp").resolvingSymlinksInPath().path)
    }

    func testOpenURLRejectsBadScheme() {
        let url = URL(string: "https://open?path=/tmp")!
        XCTAssertNil(CwdLogic.openPath(fromURL: url))
    }

    func testOpenURLRejectsBadPath() {
        let url = URL(string: "zterminal://open?path=/no/such/zzz")!
        XCTAssertNil(CwdLogic.openPath(fromURL: url))
    }
}
