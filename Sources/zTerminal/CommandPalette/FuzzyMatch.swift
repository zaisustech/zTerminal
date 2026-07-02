import Foundation

/// Subsequence fuzzy matching + scoring for the command palette. Pure and
/// unit-testable. Higher score = better match; nil = the query isn't a
/// subsequence of the candidate.
enum FuzzyMatch {

    /// Score `candidate` against `query` (case-insensitive). Rewards contiguous
    /// runs, matches at word starts, and matches near the beginning. Returns nil
    /// when `query` is not a subsequence of `candidate`. An empty query scores 0
    /// (everything matches equally).
    static func score(query: String, candidate: String) -> Int? {
        let q = Array(query.lowercased())
        guard !q.isEmpty else { return 0 }
        let c = Array(candidate.lowercased())
        guard q.count <= c.count else { return nil }

        let boundaries: Set<Character> = ["/", "_", "-", ".", " "]
        var score = 0
        var qi = 0
        var prevMatch = -2

        for (ci, ch) in c.enumerated() {
            guard qi < q.count, ch == q[qi] else { continue }
            var bonus = 1
            if ci == prevMatch + 1 { bonus += 5 }               // contiguous run
            if ci == 0 { bonus += 8 }                            // start of string
            else if boundaries.contains(c[ci - 1]) { bonus += 4 } // after a word boundary
            score += bonus
            prevMatch = ci
            qi += 1
        }
        return qi == q.count ? score : nil
    }

    /// True when `query` fuzzy-matches `candidate`.
    static func matches(query: String, candidate: String) -> Bool {
        score(query: query, candidate: candidate) != nil
    }
}
