import Foundation

/// Locates the bundled preview renderer (preview.html/js/css + fonts).
///
/// Two build paths ship it differently: the Xcode app / bundle.sh place it at
/// Contents/Resources/Preview, while `swift run` / `swift test` have no app
/// bundle at all — there we fall back to the repo checkout relative to this
/// source file.
enum PreviewAssets {

    /// Directory containing preview.html, or nil if the bundle is missing
    /// (renderer not built — run scripts/build-preview-assets.sh).
    static var directory: URL? {
        let fm = FileManager.default
        if let res = Bundle.main.resourceURL {
            let bundled = res.appendingPathComponent("Preview", isDirectory: true)
            if fm.fileExists(atPath: bundled.appendingPathComponent("preview.html").path) {
                return bundled
            }
        }
        // Dev fallback: <repo>/Sources/zTerminal/Preview/PreviewAssets.swift → <repo>/Resources/Preview
        let dev = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // Preview/
            .deletingLastPathComponent()   // zTerminal/
            .deletingLastPathComponent()   // Sources/
            .deletingLastPathComponent()   // repo root
            .appendingPathComponent("Resources/Preview", isDirectory: true)
        if fm.fileExists(atPath: dev.appendingPathComponent("preview.html").path) {
            return dev
        }
        return nil
    }

    static var pageURL: URL? {
        directory?.appendingPathComponent("preview.html")
    }
}
