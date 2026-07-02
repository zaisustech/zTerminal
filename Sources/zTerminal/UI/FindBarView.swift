import SwiftUI
import AppKit

/// Observes the session's search controller and shows the find bar only while a
/// search is active, so toggling ⌘F re-renders without the parent observing every
/// controller.
struct FindBarHost: View {
    @ObservedObject var controller: SearchController
    var body: some View {
        if controller.isActive {
            FindBarView(controller: controller)
                .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

/// The sticky ⌘F find bar shown over the top of the active terminal. Layout +
/// styling in SwiftUI (Liquid Glass material); the text input is an AppKit
/// `NSSearchField` wrapper so Return / Shift+Return / ↑ / ↓ / Esc work reliably on
/// macOS 13 (SwiftUI `onKeyPress` is macOS 14+).
struct FindBarView: View {
    @ObservedObject var controller: SearchController

    var body: some View {
        HStack(spacing: 8) {
            SearchFieldRepresentable(
                text: Binding(get: { controller.query }, set: { controller.setQuery($0) }),
                onNext: controller.next,
                onPrevious: controller.previous,
                onClose: controller.close,
                invalid: controller.query.isEmpty ? false : (controller.options.regex && !controller.isValidRegex)
            )
            .frame(width: 220)

            historyMenu

            Text(counterText)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(counterColor)
                .frame(minWidth: 64, alignment: .leading)

            navButton("chevron.up", help: "Previous (⇧⏎ / ⇧F3)", action: controller.previous)
            navButton("chevron.down", help: "Next (⏎ / F3)", action: controller.next)

            Divider().frame(height: 16)

            // Filter mode: show only matching lines in a panel (Chrome DevTools style).
            Button(action: controller.toggleFilterMode) {
                Image(systemName: "line.3.horizontal.decrease.circle\(controller.filterMode ? ".fill" : "")")
                    .font(.system(size: 12))
            }
            .buttonStyle(.borderless)
            .foregroundStyle(controller.filterMode ? Color.accentColor : Color.secondary)
            .help("Filter to matching lines")

            Divider().frame(height: 16)

            optionToggle("Aa", help: "Case sensitive", isOn: controller.options.caseSensitive) {
                var o = controller.options; o.caseSensitive.toggle(); controller.setOptions(o)
            }
            optionToggle(".*", help: "Regular expression", isOn: controller.options.regex) {
                var o = controller.options; o.regex.toggle(); controller.setOptions(o)
            }
            optionToggle("ab|", help: "Whole word", isOn: controller.options.wholeWord) {
                var o = controller.options; o.wholeWord.toggle(); controller.setOptions(o)
            }

            Divider().frame(height: 16)

            navButton("xmark", help: "Close (Esc)", action: controller.close)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
        .padding(.top, 6)
        .padding(.trailing, 14)
    }

    // MARK: Pieces

    @ViewBuilder private var historyMenu: some View {
        if controller.history.isEmpty {
            EmptyView()
        } else {
            Menu {
                ForEach(controller.history, id: \.self) { term in
                    Button(term) { controller.useHistory(term) }
                }
            } label: {
                Image(systemName: "clock.arrow.circlepath")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Recent searches")
        }
    }

    private func navButton(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 11, weight: .semibold))
        }
        .buttonStyle(.borderless)
        .help(help)
    }

    private func optionToggle(_ label: String, help: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .padding(.horizontal, 5).padding(.vertical, 2)
                .background(isOn ? Color.accentColor.opacity(0.85) : Color.clear,
                            in: RoundedRectangle(cornerRadius: 4))
                .foregroundStyle(isOn ? Color.white : Color.secondary)
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private var counterText: String {
        if controller.query.trimmingCharacters(in: .whitespaces).isEmpty { return "" }
        if controller.options.regex && !controller.isValidRegex { return "Invalid regex" }
        if controller.total == 0 { return "No results" }
        return "\(controller.current) / \(controller.total)"
    }

    private var counterColor: Color {
        if controller.options.regex && !controller.isValidRegex && !controller.query.isEmpty { return .orange }
        if controller.total == 0 && !controller.query.trimmingCharacters(in: .whitespaces).isEmpty { return .secondary }
        return .primary
    }
}

/// AppKit `NSSearchField` bridged into SwiftUI: reports live text changes and maps
/// Return / Shift+Return / ↑ / ↓ / Esc to search actions. Focuses itself when it
/// first appears so ⌘F drops the caret straight into the field.
struct SearchFieldRepresentable: NSViewRepresentable {
    @Binding var text: String
    var onNext: () -> Void
    var onPrevious: () -> Void
    var onClose: () -> Void
    var invalid: Bool

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSSearchField {
        let field = NSSearchField()
        field.placeholderString = "Find"
        field.delegate = context.coordinator
        field.sendsSearchStringImmediately = true
        field.focusRingType = .none
        field.controlSize = .small
        field.font = .systemFont(ofSize: 12)
        DispatchQueue.main.async { field.window?.makeFirstResponder(field) }
        return field
    }

    func updateNSView(_ field: NSSearchField, context: Context) {
        if field.stringValue != text { field.stringValue = text }
        // Tint the field red-ish when the regex is invalid.
        field.textColor = invalid ? .systemRed : .labelColor
    }

    final class Coordinator: NSObject, NSSearchFieldDelegate {
        let parent: SearchFieldRepresentable
        init(_ parent: SearchFieldRepresentable) { self.parent = parent }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSSearchField else { return }
            parent.text = field.stringValue
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            switch selector {
            case #selector(NSResponder.insertNewline(_:)):
                if NSApp.currentEvent?.modifierFlags.contains(.shift) == true { parent.onPrevious() }
                else { parent.onNext() }
                return true
            case #selector(NSResponder.cancelOperation(_:)):
                parent.onClose()
                return true
            case #selector(NSResponder.moveUp(_:)):
                parent.onPrevious()
                return true
            case #selector(NSResponder.moveDown(_:)):
                parent.onNext()
                return true
            default:
                return false
            }
        }
    }
}
