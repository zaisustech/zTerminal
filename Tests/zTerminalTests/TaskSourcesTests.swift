import XCTest
@testable import zTerminal

final class TaskSourcesTests: XCTestCase {
    private var dir: String!
    override func setUpWithError() throws {
        dir = NSTemporaryDirectory() + "zt-src-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(atPath: dir) }
    private func write(_ name: String, _ contents: String = "") {
        try? contents.write(toFile: (dir as NSString).appendingPathComponent(name), atomically: true, encoding: .utf8)
    }

    func testUnrecognizedDirectory() {
        XCTAssertFalse(TaskRunner.isRecognized(dir))
        XCTAssertTrue(TaskRunner.detect(in: dir).isEmpty)
    }

    func testCargoDetected() {
        write("Cargo.toml", "[package]")
        XCTAssertTrue(TaskRunner.isRecognized(dir))
        let g = TaskRunner.detect(in: dir).first { $0.title == "Cargo" }
        XCTAssertNotNil(g)
        XCTAssertTrue(g!.tasks.contains { $0.runCommand == "cargo run" })
    }

    func testMavenPrefersWrapper() {
        write("pom.xml", "<project/>")
        write("mvnw", "#!/bin/sh")
        let g = MavenTaskSource().detect(in: dir, fileManager: .default)
        XCTAssertEqual(g?.title, "Maven")
        XCTAssertTrue(g!.tasks.contains { $0.runCommand == "./mvnw spring-boot:run" })
    }

    func testGradleWrapper() {
        write("build.gradle.kts")
        write("gradlew", "#!/bin/sh")
        let g = GradleTaskSource().detect(in: dir, fileManager: .default)
        XCTAssertTrue(g!.tasks.contains { $0.runCommand == "./gradlew bootRun" })
    }

    func testDjangoDetected() {
        write("manage.py", "import django")
        let g = TaskRunner.detect(in: dir).first { $0.title == "Django" }
        XCTAssertNotNil(g)
        XCTAssertTrue(g!.tasks.contains { $0.runCommand == "python manage.py runserver" })
    }

    func testGoDetected() {
        write("go.mod", "module x")
        let g = TaskRunner.detect(in: dir).first { $0.title == "Go" }
        XCTAssertTrue(g!.tasks.contains { $0.runCommand == "go test ./..." })
    }

    func testMakefileTargetsParsed() {
        write("Makefile", """
        .PHONY: build test
        VERSION := 1.0
        build:
        \tgo build
        test: build
        \tgo test
        %.o: %.c
        \tcc -c $<
        """)
        let targets = MakeTaskSource.parseTargets(try! String(contentsOfFile: (dir as NSString).appendingPathComponent("Makefile"), encoding: .utf8))
        XCTAssertTrue(targets.contains("build"))
        XCTAssertTrue(targets.contains("test"))
        XCTAssertFalse(targets.contains(".PHONY"))
        XCTAssertFalse(targets.contains("VERSION"))
        XCTAssertFalse(targets.contains { $0.contains("%") })
    }

    func testDotNetDetected() {
        write("App.csproj", "<Project/>")
        let g = TaskRunner.detect(in: dir).first { $0.title == ".NET" }
        XCTAssertTrue(g!.tasks.contains { $0.runCommand == "dotnet run" })
    }

    func testDenoTasksParsed() {
        write("deno.json", #"{"tasks":{"start":"deno run main.ts"}}"#)
        let g = DenoTaskSource().detect(in: dir, fileManager: .default)
        XCTAssertTrue(g!.tasks.contains { $0.runCommand == "deno task start" })
        XCTAssertTrue(g!.tasks.contains { $0.runCommand == "deno test" })
    }

    func testRubyRakeTasksAndBundler() {
        write("Gemfile", "source 'https://rubygems.org'")
        write("Rakefile", "task :build do\nend\ntask \"spec\" do\nend")
        let g = RubyTaskSource().detect(in: dir, fileManager: .default)
        XCTAssertTrue(g!.tasks.contains { $0.runCommand == "bundle install" })
        XCTAssertTrue(g!.tasks.contains { $0.runCommand == "bundle exec rake build" })
        XCTAssertTrue(g!.tasks.contains { $0.runCommand == "bundle exec rake spec" })
    }

    func testMultipleEcosystemsGrouped() {
        write("package.json", #"{"scripts":{"dev":"vite"}}"#)
        write("Cargo.toml", "[package]")
        let titles = TaskRunner.detect(in: dir).map(\.title)
        XCTAssertTrue(titles.contains { $0.hasPrefix("Node") })
        XCTAssertTrue(titles.contains("Cargo"))
    }
}
