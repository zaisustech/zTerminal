import Foundation

/// One activatable row in the command palette. Carries display fields plus an
/// `activate(newTab:)` closure, so the palette itself needs no knowledge of how
/// each source runs.
struct PaletteItem: Identifiable {
    enum Category: String, CaseIterable {
        case bookmark  = "Bookmarks"
        case task      = "Tasks"
        case shortcut  = "Shortcuts"
        case tab       = "Tabs"
        case directory = "Recent Folders"
        case app       = "Commands"

        /// Display order when grouped (empty query).
        var order: Int { Category.allCases.firstIndex(of: self) ?? 0 }
    }

    let id: String
    let category: Category
    let title: String
    let subtitle: String
    let icon: String            // SF Symbol
    var iconColorHex: String?   // nil = accent
    /// Whether ⌘Return (force new tab) is meaningful for this item.
    var supportsNewTab: Bool = true
    let activate: (_ newTab: Bool) -> Void
}
