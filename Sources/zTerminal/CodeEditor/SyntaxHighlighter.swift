import Foundation
import AppKit

/// A rule-based tokenizer + attributed-string builder. Not compiler-accurate —
/// "good enough to read": it finds comments, strings, numbers, and keywords and
/// colors them from a theme palette. Comments/strings are matched first so
/// keywords/numbers inside them aren't re-highlighted.
enum SyntaxHighlighter {

    enum TokenKind { case keyword, string, comment, number }

    struct Token: Equatable {
        let range: NSRange
        let kind: TokenKind
    }

    /// Files larger than this are shown as plain text (no highlighting) to stay responsive.
    static let highlightByteLimit = 2 * 1024 * 1024   // 2 MB

    /// Compute non-overlapping tokens for `source` in `language`, in document order.
    /// Priority when ranges would overlap: comment > string > number > keyword.
    static func tokens(source: String, language: CodeLanguage) -> [Token] {
        guard language != .plainText else { return [] }
        let ns = source as NSString
        let full = NSRange(location: 0, length: ns.length)
        var claimed = [Token]()

        func add(_ range: NSRange, _ kind: TokenKind) {
            // Skip if this range intersects an already-claimed (higher-priority) token.
            for t in claimed where NSIntersectionRange(t.range, range).length > 0 { return }
            claimed.append(Token(range: range, kind: kind))
        }
        func addMatches(_ pattern: String, _ kind: TokenKind, options: NSRegularExpression.Options = []) {
            guard let re = try? NSRegularExpression(pattern: pattern, options: options) else { return }
            for m in re.matches(in: source, options: [], range: full) where m.range.length > 0 {
                add(m.range, kind)
            }
        }

        // 1) Comments (highest priority).
        if language.hasBlockComments {
            addMatches("/\\*[\\s\\S]*?\\*/", .comment)
        }
        if let lc = language.lineComment {
            addMatches("\(NSRegularExpression.escapedPattern(for: lc)).*", .comment)
        }
        // 2) Strings — double, single, and (where common) backtick.
        addMatches("\"(?:[^\"\\\\\\n]|\\\\.)*\"", .string)
        addMatches("'(?:[^'\\\\\\n]|\\\\.)*'", .string)
        if language == .swift || language == .javascript || language == .typescript {
            addMatches("`(?:[^`\\\\]|\\\\.)*`", .string)
        }
        // 3) Numbers.
        addMatches("\\b\\d[\\d_]*(?:\\.\\d+)?(?:[eE][+-]?\\d+)?\\b", .number)
        // 4) Keywords (word-boundary), skipping any that fall inside a comment/string.
        let kws = language.keywords
        if !kws.isEmpty {
            let escaped = kws.map { NSRegularExpression.escapedPattern(for: $0) }.joined(separator: "|")
            addMatches("\\b(?:\(escaped))\\b", .keyword)
        }

        return claimed.sorted { $0.range.location < $1.range.location }
    }

    /// Build a colored attributed string for the code viewer. Falls back to plain
    /// (uncolored) text for `.plainText` or oversized input.
    static func attributedString(source: String, language: CodeLanguage,
                                 font: NSFont, palette: Palette) -> NSAttributedString {
        let base: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: palette.text]
        let result = NSMutableAttributedString(string: source, attributes: base)
        guard language != .plainText,
              source.utf8.count <= highlightByteLimit else { return result }
        for token in tokens(source: source, language: language) {
            result.addAttribute(.foregroundColor, value: palette.color(for: token.kind), range: token.range)
        }
        return result
    }

    /// Token colors, derived from the theme so light/dark/Blur stay legible.
    struct Palette {
        var text: NSColor
        var keyword: NSColor
        var string: NSColor
        var comment: NSColor
        var number: NSColor

        func color(for kind: TokenKind) -> NSColor {
            switch kind {
            case .keyword: return keyword
            case .string:  return string
            case .comment: return comment
            case .number:  return number
            }
        }

        /// A palette tuned for the dark terminal background.
        static let dark = Palette(
            text:    NSColor(calibratedWhite: 0.90, alpha: 1),
            keyword: NSColor(calibratedRed: 0.78, green: 0.55, blue: 0.98, alpha: 1),  // violet
            string:  NSColor(calibratedRed: 0.55, green: 0.86, blue: 0.55, alpha: 1),  // green
            comment: NSColor(calibratedWhite: 0.55, alpha: 1),                          // gray
            number:  NSColor(calibratedRed: 0.98, green: 0.72, blue: 0.42, alpha: 1))   // amber
    }
}
