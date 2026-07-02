import XCTest
import WebKit
@testable import zTerminal

/// End-to-end renderer tests: a real (offscreen) WKWebView running the bundled
/// preview.js, driven through the same PreviewPaneModel bridge the app uses.
/// This is what verifies GFM rendering, block-diff stability, sanitization,
/// search, and large-document speed without launching the app.
@MainActor
final class PreviewRendererTests: XCTestCase {

    private var model: PreviewPaneModel!
    private var source: StreamPreviewSource!
    private var coordinator: PreviewWebView.Coordinator!
    private var webView: WKWebView!

    override func setUp() {
        super.setUp()
        source = StreamPreviewSource(title: "test")
        model = PreviewPaneModel(source: source)
        coordinator = PreviewWebView.Coordinator(model: model)
        webView = PreviewWebView.makeConfiguredWebView(model: model, coordinator: coordinator)
        XCTAssertTrue(waitFor("typeof window.preview === 'object'", timeout: 10),
                      "renderer never became ready — is Resources/Preview built?")
    }

    override func tearDown() {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "preview")
        webView = nil
        super.tearDown()
    }

    // MARK: Helpers

    /// Pump the main run loop until `js` evaluates truthy (or timeout).
    @discardableResult
    private func waitFor(_ js: String, timeout: TimeInterval = 5) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        var result = false
        while Date() < deadline && !result {
            var done = false
            webView.evaluateJavaScript("!!(\(js))") { value, _ in
                result = (value as? Bool) ?? false
                done = true
            }
            while !done { RunLoop.main.run(until: Date().addingTimeInterval(0.02)) }
            if !result { RunLoop.main.run(until: Date().addingTimeInterval(0.05)) }
        }
        return result
    }

    private func eval(_ js: String) -> Any? {
        var result: Any?
        var done = false
        webView.evaluateJavaScript(js) { value, _ in result = value; done = true }
        while !done { RunLoop.main.run(until: Date().addingTimeInterval(0.02)) }
        return result
    }

    // MARK: Tests

    func testRendersCoreGFM() {
        source.replace("""
        # Title

        Text with **bold**, `code`, :rocket:, and a [link](https://example.com).

        | A | B |
        | - | - |
        | 1 | 2 |

        - [x] done
        - [ ] todo

        > Note
        > A callout.

        ```swift
        let x = 1
        ```

        Math: $e^2$

        Footnote[^1]

        [^1]: text
        """)
        XCTAssertTrue(waitFor("document.querySelector('#content h1')?.textContent === 'Title'"))
        XCTAssertTrue(waitFor("document.querySelector('#content table td') !== null"))
        XCTAssertTrue(waitFor("document.querySelectorAll('#content input[type=checkbox]').length === 2"))
        XCTAssertTrue(waitFor("document.querySelector('#content .callout-note .callout-title') !== null"))
        XCTAssertTrue(waitFor("document.querySelector('#content .code-block[data-lang=swift] .cl') !== null"))
        XCTAssertTrue(waitFor("document.querySelector('#content .katex') !== null"))
        XCTAssertTrue(waitFor("document.querySelector('#content .footnotes') !== null"))
        XCTAssertTrue(waitFor("document.querySelector('#content .toc-item, #toc .toc-item') !== null"))
    }

    func testStreamingKeepsEarlierDOMNodesAlive() {
        source.replace("# Stable\n\nfirst paragraph\n\n")
        XCTAssertTrue(waitFor("document.querySelectorAll('#content > *').length >= 2"))
        // Tag the live paragraph node, then stream more content after it.
        _ = eval("document.querySelector('#content p').dataset.probe = 'alive'")
        source.append("## More\n\nsecond paragraph\n")
        XCTAssertTrue(waitFor("document.querySelector('#content h2') !== null"))
        // The original paragraph element must be the same DOM node — block diff
        // may not rebuild unchanged blocks (no flicker, no image refetch).
        XCTAssertTrue(waitFor("document.querySelector('#content p')?.dataset.probe === 'alive'"))
    }

    func testOpenFenceRendersAsCodeBlockMidStream() {
        source.replace("```typescript\nconst a = 1\n")   // fence never closed
        XCTAssertTrue(waitFor("document.querySelector('#content .code-block[data-lang=typescript]') !== null"),
                      "unclosed fence should render as a live code block")
    }

    func testScriptsNeverExecuteEvenWithHTMLEnabled() {
        _ = eval("preview.setHTMLEnabled(true)")
        source.replace("before\n\n<script>window.__pwned = 1; document.title='xss'</script>\n\n<div onclick=\"window.__pwned=2\" id=\"probe\">html div</div>\n\nafter")
        XCTAssertTrue(waitFor("document.querySelectorAll('#content p').length >= 2"))
        XCTAssertTrue(waitFor("typeof window.__pwned === 'undefined'"), "injected script must not run")
        XCTAssertEqual(eval("document.title") as? String, "Markdown Preview")
        // Sanitized element renders without its event handler.
        XCTAssertTrue(waitFor("document.getElementById('probe') !== null"))
        XCTAssertTrue(waitFor("document.getElementById('probe').getAttribute('onclick') === null"))
    }

    func testHTMLHiddenByDefault() {
        source.replace("text\n\n<div id=\"rawhtml\">raw</div>")
        XCTAssertTrue(waitFor("document.querySelector('#content p') !== null"))
        XCTAssertTrue(waitFor("document.getElementById('rawhtml') === null"),
                      "raw HTML must not render unless enabled in Settings")
    }

    func testSearchCountsAndNavigates() {
        source.replace("alpha beta\n\nbeta gamma\n\nbeta beta")
        XCTAssertTrue(waitFor("document.querySelectorAll('#content p').length === 3"))
        _ = eval("preview.find()")
        _ = eval("""
        (() => {
          const input = document.querySelector('.search-input')
          input.value = 'beta'
          input.dispatchEvent(new Event('input'))
        })()
        """)
        XCTAssertTrue(waitFor("document.querySelectorAll('mark.zt-hit').length === 4"))
        XCTAssertTrue(waitFor("document.querySelector('.search-count')?.textContent === '1 of 4 matches'"))
        _ = eval("document.querySelector('.search-next').click()")
        XCTAssertTrue(waitFor("document.querySelector('.search-count')?.textContent === '2 of 4 matches'"))
    }

    func testLargeDocumentRendersFast() throws {
        let fixture = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Fixtures/large-5k.md")
        let text = try String(contentsOf: fixture, encoding: .utf8)
        let start = Date()
        source.replace(text)
        XCTAssertTrue(waitFor("document.querySelectorAll('#content h2').length >= 300", timeout: 5),
                      "5k-line document did not finish rendering")
        let elapsed = Date().timeIntervalSince(start)
        // Full parse+patch of 5,370 lines, including test-bridge overhead.
        // The spec's 500ms is viewport paint; this asserts the whole document
        // lands well inside interactive budgets.
        XCTAssertLessThan(elapsed, 3.0, "large document render too slow: \(elapsed)s")
    }

    func testSetOptionsAppliesReaderCustomization() {
        source.replace("# Opts\n\n```js\nlet x = 1\n```")
        XCTAssertTrue(waitFor("document.querySelector('#content .code-block') !== null"))
        _ = eval("preview.setOptions({fontSize: 20, readingWidth: 900, lineNumbers: false, wrapCode: true, showTOC: false, animations: false})")
        XCTAssertTrue(waitFor("getComputedStyle(document.body).fontSize === '20px'"))
        XCTAssertTrue(waitFor("getComputedStyle(document.getElementById('content')).maxWidth === '900px'"))
        XCTAssertTrue(waitFor("document.body.classList.contains('no-line-numbers')"))
        XCTAssertTrue(waitFor("document.body.classList.contains('wrap-code')"))
        XCTAssertTrue(waitFor("document.body.classList.contains('toc-collapsed')"))
        // Line-number gutter actually hidden.
        XCTAssertTrue(waitFor("getComputedStyle(document.querySelector('.cl'), '::before').display === 'none'"))
        // Reverting restores defaults.
        _ = eval("preview.setOptions({fontSize: 17, readingWidth: 740, lineNumbers: true, wrapCode: false, showTOC: true, animations: true})")
        XCTAssertTrue(waitFor("!document.body.classList.contains('no-line-numbers')"))
    }

    func testThemeSwitchWithoutReload() {
        source.replace("# Theme")
        XCTAssertTrue(waitFor("document.querySelector('#content h1') !== null"))
        model.setTheme("dark")
        XCTAssertTrue(waitFor("document.documentElement.dataset.theme === 'dark'"))
        model.setTheme("light")
        XCTAssertTrue(waitFor("document.documentElement.dataset.theme === 'light'"))
        // Content survived both switches (no reload).
        XCTAssertTrue(waitFor("document.querySelector('#content h1') !== null"))
    }

    func testExportHTMLIsSelfContained() {
        source.replace("# Export\n\nbody text")
        XCTAssertTrue(waitFor("document.querySelector('#content h1') !== null"))
        var html: String?
        let exp = expectation(description: "export")
        model.exportHTML { html = $0; exp.fulfill() }
        wait(for: [exp], timeout: 5)
        let out = html ?? ""
        XCTAssertTrue(out.contains("<!doctype html>"))
        XCTAssertTrue(out.contains("<style>"), "styles must be inlined")
        XCTAssertTrue(out.contains("Export"), "content missing from export")
        XCTAssertFalse(out.contains("@font-face"), "fonts are dropped from exports")
    }
}
