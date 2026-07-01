import SwiftUI

/// The San Francisco type scale used across zTerminal chrome, so titles,
/// headings, body, and secondary labels stay consistent (theme spec §7.1).
extension Font {
    static let ztTitle = Font.system(size: 20, weight: .bold, design: .default)
    static let ztHeading = Font.system(size: 15, weight: .semibold, design: .default)
    static let ztBody = Font.system(size: 13, weight: .regular, design: .default)
    static let ztLabel = Font.system(size: 11, weight: .medium, design: .default)
    static let ztMono = Font.system(size: 12, weight: .regular, design: .monospaced)
}
