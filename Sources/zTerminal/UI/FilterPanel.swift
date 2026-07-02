import SwiftUI

/// Observes the controller and shows the Chrome-DevTools-style filter panel over
/// the terminal only while filter mode is on.
struct FilterPanelHost: View {
    @ObservedObject var controller: SearchController
    var body: some View {
        if controller.isActive && controller.filterMode {
            FilterPanel(controller: controller)
                .transition(.opacity)
        }
    }
}

/// A panel covering the terminal that lists only the matching lines — each with
/// its original line number and matches highlighted — plus severity chips, an
/// invert toggle, and a `Showing N of M lines` count. Clicking a line jumps the
/// live terminal to it. Read-only projection; the terminal buffer is untouched.
struct FilterPanel: View {
    @ObservedObject var controller: SearchController

    var body: some View {
        // Re-read on every filterRevision bump (new output) and query/chip change.
        let _ = controller.filterRevision
        let lines = controller.filteredLines()

        VStack(spacing: 0) {
            chipBar
            Divider().opacity(0.3)
            if lines.isEmpty {
                Spacer()
                Text(controller.totalCount == 0 ? "No output to filter" : "No lines match the filter")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 12))
                Spacer()
            } else {
                List(lines) { line in
                    row(line)
                        .listRowInsets(EdgeInsets(top: 1, leading: 8, bottom: 1, trailing: 8))
                        .listRowSeparator(.hidden)
                        .contentShape(Rectangle())
                        .onTapGesture { controller.jumpToLine(line.id) }
                }
                .listStyle(.plain)
                .environment(\.defaultMinListRowHeight, 18)
            }
        }
        .background(.ultraThinMaterial)
    }

    // MARK: Chip bar + count

    private var chipBar: some View {
        HStack(spacing: 6) {
            chip(label: "All", active: controller.severityFilter == nil, color: .secondary) {
                controller.setSeverity(nil)
            }
            ForEach(LogSeverity.chipLevels) { sev in
                chip(label: sev.label, active: controller.severityFilter == sev, color: sev.color) {
                    controller.setSeverity(controller.severityFilter == sev ? nil : sev)
                }
            }

            Divider().frame(height: 14)

            Button(action: controller.toggleInvert) {
                Label("Invert", systemImage: "arrow.triangle.2.circlepath")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.plain)
            .foregroundStyle(controller.invert ? Color.accentColor : Color.secondary)
            .help("Show lines that do NOT match")

            Spacer()

            Text("Showing \(controller.filteredLines().count) of \(controller.totalCount) lines")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    private func chip(label: String, active: Bool, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .padding(.horizontal, 8).padding(.vertical, 2)
                .background(active ? color.opacity(0.85) : color.opacity(0.15),
                            in: Capsule())
                .foregroundStyle(active ? Color.white : color)
        }
        .buttonStyle(.plain)
    }

    // MARK: Row

    private func row(_ line: SearchController.FilterLine) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(line.id + 1)")            // original line number (1-based)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(minWidth: 52, alignment: .trailing)
            if line.severity != .none {
                Circle().fill(line.severity.color).frame(width: 6, height: 6).padding(.top, 5)
            } else {
                Color.clear.frame(width: 6, height: 6)
            }
            highlighted(line)
                .font(.system(size: 12, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// The line text with matched ranges emphasized.
    private func highlighted(_ line: SearchController.FilterLine) -> Text {
        let ranges = controller.matchRanges(forLine: line.id)
        guard !ranges.isEmpty else { return Text(line.text) }
        let chars = Array(line.text)
        var result = Text("")
        var cursor = 0
        for r in ranges.sorted(by: { $0.lowerBound < $1.lowerBound }) {
            let lo = max(cursor, r.lowerBound), hi = min(chars.count, r.upperBound)
            guard lo < hi else { continue }
            if cursor < lo { result = result + Text(String(chars[cursor..<lo])) }
            result = result + Text(String(chars[lo..<hi]))
                .foregroundColor(Color(SearchPalette.keywordColors[0]))
                .bold()
            cursor = hi
        }
        if cursor < chars.count { result = result + Text(String(chars[cursor..<chars.count])) }
        return result
    }
}
