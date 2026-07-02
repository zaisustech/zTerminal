import Foundation
import WebKit
import UniformTypeIdentifiers

/// Serves `zt-asset://doc/<relative-path>` for local images referenced by the
/// previewed document. Containment is enforced here: only files under the
/// source's base directory are ever readable, no matter what the Markdown says.
final class PreviewSchemeHandler: NSObject, WKURLSchemeHandler {
    static let scheme = "zt-asset"

    /// Resolved lazily so the handler follows the pane's current source.
    var baseDirectory: () -> URL? = { nil }

    func webView(_ webView: WKWebView, start task: WKURLSchemeTask) {
        guard let fileURL = resolve(task.request.url) else {
            task.didFailWithError(CocoaError(.fileReadNoSuchFile))
            return
        }
        do {
            let data = try Data(contentsOf: fileURL)
            let mime = UTType(filenameExtension: fileURL.pathExtension)?.preferredMIMEType
                ?? "application/octet-stream"
            let response = URLResponse(url: task.request.url!, mimeType: mime,
                                       expectedContentLength: data.count, textEncodingName: nil)
            task.didReceive(response)
            task.didReceive(data)
            task.didFinish()
        } catch {
            task.didFailWithError(error)
        }
    }

    func webView(_ webView: WKWebView, stop task: WKURLSchemeTask) {}

    /// zt-asset://doc/a/b.png → <base>/a/b.png, rejecting anything that
    /// escapes the base directory (.., symlinks resolved via standardization).
    func resolve(_ url: URL?) -> URL? {
        guard let url, url.scheme == Self.scheme, let base = baseDirectory() else { return nil }
        let relative = url.path.removingPercentEncoding ?? url.path
        let candidate = base.appendingPathComponent(relative).standardizedFileURL
            .resolvingSymlinksInPath()
        let root = base.standardizedFileURL.resolvingSymlinksInPath()
        guard candidate.path == root.path || candidate.path.hasPrefix(root.path + "/") else { return nil }
        guard FileManager.default.fileExists(atPath: candidate.path) else { return nil }
        return candidate
    }
}
