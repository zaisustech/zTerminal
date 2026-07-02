import SwiftUI

/// The top tab bar (native-terminal style). One entry per session; the active
/// one is highlighted. A "+" opens a new tab inheriting the current directory.
struct TabBar: View {
    @ObservedObject var model: WindowModel
    @EnvironmentObject var theme: ThemeManager

    var body: some View {
        HStack(spacing: 6) {
            ForEach(model.sessions) { session in
                TabChip(session: session,
                        isActive: session.id == model.activeID,
                        canClose: model.sessions.count > 1,
                        onSelect: { model.select(session.id) },
                        onClose: { model.close(session.id) })
                    .draggable(session.id.uuidString)
                    .dropDestination(for: String.self) { items, _ in
                        guard let dragged = items.first else { return false }
                        model.moveTab(dragged, before: session.id)
                        return true
                    }
            }
            Button(action: { model.addTab() }) {
                Image(systemName: "plus").frame(width: 16, height: 16)
            }
            .buttonStyle(GlassButtonStyle())
            .help("New tab in the current directory (⌘T)")
            Spacer()
            if let active = model.active {
                RunButton(model: model, session: active)
            }
        }
        .padding(.leading, theme.tokens.hideTitleBar ? 64 : 10)   // clear floating traffic lights when frameless
        .padding(.trailing, 10)
        .padding(.vertical, 6)
        .frame(height: 38)
        // Drag the window from empty tab-bar chrome (tabs/buttons on top keep their
        // own gestures). Restores window-move after background-drag was disabled.
        .background(WindowDragHandle())
    }
}

private struct TabChip: View {
    @ObservedObject var session: SessionModel
    let isActive: Bool
    let canClose: Bool
    let onSelect: () -> Void
    let onClose: () -> Void
    @State private var hovering = false
    @State private var isEditing = false
    @State private var draft = ""
    @FocusState private var fieldFocused: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: session.kind == .preview ? "doc.richtext"
                              : session.isRunning ? "terminal" : "checkmark.circle")
                .font(.system(size: 11))
                .foregroundStyle(isActive ? Color.accentColor : .secondary)

            if isEditing {
                TextField("", text: $draft)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .focused($fieldFocused)
                    .onSubmit(commit)
                    .onExitCommand(perform: cancel)   // Esc cancels
                    .onChange(of: fieldFocused) { focused in
                        if !focused { commit() }       // clicking away commits
                    }
            } else {
                Text(session.displayTitle)
                    .font(.system(size: 12, weight: isActive ? .semibold : .regular))
                    .lineLimit(1)
                Spacer(minLength: 6)
                // Close button — hidden when this is the only tab; otherwise shown
                // on hover/active at the right end.
                if canClose {
                    Button(action: onClose) {
                        Image(systemName: "xmark").font(.system(size: 8, weight: .bold))
                    }
                    .buttonStyle(.plain)
                    .help("Close tab (⌘W)")
                    .opacity(hovering || isActive ? 1 : 0)
                    .allowsHitTesting(hovering || isActive)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .frame(width: 172)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isActive ? Color.primary.opacity(0.12) : Color.clear)
        )
        .contentShape(Rectangle())
        // Double-click renames; single click selects.
        .onTapGesture(count: 2, perform: beginEditing)
        .onTapGesture(perform: onSelect)
        .onHover { hovering = $0 }
        .help("Double-click to rename")
    }

    private func beginEditing() {
        draft = session.displayTitle
        isEditing = true
        DispatchQueue.main.async { fieldFocused = true }
    }

    private func commit() {
        guard isEditing else { return }
        session.rename(draft)
        isEditing = false
    }

    private func cancel() {
        isEditing = false
    }
}
