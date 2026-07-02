import Foundation

/// Pure, terminal-independent search core: given the plain text of the buffer's
/// logical lines plus a query, it computes every match, tags each with the
/// keyword that produced it (for multi-keyword coloring), keeps them ordered in
/// buffer order, and tracks an active match with wrap-around navigation.
///
/// This type deliberately has **no SwiftTerm dependency** so it is unit-testable
/// with fixture strings. The view layer feeds it extracted line text (see the
/// buffer-extraction adapter) and maps `Match` ranges back to grid cells for the
/// highlight overlay and minimap.
struct TerminalSearch {

    /// Search options, mirroring SwiftTerm's `SearchOptions` semantics so the app
    /// behaves the same where they overlap.
    struct Options: Equatable {
        var caseSensitive: Bool = false
        var regex: Bool = false
        var wholeWord: Bool = false
    }

    /// One match: which logical line, the half-open column range within that
    /// line's text (Character offsets), and the index of the keyword that matched
    /// (0 for a single-term or regex query; assigned per space-separated term in
    /// multi-keyword mode) so the UI can color each keyword distinctly.
    struct Match: Equatable {
        let line: Int
        let range: Range<Int>
        let keyword: Int
    }

    /// Non-word characters used for whole-word boundary tests — same set SwiftTerm
    /// uses so `Word` matches identically.
    private static let nonWord: Set<Character> = Set(" ~!@#$%^&*()+`-=[]{}|\\;:\"',./<>?\t")

    // MARK: State

    /// All matches, ordered by (line, start column, keyword).
    private(set) var matches: [Match] = []

    /// Index into `matches` of the active/current match, or nil when there are none.
    private(set) var activeIndex: Int?

    /// False when the query is a regex that failed to compile. Callers surface this
    /// as an invalid/zero-match state without disturbing the view.
    private(set) var isValid: Bool = true

    /// Number of distinct keywords the last query produced (>=1), for palette sizing.
    private(set) var keywordCount: Int = 0

    // MARK: Derived

    var isEmpty: Bool { matches.isEmpty }
    var total: Int { matches.count }

    /// 1-based position of the active match, or 0 when there is none. Pairs with
    /// `total` for the `Current: n / total` counter.
    var currentPosition: Int {
        guard let i = activeIndex else { return 0 }
        return i + 1
    }

    var activeMatch: Match? {
        guard let i = activeIndex, matches.indices.contains(i) else { return nil }
        return matches[i]
    }

    // MARK: Recompute

    /// Recompute all matches for `query` over `lines`. Preserves the active match
    /// across recomputes when it still exists (so live output doesn't jump the
    /// selection); otherwise clamps the active index into range.
    ///
    /// - Parameter preferActiveNear: when the previously active match is gone,
    ///   pick the first match at or after this (line, col) if provided.
    mutating func recompute(query: String, options: Options, lines: [String],
                            preferActiveNear: (line: Int, col: Int)? = nil) {
        let previousActive = activeMatch
        let (newMatches, valid, keywords) = Self.computeMatches(query: query, options: options, lines: lines)
        matches = newMatches
        isValid = valid
        keywordCount = keywords

        guard !matches.isEmpty else { activeIndex = nil; return }

        // Keep the same match active if it survived the recompute.
        if let prev = previousActive, let idx = matches.firstIndex(of: prev) {
            activeIndex = idx
            return
        }
        // Otherwise anchor near a requested position (e.g. viewport top / a click).
        if let near = preferActiveNear,
           let idx = matches.firstIndex(where: { $0.line > near.line || ($0.line == near.line && $0.range.lowerBound >= near.col) }) {
            activeIndex = idx
            return
        }
        // Fall back to clamping the old index into the new range.
        if let old = activeIndex {
            activeIndex = min(max(0, old), matches.count - 1)
        } else {
            activeIndex = 0
        }
    }

    /// Clear all state (Esc / empty query).
    mutating func clear() {
        matches = []
        activeIndex = nil
        isValid = true
        keywordCount = 0
    }

    // MARK: Navigation

    /// Advance to the next match, wrapping past the end. No-op with no matches.
    mutating func next() {
        guard !matches.isEmpty else { return }
        let i = activeIndex ?? -1
        activeIndex = (i + 1) % matches.count
    }

    /// Step to the previous match, wrapping past the start. No-op with no matches.
    mutating func previous() {
        guard !matches.isEmpty else { return }
        let i = activeIndex ?? 0
        activeIndex = (i - 1 + matches.count) % matches.count
    }

    /// Make the match nearest to (line, col) active — used when a minimap marker is
    /// clicked. Chooses the closest match by absolute line distance, then column.
    mutating func activateNearest(line: Int, col: Int) {
        guard !matches.isEmpty else { return }
        var bestIdx = 0
        var bestCost = Int.max
        for (idx, m) in matches.enumerated() {
            let cost = abs(m.line - line) * 100_000 + abs(m.range.lowerBound - col)
            if cost < bestCost { bestCost = cost; bestIdx = idx }
        }
        activeIndex = bestIdx
    }

    // MARK: Matching

    /// Compute matches, validity, and keyword count for a query over the lines.
    private static func computeMatches(query: String, options: Options, lines: [String])
        -> (matches: [Match], valid: Bool, keywords: Int) {

        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return ([], true, 0) }

        // Multi-keyword only when regex is off; a regex query is one pattern and
        // its spaces are literal.
        let terms: [String] = options.regex
            ? [query]
            : query.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        guard !terms.isEmpty else { return ([], true, 0) }

        // Precompile regexes once per term; a single failed compile invalidates.
        var regexes: [NSRegularExpression?] = []
        if options.regex {
            let opts: NSRegularExpression.Options = options.caseSensitive ? [] : [.caseInsensitive]
            for term in terms {
                guard let re = try? NSRegularExpression(pattern: term, options: opts) else {
                    return ([], false, terms.count)
                }
                regexes.append(re)
            }
        }

        var result: [Match] = []
        for (lineIdx, line) in lines.enumerated() {
            let chars = Array(line)
            for (kw, term) in terms.enumerated() {
                let ranges: [Range<Int>] = options.regex
                    ? regexMatches(regex: regexes[kw]!, line: line, chars: chars)
                    : substringMatches(term: term, chars: chars, caseSensitive: options.caseSensitive)
                for r in ranges {
                    if options.wholeWord && !isWholeWord(range: r, chars: chars) { continue }
                    result.append(Match(line: lineIdx, range: r, keyword: kw))
                }
            }
        }

        // Union in buffer order: by line, then start column, then keyword.
        result.sort {
            if $0.line != $1.line { return $0.line < $1.line }
            if $0.range.lowerBound != $1.range.lowerBound { return $0.range.lowerBound < $1.range.lowerBound }
            return $0.keyword < $1.keyword
        }
        return (result, true, terms.count)
    }

    /// All non-overlapping substring occurrences of `term` in `chars`, as
    /// Character-offset ranges.
    private static func substringMatches(term: String, chars: [Character], caseSensitive: Bool) -> [Range<Int>] {
        let needle = Array(term)
        guard !needle.isEmpty, needle.count <= chars.count else { return [] }
        func eq(_ a: Character, _ b: Character) -> Bool {
            caseSensitive ? a == b : (String(a).lowercased() == String(b).lowercased())
        }
        var ranges: [Range<Int>] = []
        var i = 0
        let last = chars.count - needle.count
        while i <= last {
            var j = 0
            while j < needle.count && eq(chars[i + j], needle[j]) { j += 1 }
            if j == needle.count {
                ranges.append(i ..< (i + needle.count))
                i += needle.count            // non-overlapping
            } else {
                i += 1
            }
        }
        return ranges
    }

    /// Regex matches over a line, returned as Character-offset ranges (converting
    /// from NSRange/UTF-16). Zero-length matches are skipped.
    private static func regexMatches(regex: NSRegularExpression, line: String, chars: [Character]) -> [Range<Int>] {
        let ns = line as NSString
        let full = NSRange(location: 0, length: ns.length)
        var ranges: [Range<Int>] = []
        for m in regex.matches(in: line, options: [], range: full) where m.range.length > 0 {
            guard let swiftRange = Range(m.range, in: line) else { continue }
            let start = line.distance(from: line.startIndex, to: swiftRange.lowerBound)
            let end = line.distance(from: line.startIndex, to: swiftRange.upperBound)
            if start >= 0 && end <= chars.count && start < end {
                ranges.append(start ..< end)
            }
        }
        return ranges
    }

    /// A range is a whole word when the characters immediately before and after it
    /// are non-word characters (or the line edge).
    private static func isWholeWord(range: Range<Int>, chars: [Character]) -> Bool {
        let before = range.lowerBound - 1
        let after = range.upperBound
        let leftOK = before < 0 || nonWord.contains(chars[before])
        let rightOK = after >= chars.count || nonWord.contains(chars[after])
        return leftOK && rightOK
    }
}
