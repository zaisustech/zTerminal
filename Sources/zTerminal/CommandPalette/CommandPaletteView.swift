import SwiftUI
import AppKit

/// The ⌘K command palette: a centered overlay with a filter field and a
/// keyboard-navigable list of aggregated actions. Grouped by category when empty,
/// a flat ranked list while searching.
struct CommandPaletteView: View {
    let model: WindowModel
    @EnvironmentObject var theme: ThemeManager
    var onClose: () -> Void

    @State private var query = ""
    @State private var selection = 0
    @State private var allItems: [PaletteItem] = []

    private var visible: [PaletteItem] { PaletteRanker.ranked(allItems, query: query) }
    private var grouped: Bool { query.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            PaletteFieldRepresentable(
                text: $query,
                onMoveUp: { move(-1) },
                onMoveDown: { move(1) },
                onActivate: { newTab in activate(newTab: newTab) },
                onClose: onClose)
                .padding(.horizontal, 12).padding(.vertical, 10)
            Divider().opacity(0.4)
            list
            footer
        }
        .frame(width: 560)
        .frame(maxHeight: 420)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.white.opacity(0.12)))
        .shadow(color: .black.opacity(0.4), radius: 30, y: 14)
        .padding(.top, 80)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(
            // Click-away scrim.
            Color.black.opacity(0.25).ignoresSafeArea().onTapGesture { onClose() }
        )
        .onChange(of: query) { _ in selection = 0 }
        .onAppear { allItems = PaletteAggregator.items(model: model, theme: theme) }
    }

    private var list: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 1) {
                    if visible.isEmpty {
                        Text("No matches").font(.system(size: 12)).foregroundStyle(.secondary).padding(12)
                    }
                    ForEach(Array(visible.enumerated()), id: \.element.id) { index, item in
                        if grouped, index == 0 || visible[index - 1].category != item.category {
                            Text(item.category.rawValue.uppercased())
                                .font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                                .padding(.horizontal, 12).padding(.top, 8).padding(.bottom, 2)
                        }
                        row(item, selected: index == selection)
                            .id(index)
                            .onTapGesture { selection = index; activate(newTab: false) }
                    }
                }
                .padding(.vertical, 4)
            }
            .onChange(of: selection) { proxy.scrollTo($0, anchor: .center) }
        }
    }

    private func row(_ item: PaletteItem, selected: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: item.icon)
                .font(.system(size: 13)).frame(width: 20)
                .foregroundStyle(item.iconColorHex.flatMap { Color(hex: $0) } ?? theme.accent)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.title).font(.system(size: 13)).lineLimit(1)
                if !item.subtitle.isEmpty {
                    Text(item.subtitle).font(.system(size: 11)).foregroundStyle(.secondary)
                        .lineLimit(1).truncationMode(.middle)
                }
            }
            Spacer()
            if !grouped {
                Text(item.category.rawValue).font(.system(size: 10)).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 5)
        .background(selected ? Color.accentColor.opacity(0.30) : Color.clear)
        .contentShape(Rectangle())
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Text("↑↓ navigate").foregroundStyle(.secondary)
            Text("↩ run").foregroundStyle(.secondary)
            Text("⌘↩ new tab").foregroundStyle(.secondary)
            Spacer()
            Text("esc close").foregroundStyle(.secondary)
        }
        .font(.system(size: 10))
        .padding(.horizontal, 12).padding(.vertical, 6)
        .overlay(Divider().opacity(0.4), alignment: .top)
    }

    private func move(_ delta: Int) {
        guard !visible.isEmpty else { return }
        selection = min(max(0, selection + delta), visible.count - 1)
    }

    private func activate(newTab: Bool) {
        guard visible.indices.contains(selection) else { return }
        let item = visible[selection]
        onClose()
        item.activate(newTab && item.supportsNewTab)
    }
}

/// Observes the ⌘K toggle notification and shows the palette over the window.
struct CommandPaletteHost: View {
    let model: WindowModel
    @State private var shown = false
    var body: some View {
        ZStack {
            if shown { CommandPaletteView(model: model) { shown = false } }
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleCommandPalette)) { _ in
            shown.toggle()
        }
    }
}

/// AppKit search field for the palette: reports live text plus arrow/return/escape
/// so the list is keyboard-driven on macOS 13. Focuses itself on appear.
private struct PaletteFieldRepresentable: NSViewRepresentable {
    @Binding var text: String
    var onMoveUp: () -> Void
    var onMoveDown: () -> Void
    var onActivate: (_ newTab: Bool) -> Void
    var onClose: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSSearchField {
        let field = NSSearchField()
        field.placeholderString = "Run a command, task, bookmark, or jump to a folder…"
        field.delegate = context.coordinator
        field.focusRingType = .none
        field.sendsSearchStringImmediately = true
        field.font = .systemFont(ofSize: 14)
        DispatchQueue.main.async { field.window?.makeFirstResponder(field) }
        return field
    }
    func updateNSView(_ field: NSSearchField, context: Context) {
        if field.stringValue != text { field.stringValue = text }
    }

    final class Coordinator: NSObject, NSSearchFieldDelegate {
        let parent: PaletteFieldRepresentable
        init(_ parent: PaletteFieldRepresentable) { self.parent = parent }
        func controlTextDidChange(_ obj: Notification) {
            parent.text = (obj.object as? NSSearchField)?.stringValue ?? ""
        }
        func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            switch selector {
            case #selector(NSResponder.moveUp(_:)):        parent.onMoveUp();  return true
            case #selector(NSResponder.moveDown(_:)):      parent.onMoveDown(); return true
            case #selector(NSResponder.cancelOperation(_:)): parent.onClose(); return true
            case #selector(NSResponder.insertNewline(_:)):
                let cmd = NSApp.currentEvent?.modifierFlags.contains(.command) == true
                parent.onActivate(cmd)
                return true
            default: return false
            }
        }
    }
}
