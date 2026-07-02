import AppKit
import SwiftTerm

/// A resolved match ready for drawing: its absolute buffer-line index (same space
/// as `getTopVisibleRow()`), the grid-column range, and which keyword produced it.
struct OverlayMatch {
    let bufferIndex: Int
    let colStart: Int
    let colEnd: Int
    let keyword: Int
    let isActive: Bool
}

/// Shared visual constants for search overlays.
enum SearchPalette {
    /// Per-keyword highlight colors (cycled for >count keywords). Chosen to read on
    /// dark terminal backgrounds; the active match is drawn brighter with a border.
    static let keywordColors: [NSColor] = [
        NSColor(calibratedRed: 0.98, green: 0.82, blue: 0.25, alpha: 1),  // amber
        NSColor(calibratedRed: 0.35, green: 0.78, blue: 0.98, alpha: 1),  // cyan
        NSColor(calibratedRed: 0.55, green: 0.90, blue: 0.45, alpha: 1),  // green
        NSColor(calibratedRed: 0.98, green: 0.55, blue: 0.85, alpha: 1),  // pink
        NSColor(calibratedRed: 0.75, green: 0.65, blue: 0.98, alpha: 1),  // violet
        NSColor(calibratedRed: 0.98, green: 0.62, blue: 0.35, alpha: 1),  // orange
    ]

    static func color(forKeyword k: Int) -> NSColor {
        keywordColors[((k % keywordColors.count) + keywordColors.count) % keywordColors.count]
    }
}

/// A non-interactive layer drawn over the terminal that fills a translucent rect
/// behind every visible match, with the active match emphasized. It reads the live
/// scroll position and cell size on each draw so it stays aligned as the buffer
/// scrolls, resizes, or the font changes.
final class SearchHighlightOverlay: NSView {
    weak var term: ZTerminalView?
    var matches: [OverlayMatch] = [] { didSet { needsDisplay = true } }

    override var isFlipped: Bool { false }               // AppKit default: origin bottom-left
    override func hitTest(_ point: NSPoint) -> NSView? { nil }   // clicks pass through
    override var acceptsFirstResponder: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        guard let term else { return }
        let t = term.getTerminal()
        let cell = term.cellSize
        guard cell.width > 0, cell.height > 0 else { return }
        let top = t.getTopVisibleRow()
        let rows = t.rows
        let h = bounds.height

        for m in matches {
            let visibleRow = m.bufferIndex - top
            guard visibleRow >= 0, visibleRow < rows else { continue }   // off-screen
            let x = CGFloat(m.colStart) * cell.width
            let width = CGFloat(max(1, m.colEnd - m.colStart)) * cell.width
            let y = h - CGFloat(visibleRow + 1) * cell.height
            let rect = NSRect(x: x, y: y, width: width, height: cell.height)
            let base = SearchPalette.color(forKeyword: m.keyword)
            if m.isActive {
                base.withAlphaComponent(0.55).setFill()
                rect.fill()
                base.withAlphaComponent(0.95).setStroke()
                let border = NSBezierPath(rect: rect.insetBy(dx: 0.5, dy: 0.5))
                border.lineWidth = 1.5
                border.stroke()
            } else {
                base.withAlphaComponent(0.30).setFill()
                rect.fill()
            }
        }
    }
}

/// A thin interactive gutter along the right edge showing one marker per matching
/// row, positioned proportionally over the whole buffer (oldest at top). Clicking
/// jumps to the nearest match at that position.
final class SearchMinimapView: NSView {
    weak var term: ZTerminalView?
    var matches: [OverlayMatch] = [] { didSet { needsDisplay = true } }
    /// Called with the buffer index the user clicked near.
    var onJump: ((Int) -> Void)?

    static let width: CGFloat = 8

    override var isFlipped: Bool { false }

    private var totalLines: Int { max(1, term?.getTerminal().bufferLineCount ?? 1) }

    override func draw(_ dirtyRect: NSRect) {
        // Faint track so the gutter is discoverable even with few matches.
        NSColor.white.withAlphaComponent(0.06).setFill()
        bounds.fill()

        let total = CGFloat(totalLines)
        let h = bounds.height
        for m in matches {
            let frac = CGFloat(m.bufferIndex) / total           // 0 = oldest (top)
            let y = h - frac * h                                 // origin bottom-left
            let color = SearchPalette.color(forKeyword: m.keyword)
            if m.isActive {
                color.withAlphaComponent(0.95).setFill()
                NSRect(x: 0, y: max(0, y - 2), width: bounds.width, height: 4).fill()
            } else {
                color.withAlphaComponent(0.6).setFill()
                NSRect(x: 1, y: max(0, y - 1), width: bounds.width - 2, height: 2).fill()
            }
        }
    }

    override func mouseDown(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        let frac = 1 - (p.y / max(1, bounds.height))            // 0 = oldest (top)
        let index = Int((frac * CGFloat(totalLines)).rounded())
        onJump?(max(0, min(totalLines - 1, index)))
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }
}
