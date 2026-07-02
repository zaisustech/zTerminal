import AppKit
import WebKit
import UniformTypeIdentifiers

/// Export of the rendered document: self-contained HTML, paginated PDF,
/// Markdown source, and the standard print dialog.
enum PreviewExport {

    static func exportHTML(model: PreviewPaneModel, from window: NSWindow?) {
        model.exportHTML { html in
            guard var html else { return fail("The document could not be serialized.") }
            // Inline local images so the file is self-contained offline: Swift
            // holds the file access the sandboxed page doesn't.
            html = inlineAssetImages(in: html, base: model.source.baseDirectory)
            savePanel(title: model.title, type: .html, in: window) { url in
                write(html.data(using: .utf8), to: url)
            }
        }
    }

    static func exportPDF(model: PreviewPaneModel, from window: NSWindow?) {
        guard let webView = model.webView else { return fail("The preview is not ready yet.") }
        // Expand content-visibility-skipped blocks so long documents aren't
        // blank below the fold (createPDF renders with screen media).
        webView.evaluateJavaScript("document.body.classList.add('export')") { _, _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                webView.createPDF(configuration: WKPDFConfiguration()) { result in
                    webView.evaluateJavaScript("document.body.classList.remove('export')", completionHandler: nil)
                    switch result {
                    case .success(let data):
                        savePanel(title: model.title, type: .pdf, in: window) { url in
                            write(data, to: url)
                        }
                    case .failure(let error):
                        fail("PDF rendering failed: \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    static func exportMarkdown(model: PreviewPaneModel, from window: NSWindow?) {
        let text = model.source.currentText
        savePanel(title: model.title, type: UTType(filenameExtension: "md") ?? .plainText,
                  in: window) { url in
            write(text.data(using: .utf8), to: url)
        }
    }

    static func printDocument(model: PreviewPaneModel) {
        guard let webView = model.webView else { return }
        let info = NSPrintInfo.shared
        info.topMargin = 24; info.bottomMargin = 24
        info.leftMargin = 24; info.rightMargin = 24
        info.horizontalPagination = .fit
        let op = webView.printOperation(with: info)
        op.showsPrintPanel = true
        op.showsProgressPanel = true
        // The web view must have a window-attached frame for printing.
        op.view?.frame = webView.bounds
        if let window = webView.window {
            op.runModal(for: window, delegate: nil, didRun: nil, contextInfo: nil)
        } else {
            op.run()
        }
    }

    // MARK: Helpers

    private static func savePanel(title: String, type: UTType, in window: NSWindow?,
                                  write: @escaping (URL) -> Void) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [type]
        panel.nameFieldStringValue = (title as NSString).deletingPathExtension
        panel.level = .modalPanel
        let handler: (NSApplication.ModalResponse) -> Void = { response in
            guard response == .OK, let url = panel.url else { return }
            write(url)
        }
        if let window { panel.beginSheetModal(for: window, completionHandler: handler) }
        else { handler(panel.runModal()) }
    }

    /// Failures surface as an alert instead of silently doing nothing.
    private static func fail(_ message: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Export Failed"
            alert.informativeText = message
            alert.runModal()
        }
    }

    private static func write(_ data: Data?, to url: URL) {
        do { try (data ?? Data()).write(to: url) }
        catch { fail("Could not save the file: \(error.localizedDescription)") }
    }

    /// Replace zt-asset://doc/<path> image sources with base64 data URIs.
    static func inlineAssetImages(in html: String, base: URL?) -> String {
        guard let base else { return html }
        let pattern = #"src="zt-asset://doc/([^"]+)""#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return html }
        let ns = html as NSString
        var result = html
        for match in regex.matches(in: html, range: NSRange(location: 0, length: ns.length)).reversed() {
            let rel = ns.substring(with: match.range(at: 1)).removingPercentEncoding
                ?? ns.substring(with: match.range(at: 1))
            let fileURL = base.appendingPathComponent(rel).standardizedFileURL
            guard fileURL.path.hasPrefix(base.standardizedFileURL.path),
                  let data = try? Data(contentsOf: fileURL) else { continue }
            let mime = UTType(filenameExtension: fileURL.pathExtension)?.preferredMIMEType ?? "image/png"
            let replacement = "src=\"data:\(mime);base64,\(data.base64EncodedString())\""
            if let range = Range(match.range, in: result) {
                result.replaceSubrange(range, with: replacement)
            }
        }
        return result
    }
}
