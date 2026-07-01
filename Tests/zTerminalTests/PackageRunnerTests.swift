import XCTest
@testable import zTerminal

final class PackageRunnerTests: XCTestCase {
    private var dir: String!

    override func setUpWithError() throws {
        dir = NSTemporaryDirectory() + "zt-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(atPath: dir)
    }

    private func write(_ name: String, _ contents: String) {
        try? contents.write(toFile: (dir as NSString).appendingPathComponent(name),
                            atomically: true, encoding: .utf8)
    }

    // MARK: package manager detection

    func testLockfileDetection() {
        write("pnpm-lock.yaml", "")
        XCTAssertEqual(PackageRunner.detectManager(in: dir), .pnpm)
    }

    func testYarnLock() {
        write("yarn.lock", "")
        XCTAssertEqual(PackageRunner.detectManager(in: dir), .yarn)
    }

    func testBunLock() {
        write("bun.lockb", "")
        XCTAssertEqual(PackageRunner.detectManager(in: dir), .bun)
    }

    func testDefaultsToNpm() {
        XCTAssertEqual(PackageRunner.detectManager(in: dir), .npm)
    }

    func testPackageManagerFieldWins() {
        // Lockfile says npm, but the field says pnpm — field wins.
        write("package-lock.json", "{}")
        let json: [String: Any] = ["packageManager": "pnpm@9.1.0"]
        XCTAssertEqual(PackageRunner.detectManager(in: dir, packageJSON: json), .pnpm)
    }

    func testMultipleManagersDetected() {
        write("yarn.lock", "")
        write("package-lock.json", "{}")
        let mgrs = PackageRunner.detectManagers(in: dir)
        XCTAssertTrue(mgrs.contains(.yarn))
        XCTAssertTrue(mgrs.contains(.npm))
        XCTAssertEqual(mgrs.count, 2)
        // Preferred (first) drives the default.
        XCTAssertEqual(PackageRunner.detectManager(in: dir), mgrs.first)
    }

    func testSingleManagerWhenOneLockfile() {
        write("pnpm-lock.yaml", "")
        XCTAssertEqual(PackageRunner.detectManagers(in: dir), [.pnpm])
    }

    func testRunCommandFormatting() {
        XCTAssertEqual(PackageManager.npm.runCommand(for: "dev"), "npm run dev")
        XCTAssertEqual(PackageManager.pnpm.runCommand(for: "dev"), "pnpm run dev")
        XCTAssertEqual(PackageManager.yarn.runCommand(for: "dev"), "yarn dev")
        XCTAssertEqual(PackageManager.bun.runCommand(for: "build"), "bun run build")
    }

    // MARK: script loading

    func testLoadNilWithoutPackageJSON() {
        XCTAssertNil(PackageRunner.load(in: dir))
    }

    func testLoadScripts() {
        write("package.json", #"{"scripts":{"dev":"vite","build":"vite build"}}"#)
        write("pnpm-lock.yaml", "")
        let result = PackageRunner.load(in: dir)
        XCTAssertNotNil(result)
        XCTAssertNil(result?.error)
        XCTAssertEqual(result?.manager, .pnpm)
        XCTAssertEqual(result?.tasks.map(\.name), ["build", "dev"])  // sorted
        let dev = result?.tasks.first { $0.name == "dev" }
        XCTAssertEqual(dev?.rawCommand, "vite")
        XCTAssertEqual(dev?.runCommand, "pnpm run dev")
    }

    func testMalformedJSON() {
        write("package.json", "{ not json ")
        let result = PackageRunner.load(in: dir)
        XCTAssertNotNil(result?.error)
        XCTAssertEqual(result?.tasks.count, 0)
    }

    func testEmptyScripts() {
        write("package.json", #"{"name":"x"}"#)
        let result = PackageRunner.load(in: dir)
        XCTAssertNil(result?.error)
        XCTAssertEqual(result?.tasks.count, 0)
    }

    func testHasPackageJSON() {
        XCTAssertFalse(PackageRunner.hasPackageJSON(in: dir))
        write("package.json", "{}")
        XCTAssertTrue(PackageRunner.hasPackageJSON(in: dir))
    }
}
