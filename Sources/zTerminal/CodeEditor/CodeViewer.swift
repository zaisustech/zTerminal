import SwiftUI
import AppKit

/// SwiftUI container for a read-only code viewer: a header (language, wrap toggle,
/// reload) over the text, with status handling (loading / large-file / error).
struct CodeViewerView: View {
    @ObservedObject var document: CodeDocument
    @EnvironmentObject var theme: ThemeManager
    /// Shown as a close button when the viewer is a split pane (nil = full tab).
    var onClose: (() -> Void)? = nil
    /// Cursor-style source↔preview toggle: set for Markdown documents; shows a
    /// "Preview" button that swaps this code view for the rendered preview.
    var onShowPreview: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.3)
            content
        }
        .background(Color(theme.terminalBackground))
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text(document.title).font(.system(size: 12, weight: .semibold)).lineLimit(1)
            Text(document.language.displayName)
                .font(.system(size: 10, weight: .medium))
                .padding(.horizontal, 6).padding(.vertical, 1)
                .background(Color.secondary.opacity(0.2), in: Capsule())
                .foregroundStyle(.secondary)
            Text("Read-only").font(.system(size: 10)).foregroundStyle(.secondary)
            Spacer()
            if let onShowPreview {
                Button(action: onShowPreview) {
                    Label("Preview", systemImage: "doc.richtext")
                        .font(.system(size: 10, weight: .semibold))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 8).padding(.vertical, 2)
                .background(Color.accentColor.opacity(0.18), in: Capsule())
                .foregroundStyle(Color.accentColor)
                .help("Show rendered Markdown")
            }
            Button { document.wrap.toggle() } label: {
                Image(systemName: document.wrap ? "text.aligncenter" : "text.alignleft")
            }
            .buttonStyle(.plain).foregroundStyle(document.wrap ? Color.accentColor : .secondary)
            .help("Toggle soft wrap")
            Button { document.reload() } label: { Image(systemName: "arrow.clockwise") }
                .buttonStyle(.plain).foregroundStyle(.secondary).help("Reload from disk")
            if let onClose {
                Button(action: onClose) { Image(systemName: "xmark") }
                    .buttonStyle(.plain).foregroundStyle(.secondary).help("Close")
            }
        }
        .font(.system(size: 12))
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(.ultraThinMaterial)
    }

    @ViewBuilder private var content: some View {
        switch document.status {
        case .loading:
            Spacer(); ProgressView().controlSize(.small); Spacer()
        case .failed(let message):
            Spacer()
            Text(message).font(.system(size: 12)).foregroundStyle(.secondary).padding()
            Spacer()
        case .ready, .plainLarge:
            VStack(spacing: 0) {
                if document.status == .plainLarge {
                    Text("Large file — syntax highlighting disabled.")
                        .font(.system(size: 11)).foregroundStyle(.orange)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Color.orange.opacity(0.12))
                }
                CodeTextView(text: document.text,
                             language: document.language,
                             wrap: document.wrap,
                             font: theme.terminalFont,
                             palette: .dark)
            }
        }
    }
}

/// `NSTextView` wrapper: read-only, selectable, syntax-highlighted, with a
/// line-number ruler and optional soft-wrap. TextKit handles large docs, selection,
/// and the built-in find bar (⌘F via `performTextFinderAction`).
struct CodeTextView: NSViewRepresentable {
    let text: String
    let language: CodeLanguage
    let wrap: Bool
    let font: NSFont
    let palette: SyntaxHighlighter.Palette

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSTextView.scrollableTextView()
        guard let textView = scroll.documentView as? NSTextView else { return scroll }

        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = false
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true
        textView.drawsBackground = false
        textView.backgroundColor = NSColor.clear
        textView.textContainerInset = NSSize(width: 6, height: 8)
        textView.autoresizingMask = [.width]
        context.coordinator.textView = textView

        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = true
        scroll.drawsBackground = false

        // Line-number gutter.
        let ruler = LineNumberRulerView(textView: textView)
        scroll.verticalRulerView = ruler
        scroll.hasVerticalRuler = true
        scroll.rulersVisible = true

        // ⌘F (routed from the app menu) → show this text view's built-in find bar.
        context.coordinator.findObserver = NotificationCenter.default.addObserver(
            forName: .codeFind, object: nil, queue: .main) { [weak textView] _ in
            guard let textView, textView.window?.isKeyWindow == true else { return }
            let item = NSMenuItem()
            item.tag = Int(NSTextFinder.Action.showFindInterface.rawValue)
            textView.performTextFinderAction(item)
        }

        apply(to: textView, scroll: scroll)
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let textView = scroll.documentView as? NSTextView else { return }
        apply(to: textView, scroll: scroll)
    }

    private func apply(to textView: NSTextView, scroll: NSScrollView) {
        // Wrap vs. no-wrap: toggle the container's width tracking.
        if let container = textView.textContainer {
            let big = CGFloat.greatestFiniteMagnitude
            if wrap {
                container.widthTracksTextView = true
                container.size = NSSize(width: scroll.contentSize.width, height: big)
                textView.isHorizontallyResizable = false
            } else {
                container.widthTracksTextView = false
                container.size = NSSize(width: big, height: big)
                textView.isHorizontallyResizable = true
                textView.maxSize = NSSize(width: big, height: big)
            }
        }
        let attributed = SyntaxHighlighter.attributedString(
            source: text, language: language, font: font, palette: palette)
        textView.textStorage?.setAttributedString(attributed)
        (scroll.verticalRulerView as? LineNumberRulerView)?.needsDisplay = true
    }

    func makeCoordinator() -> Coordinator { Coordinator() }
    final class Coordinator {
        weak var textView: NSTextView?
        var findObserver: NSObjectProtocol?
        deinit { if let o = findObserver { NotificationCenter.default.removeObserver(o) } }
    }
}

/// Draws 1-based line numbers in the scroll view's left gutter, tracking the text
/// view's layout + scroll position.
final class LineNumberRulerView: NSRulerView {
    weak var textView: NSTextView?

    init(textView: NSTextView) {
        self.textView = textView
        super.init(scrollView: textView.enclosingScrollView, orientation: .verticalRuler)
        clientView = textView
        ruleThickness = 44
        NotificationCenter.default.addObserver(self, selector: #selector(redraw),
                                               name: NSText.didChangeNotification, object: textView)
    }
    required init(coder: NSCoder) { fatalError() }

    @objc private func redraw() { needsDisplay = true }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let textView, let layoutManager = textView.layoutManager,
              let container = textView.textContainer else { return }
        let content = textView.string as NSString
        let visibleRect = textView.visibleRect
        let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: container)
        let charRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
        let inset = textView.textContainerInset.height

        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular),
            .foregroundColor: NSColor.secondaryLabelColor,
        ]

        // Line number of the first visible char.
        var lineNumber = 1 + content.substring(to: charRange.location)
            .reduce(0) { $0 + ($1 == "\n" ? 1 : 0) }

        var index = charRange.location
        while index < NSMaxRange(charRange) {
            let lineRange = content.lineRange(for: NSRange(location: index, length: 0))
            let lineGlyphRange = layoutManager.glyphRange(forCharacterRange: lineRange, actualCharacterRange: nil)
            var rectForLine = layoutManager.boundingRect(forGlyphRange:
                NSRange(location: lineGlyphRange.location, length: 0), in: container)
            let y = rectForLine.minY + inset - textView.visibleRect.minY
            let label = "\(lineNumber)" as NSString
            let size = label.size(withAttributes: attrs)
            label.draw(at: NSPoint(x: ruleThickness - size.width - 6, y: y + 1), withAttributes: attrs)
            lineNumber += 1
            index = NSMaxRange(lineRange)
            _ = rectForLine
        }
    }
}
