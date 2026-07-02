import SwiftUI
import AppKit

/// The leading sidebar column: the file tree plus a draggable resize handle on its
/// trailing edge. Kept separate so `RootView`'s body stays simple.
struct FileExplorerColumn: View {
    @ObservedObject var tree: FileTreeModel
    @Binding var width: Double

    /// Extensions we send to the system default app instead of the code viewer.
    private static let binaryExts: Set<String> = [
        "png","jpg","jpeg","gif","bmp","tiff","webp","heic","icns","ico",
        "pdf","zip","gz","tar","dmg","app","mp3","mp4","mov","wav","aiff",
        "ttf","otf","woff","woff2","o","a","dylib","so","bin","exe","class",
        "sqlite","db","xcodeproj","key","numbers","pages",
    ]
    static func isBinary(_ url: URL) -> Bool {
        binaryExts.contains(url.pathExtension.lowercased())
    }

    private let minWidth: Double = 160
    private let maxWidth: Double = 460

    var body: some View {
        HStack(spacing: 0) {
            FileExplorerSidebar(
                tree: tree,
                onOpenFile: { url in
                    // Markdown opens RENDERED first (Cursor-style; the Code
                    // button in the preview header shows the source); other
                    // text/code files open in a split code viewer beside the
                    // terminal; binaries fall back to the system default app.
                    if ["md", "markdown"].contains(url.pathExtension.lowercased()) {
                        WindowRouter.shared.openMarkdownPreview(url, split: true)
                    } else if FileExplorerColumn.isBinary(url) {
                        NSWorkspace.shared.open(url)
                    } else {
                        WindowRouter.shared.openCode(url, split: true)
                    }
                },
                onOpenFolderInTab: { url in WindowRouter.shared.openInNewTab(url.path) }
            )
            // Leading-align + clip so long file names truncate on the right rather
            // than centering and spilling off the left edge of the window.
            .frame(width: width, alignment: .leading)
            .clipped()

            // Drag-to-resize handle.
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(width: 4)
                .contentShape(Rectangle())
                .onHover { inside in
                    if inside { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() }
                }
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            width = min(maxWidth, max(minWidth, width + value.translation.width))
                        }
                )
        }
    }
}

/// Invisible observer that keeps the file tree rooted at the active tab's working
/// directory: re-roots on appear (also when the active tab changes, since it's
/// keyed by the session id) and whenever the shell's CWD changes.
struct SidebarRootUpdater: View {
    @ObservedObject var session: SessionModel
    let tree: FileTreeModel

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .allowsHitTesting(false)
            .onAppear { tree.setRoot(path: session.cwd); RecentDirectories.shared.record(session.cwd) }
            .onChange(of: session.cwd) { tree.setRoot(path: $0); RecentDirectories.shared.record($0) }
    }
}
