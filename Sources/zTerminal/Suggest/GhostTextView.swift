import AppKit

/// A lightweight, click-through overlay that draws the inline autosuggestion as
/// dim text in the terminal's font. It occupies one cell's height starting at the
/// cursor cell; the host (`ZTerminalView`) sizes and positions it from the public
/// `caretFrame`. It never becomes first responder and passes all mouse events
/// through so selection/clicks in the terminal are unaffected.
final class GhostTextView: NSView {

    var text: String = "" {
        didSet { if text != oldValue { needsDisplay = true } }
    }

    var font: NSFont = .monospacedSystemFont(ofSize: 12, weight: .regular) {
        didSet { needsDisplay = true }
    }

    /// Dim foreground — a low-alpha white reads as "ghost" over dark terminals and
    /// stays subtle over light ones.
    var textColor: NSColor = NSColor(white: 1.0, alpha: 0.30) {
        didSet { needsDisplay = true }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    required init?(coder: NSCoder) { nil }

    // Never intercept mouse events — clicks fall through to the terminal.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override var isFlipped: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        guard !text.isEmpty else { return }
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor,
        ]
        let str = NSAttributedString(string: text, attributes: attrs)
        // Vertically center the glyphs within the cell height so they line up with
        // the terminal's own row text closely enough for a dim hint.
        let h = str.size().height
        let y = max(0, (bounds.height - h) / 2)
        str.draw(at: NSPoint(x: 0, y: y))
    }
}
