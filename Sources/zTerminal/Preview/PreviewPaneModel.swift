import Foundation
import WebKit
import SwiftUI

/// Drives one preview surface: owns the content source, gates pushes on the
/// renderer's ready signal, and wraps the `window.preview` JS API. The WKWebView
/// itself is created by `PreviewWebView` and attached here.
final class PreviewPaneModel: NSObject, ObservableObject, Identifiable {
    let id = UUID()

    @Published private(set) var title: String
    @Published private(set) var source: PreviewSource

    /// Raw-HTML rendering (sanitized) — Settings-controlled, default off.
    @AppStorage("previewAllowHTML") private var allowHTML = false

    weak var webView: WKWebView?
    private var isReady = false
    private var lastPushedTheme: String?

    init(source: PreviewSource) {
        self.title = source.title
        self.source = source
        super.init()
        source.onEvent = { [weak self] event in self?.push(event) }
    }

    /// Swap in a new source (relative-link navigation, re-open).
    func load(source newSource: PreviewSource) {
        source.stop()
        source = newSource
        title = newSource.title
        newSource.onEvent = { [weak self] event in self?.push(event) }
        if isReady { newSource.start() }
    }

    /// Open a document-relative Markdown link.
    func loadRelative(path: String) {
        guard let base = source.baseDirectory else { return }
        let clean = path.removingPercentEncoding ?? path
        let target = base.appendingPathComponent(String(clean.split(separator: "#").first ?? ""))
            .standardizedFileURL
        guard FileManager.default.fileExists(atPath: target.path) else { return }
        load(source: FilePreviewSource(url: target))
    }

    // MARK: JS bridge

    /// A fresh web view is about to load the renderer page (first mount, or a
    /// rebuild after LRU hibernation) — gate pushes until its ready signal.
    func rendererWillReload() {
        isReady = false
    }

    /// Called by the web view coordinator when the renderer signals ready.
    func rendererDidBecomeReady() {
        isReady = true
        applySettings()
        if let theme = lastPushedTheme { call("preview.setTheme", jsonArg(theme)) }
        source.start()
    }

    /// Push every Settings → Markdown option (called on ready and whenever
    /// Settings posts .previewSettingsChanged).
    func applySettings() {
        guard isReady else { return }
        call("preview.setHTMLEnabled", jsonArg(allowHTML))
        let d = UserDefaults.standard
        let options: [String: Any] = [
            "fontSize": d.object(forKey: "previewFontSize") as? Double ?? 17,
            "readingWidth": d.object(forKey: "previewWidth") as? Double ?? 740,
            "lineNumbers": d.object(forKey: "previewLineNumbers") as? Bool ?? true,
            "wrapCode": d.object(forKey: "previewWrapCode") as? Bool ?? false,
            "showTOC": d.object(forKey: "previewShowTOC") as? Bool ?? true,
            "animations": d.object(forKey: "previewAnimations") as? Bool ?? true,
        ]
        call("preview.setOptions", jsonArg(options))
    }

    private func push(_ event: PreviewSourceEvent) {
        guard isReady else { return }
        switch event {
        case .replace(let text): call("preview.setContent", jsonArg(text))
        case .append(let chunk): call("preview.append", jsonArg(chunk))
        }
    }

    /// 'light' | 'dark' — auto is resolved by the caller (SwiftUI environment).
    func setTheme(_ theme: String) {
        lastPushedTheme = theme
        guard isReady else { return }
        call("preview.setTheme", jsonArg(theme))
    }


    /// Open the in-page ⌘F search overlay.
    func find() {
        call("preview.find", "")
    }

    /// True when this pane's web view (or a descendant) is the key window's
    /// first responder — the ⌘F routing test.
    var isFocused: Bool {
        guard let webView,
              let responder = webView.window?.firstResponder as? NSView else { return false }
        return responder === webView || responder.isDescendant(of: webView)
    }

    /// Ask the renderer for a self-contained HTML document.
    func exportHTML(completion: @escaping (String?) -> Void) {
        webView?.callAsyncJavaScript(
            "return await preview.exportHTML(title)",
            arguments: ["title": title],
            in: nil, in: .page
        ) { result in
            if case .success(let value) = result { completion(value as? String) }
            else { completion(nil) }
        }
    }

    private func call(_ fn: String, _ args: String) {
        webView?.evaluateJavaScript("\(fn)(\(args))", completionHandler: nil)
    }

    private func jsonArg(_ value: Any) -> String {
        let data = (try? JSONSerialization.data(withJSONObject: value, options: [.fragmentsAllowed])) ?? Data()
        return String(data: data, encoding: .utf8) ?? "null"
    }

    deinit { source.stop() }
}
