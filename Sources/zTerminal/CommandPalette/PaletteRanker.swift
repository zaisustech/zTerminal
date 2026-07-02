import Foundation

/// Orders palette items for display. Empty query → items in category order
/// (stable, as aggregated). Non-empty query → fuzzy-matched items ranked by score
/// (best first), ties broken by category order. Pure and unit-testable.
enum PaletteRanker {
    static func ranked(_ items: [PaletteItem], query: String) -> [PaletteItem] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else {
            return items.sorted { $0.category.order < $1.category.order }
        }
        let scored = items.compactMap { item -> (PaletteItem, Int)? in
            // Match on the title; fall back to the subtitle with a penalty.
            if let s = FuzzyMatch.score(query: q, candidate: item.title) { return (item, s + 100) }
            if let s = FuzzyMatch.score(query: q, candidate: item.subtitle) { return (item, s) }
            return nil
        }
        return scored
            .sorted { a, b in
                if a.1 != b.1 { return a.1 > b.1 }
                return a.0.category.order < b.0.category.order
            }
            .map(\.0)
    }
}
