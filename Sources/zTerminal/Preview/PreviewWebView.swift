import SwiftUI
import WebKit
import AppKit

/// The WKWebView hosting the bundled renderer. Loads preview.html from the
/// asset bundle, wires the `preview` message channel, serves local images via
/// zt-asset://, and keeps navigation locked to the bundle page (external links
/// go to the default browser instead).
struct PreviewWebView: NSViewRepresentable {
    @ObservedObject var model: PreviewPaneModel

    func makeCoordinator() -> Coordinator { Coordinator(model: model) }

    func makeNSView(context: Context) -> WKWebView {
        Self.makeConfiguredWebView(model: model, coordinator: context.coordinator)
    }

    /// Build the fully wired web view (scheme handler, message channel, page
    /// load). Shared with the renderer test harness, which drives the same
    /// stack offscreen.
    static func makeConfiguredWebView(model: PreviewPaneModel,
                                      coordinator: Coordinator) -> WKWebView {
        let config = WKWebViewConfiguration()
        let scheme = PreviewSchemeHandler()
        scheme.baseDirectory = { [weak model] in model?.source.baseDirectory }
        config.setURLSchemeHandler(scheme, forURLScheme: PreviewSchemeHandler.scheme)
        config.userContentController.add(coordinator, name: "preview")

        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 900, height: 700),
                                configuration: config)
        webView.navigationDelegate = coordinator
        webView.setValue(false, forKey: "drawsBackground")   // glass shows through
        webView.allowsMagnification = true
        model.rendererWillReload()
        model.webView = webView

        if let page = PreviewAssets.pageURL, let dir = PreviewAssets.directory {
            webView.loadFileURL(page, allowingReadAccessTo: dir)
        }
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.model = model
    }

    static func dismantleNSView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "preview")
    }

    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        var model: PreviewPaneModel

        init(model: PreviewPaneModel) { self.model = model }

        func userContentController(_ controller: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            guard message.name == "preview",
                  let body = message.body as? [String: Any],
                  let type = body["type"] as? String else { return }
            switch type {
            case "ready":
                model.rendererDidBecomeReady()
            case "openExternal":
                if let raw = body["url"] as? String, let url = URL(string: raw),
                   ["http", "https", "mailto"].contains(url.scheme?.lowercased() ?? "") {
                    NSWorkspace.shared.open(url)
                }
            case "openRelative":
                if let path = body["path"] as? String {
                    model.loadRelative(path: path)
                }
            case "error":
                NSLog("preview renderer error: %@", (body["message"] as? String) ?? "unknown")
            default:
                break
            }
        }

        /// Only the bundled page (and its subresources) may load; anything else
        /// is cancelled. Renderer link clicks never get here — JS intercepts
        /// them — so this is defense in depth.
        func webView(_ webView: WKWebView,
                     decidePolicyFor action: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            let url = action.request.url
            if url?.isFileURL == true || url?.scheme == PreviewSchemeHandler.scheme
                || url?.scheme == "about" {
                decisionHandler(.allow)
            } else {
                decisionHandler(.cancel)
            }
        }
    }
}
