import XCTest
@testable import zTerminal

final class CodeLanguageTests: XCTestCase {

    func testDetectByExtension() {
        XCTAssertEqual(CodeLanguage.detect(filename: "App.swift"), .swift)
        XCTAssertEqual(CodeLanguage.detect(filename: "index.tsx"), .typescript)
        XCTAssertEqual(CodeLanguage.detect(filename: "main.js"), .javascript)
        XCTAssertEqual(CodeLanguage.detect(filename: "data.json"), .json)
        XCTAssertEqual(CodeLanguage.detect(filename: "run.py"), .python)
        XCTAssertEqual(CodeLanguage.detect(filename: "build.sh"), .shell)
        XCTAssertEqual(CodeLanguage.detect(filename: "README.md"), .markdown)
        XCTAssertEqual(CodeLanguage.detect(filename: "conf.yaml"), .yaml)
        XCTAssertEqual(CodeLanguage.detect(filename: "main.rs"), .rust)
    }

    func testUnknownIsPlainText() {
        XCTAssertEqual(CodeLanguage.detect(filename: "notes.xyz"), .plainText)
        XCTAssertEqual(CodeLanguage.detect(filename: "Makefile"), .plainText)
    }

    func testShebangFallback() {
        XCTAssertEqual(CodeLanguage.fromShebang("#!/usr/bin/env python3"), .python)
        XCTAssertEqual(CodeLanguage.fromShebang("#!/bin/bash"), .shell)
        XCTAssertEqual(CodeLanguage.fromShebang("#!/usr/bin/env node"), .javascript)
        XCTAssertNil(CodeLanguage.fromShebang("not a shebang"))
    }

    func testDetectURLUsesShebangWhenNoExtension() {
        let url = URL(fileURLWithPath: "/tmp/script")
        XCTAssertEqual(CodeLanguage.detect(url: url, firstLine: "#!/bin/bash"), .shell)
        XCTAssertEqual(CodeLanguage.detect(url: url, firstLine: "plain"), .plainText)
    }

    func testExtensionWinsOverShebang() {
        let url = URL(fileURLWithPath: "/tmp/x.swift")
        XCTAssertEqual(CodeLanguage.detect(url: url, firstLine: "#!/bin/bash"), .swift)
    }
}

final class SyntaxHighlighterTests: XCTestCase {

    private func kinds(_ source: String, _ lang: CodeLanguage) -> [SyntaxHighlighter.TokenKind] {
        SyntaxHighlighter.tokens(source: source, language: lang).map(\.kind)
    }

    private func text(_ source: String, _ token: SyntaxHighlighter.Token) -> String {
        (source as NSString).substring(with: token.range)
    }

    func testSwiftKeywordsStringsCommentsNumbers() {
        let src = "let x = 42 // note\nlet s = \"hi\""
        let toks = SyntaxHighlighter.tokens(source: src, language: .swift)
        let byText = Dictionary(grouping: toks, by: { text(src, $0) })
        XCTAssertNotNil(byText["let"]?.first.map { $0.kind == .keyword })
        XCTAssertTrue(toks.contains { text(src, $0) == "42" && $0.kind == .number })
        XCTAssertTrue(toks.contains { text(src, $0) == "// note" && $0.kind == .comment })
        XCTAssertTrue(toks.contains { text(src, $0) == "\"hi\"" && $0.kind == .string })
    }

    func testKeywordInsideStringNotHighlighted() {
        // "let" inside a string literal must be a string, not a keyword.
        let src = "\"let me in\""
        let toks = SyntaxHighlighter.tokens(source: src, language: .swift)
        XCTAssertEqual(toks.count, 1)
        XCTAssertEqual(toks.first?.kind, .string)
    }

    func testKeywordInsideCommentNotHighlighted() {
        let src = "// return here"
        let toks = SyntaxHighlighter.tokens(source: src, language: .swift)
        XCTAssertEqual(toks.map(\.kind), [.comment])
    }

    func testPlainTextHasNoTokens() {
        XCTAssertTrue(SyntaxHighlighter.tokens(source: "just words 42", language: .plainText).isEmpty)
    }

    func testPythonHashComment() {
        let src = "x = 1  # comment"
        let toks = SyntaxHighlighter.tokens(source: src, language: .python)
        XCTAssertTrue(toks.contains { text(src, $0) == "# comment" && $0.kind == .comment })
    }

    func testTokensAreOrdered() {
        let src = "func f() { return 1 }"
        let locs = SyntaxHighlighter.tokens(source: src, language: .swift).map(\.range.location)
        XCTAssertEqual(locs, locs.sorted())
    }
}
