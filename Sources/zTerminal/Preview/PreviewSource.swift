import Foundation

/// How a source's content changed. Appends are forwarded as cheap deltas so
/// token streaming doesn't re-send the whole document over the JS bridge.
enum PreviewSourceEvent {
    case replace(String)
    case append(String)
}

/// Where the previewed Markdown comes from: a file on disk (live-reloading) or
/// an appendable in-memory stream (AI token output). Deliberately WebKit-free
/// so it is unit-testable.
protocol PreviewSource: AnyObject {
    var title: String { get }
    /// Directory local images and relative links resolve against.
    var baseDirectory: URL? { get }
    var currentText: String { get }
    var onEvent: ((PreviewSourceEvent) -> Void)? { get set }
    func start()
    func stop()
}

/// A Markdown file on disk. Watches the file with a vnode dispatch source and
/// replaces content on every change; atomic "save = write temp + rename" is
/// handled by re-opening the descriptor after rename/delete events.
final class FilePreviewSource: PreviewSource {
    let url: URL
    var onEvent: ((PreviewSourceEvent) -> Void)?
    private(set) var currentText: String = ""
    private var watcher: DispatchSourceFileSystemObject?
    private var fd: CInt = -1

    init(url: URL) {
        self.url = url.standardizedFileURL
    }

    var title: String { url.lastPathComponent }
    var baseDirectory: URL? { url.deletingLastPathComponent() }

    func start() {
        reload()
        watch()
    }

    func stop() {
        watcher?.cancel()
        watcher = nil
    }

    private func reload() {
        let text = (try? String(contentsOf: url, encoding: .utf8)) ?? currentText
        currentText = text
        onEvent?(.replace(text))
    }

    private func watch() {
        watcher?.cancel()
        fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend, .delete, .rename],
            queue: .main
        )
        source.setEventHandler { [weak self] in
            guard let self else { return }
            let events = source.data
            self.reload()
            if events.contains(.delete) || events.contains(.rename) {
                // Atomic save replaced the inode — re-arm on the new file.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                    self?.watch()
                    self?.reload()
                }
            }
        }
        source.setCancelHandler { [fd = self.fd] in if fd >= 0 { close(fd) } }
        source.resume()
        watcher = source
    }

    deinit { stop() }
}

/// An appendable in-memory buffer — the integration point for AI/token
/// streaming. `append` forwards a delta; `replace` resets the document.
final class StreamPreviewSource: PreviewSource {
    let title: String
    let baseDirectory: URL?
    var onEvent: ((PreviewSourceEvent) -> Void)?
    private(set) var currentText: String = ""

    init(title: String = "Live Preview", baseDirectory: URL? = nil) {
        self.title = title
        self.baseDirectory = baseDirectory
    }

    func start() {
        onEvent?(.replace(currentText))
    }

    func stop() {}

    func append(_ chunk: String) {
        currentText += chunk
        onEvent?(.append(chunk))
    }

    func replace(_ text: String) {
        currentText = text
        onEvent?(.replace(text))
    }
}
