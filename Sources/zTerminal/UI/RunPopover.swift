import SwiftUI
import AppKit

/// Which tasks a popover shows: `.zTerminal.json` bookmarks, or auto-detected
/// project script-shortcuts (npm, cargo, make…).
enum RunScope { case bookmarks, scripts }

/// Toolbar actions: a **bookmark** button for `.zTerminal.json` bookmarks and a
/// **play** button for auto-detected project script-shortcuts. Each is shown only
/// when its kind of task is present, and opens its own scoped popover.
struct RunButton: View {
    @ObservedObject var model: WindowModel
    @ObservedObject var session: SessionModel
    @State private var showBookmarks = false
    @State private var showScripts = false

    var body: some View {
        HStack(spacing: 10) {
            // Bookmark action is always available — opening it in a folder without a
            // `.zTerminal.json` lets the user add the first bookmark (creates the file).
            Button { showBookmarks.toggle() } label: {
                Image(systemName: "bookmark.circle.fill").font(.system(size: 15))
            }
            .buttonStyle(.plain)
            .help("Bookmarks")
            .accessibilityLabel("Bookmarks")
            .accessibilityHint("Shows this project's bookmarked commands")
            .popover(isPresented: $showBookmarks, arrowEdge: .bottom) {
                RunPopover(model: model, session: session, scope: .bookmarks, isPresented: $showBookmarks)
            }
            // Play action only when a manifest-based ecosystem is detected.
            if TaskRunner.hasScriptTasks(session.cwd) {
                Button { showScripts.toggle() } label: {
                    Image(systemName: "play.circle.fill").font(.system(size: 15))
                }
                .buttonStyle(.plain)
                .help("Run a project task")
                .accessibilityLabel("Run task")
                .accessibilityHint("Shows runnable script tasks for this project")
                .popover(isPresented: $showScripts, arrowEdge: .bottom) {
                    RunPopover(model: model, session: session, scope: .scripts, isPresented: $showScripts)
                }
            }
        }
    }
}

/// Lists runnable tasks grouped by ecosystem; runs one in the current tab (idle)
/// or a new tab (busy shell / ⌘).
struct RunPopover: View {
    @ObservedObject var model: WindowModel
    @ObservedObject var session: SessionModel
    var scope: RunScope = .scripts
    @Binding var isPresented: Bool
    @State private var filter = ""
    @State private var nodeManager: PackageManager?
    @State private var bookmarkForm: BookmarkFormState?  // add (index nil) or edit
    @State private var reloadToken = 0           // bumped to re-read .zTerminal.json
    @State private var argPrompt: ArgPrompt?     // set when a command needs <arg> values
    @FocusState private var filterFocused: Bool

    /// A pending command with `<arg>` placeholders awaiting user-supplied values.
    struct ArgPrompt: Identifiable {
        let id = UUID()
        let name: String
        let command: String
        let labels: [String]
        let newTab: Bool
    }

    /// The add/edit bookmark sheet: `index == nil` adds a new one; otherwise edits.
    /// `dir` is the config directory to save into (home for Global, cwd for Current).
    struct BookmarkFormState: Identifiable {
        let id = UUID()
        let dir: String
        let index: Int?
        let initial: Bookmark
    }

    // Computed synchronously so the popover has content at first layout (re-scans
    // each time it opens, satisfying "reflect updated tasks"). `reloadToken` forces
    // a recompute after a bookmark is added.
    private var groups: [RunGroup] {
        _ = reloadToken
        let all = TaskRunner.detect(in: session.cwd)
        switch scope {
        case .bookmarks: return all.filter { $0.bookmarks }
        case .scripts:   return all.filter { !$0.bookmarks }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(scope == .bookmarks ? "Bookmarks" : "Run").font(.ztHeading)
            TextField(scope == .bookmarks ? "Filter bookmarks" : "Filter tasks", text: $filter)
                .focused($filterFocused)
                .frostedField(focused: filterFocused)
                .accessibilityLabel(scope == .bookmarks ? "Filter bookmarks" : "Filter tasks")
                .onSubmit { runFirstMatch() }

            if scope == .bookmarks {
                bookmarksContent
            } else if groups.isEmpty {
                Text("No runnable tasks here.").foregroundStyle(.secondary)
                    .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(visibleGroups) { group in section(group) }
                    }
                    .padding(.trailing, 4)
                }
                .frame(maxHeight: .infinity)
            }
            Text("Return: run here · ⌘-click or ↗: new tab")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(width: 360, height: 460)     // stable size regardless of load timing
        .background(.ultraThinMaterial)
        .overlay {
            if let prompt = argPrompt {
                ArgumentForm(prompt: prompt,
                             onRun: { finalCommand in
                                 argPrompt = nil
                                 runCommand(finalCommand, forceNewTab: prompt.newTab)
                             },
                             onCancel: { argPrompt = nil })
                    .background(.ultraThinMaterial)
                    .transition(.opacity)
            } else if let form = bookmarkForm {
                BookmarkForm(
                    title: form.index == nil ? "Add bookmark" : "Edit bookmark",
                    initial: form.initial,
                    onSave: { bm in
                        if let idx = form.index {
                            try? ZTerminalConfig.updateBookmark(at: idx, to: bm, in: form.dir)
                        } else {
                            try? ZTerminalConfig.addBookmark(bm, in: form.dir)
                        }
                        bookmarkForm = nil
                        reloadToken += 1
                    },
                    onCancel: { bookmarkForm = nil })
                    .background(.ultraThinMaterial)
                    .transition(.opacity)
            }
        }
    }

    // MARK: bookmarks (editable, split into Global + Current)

    private var homeDir: String { NSHomeDirectory() }
    /// True when the tab's CWD is the home folder, so Global and Current would be
    /// the same `.zTerminal.json` — we then show a single (Global) section.
    private var cwdIsHome: Bool { session.cwd == homeDir }
    /// Short name for the Current-directory section (the folder's last component).
    private var currentName: String {
        let n = (session.cwd as NSString).lastPathComponent
        return n.isEmpty ? "Current" : n
    }

    /// Bookmarks in a given config dir, paired with their index, filtered by name.
    private func bookmarks(in dir: String) -> [(index: Int, bookmark: Bookmark)] {
        _ = reloadToken
        let all = ZTerminalConfig.load(in: dir)?.bookmarks ?? []
        return all.enumerated()
            .filter { filter.isEmpty || $0.element.name.localizedCaseInsensitiveContains(filter) }
            .map { (index: $0.offset, bookmark: $0.element) }
    }

    @ViewBuilder private var bookmarksContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                bookmarkSection(title: "Global", dir: homeDir,
                                hint: "Saved to ~/.zTerminal.json — available in every folder")
                if !cwdIsHome {
                    bookmarkSection(title: currentName, dir: session.cwd,
                                    hint: "Saved to .zTerminal.json in this folder")
                }
            }
            .padding(.trailing, 4)
        }
        .frame(maxHeight: .infinity)
    }

    /// One bookmark section (Global or Current): its rows plus an "Add" button that
    /// targets that section's `.zTerminal.json`.
    @ViewBuilder private func bookmarkSection(title: String, dir: String, hint: String) -> some View {
        let items = bookmarks(in: dir)
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased()).font(.ztLabel).foregroundStyle(.secondary)

            if items.isEmpty {
                Text(filter.isEmpty ? "No bookmarks yet." : "No matching bookmarks.")
                    .foregroundStyle(.secondary).font(.caption).padding(.vertical, 2)
            } else {
                ForEach(items, id: \.index) { item in
                    BookmarkRow(
                        bookmark: item.bookmark,
                        onRun: { newTab in launch(item.bookmark.command, newTab: newTab, name: item.bookmark.name) },
                        onEdit: { bookmarkForm = BookmarkFormState(dir: dir, index: item.index, initial: item.bookmark) },
                        onDelete: {
                            try? ZTerminalConfig.removeBookmark(at: item.index, in: dir)
                            reloadToken += 1
                        })
                }
            }

            if filter.isEmpty {
                Button { bookmarkForm = BookmarkFormState(dir: dir, index: nil, initial: Bookmark(name: "", command: "")) } label: {
                    Label("Add to \(title)", systemImage: "plus.circle")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.plain).foregroundStyle(.secondary)
                .padding(.horizontal, 8).padding(.vertical, 2)
                .help(hint)
                .accessibilityHint(hint)
            }
        }
    }

    // MARK: sections

    @ViewBuilder private func section(_ group: RunGroup) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(group.title.uppercased())
                    .font(.ztLabel).foregroundStyle(.secondary)
                Spacer()
                if group.managers.count > 1 {
                    Picker("", selection: Binding(
                        get: { nodeManager ?? group.managers[0] },
                        set: { nodeManager = $0 })) {
                        ForEach(group.managers, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented).labelsHidden().fixedSize()
                    .accessibilityLabel("Package manager")
                }
            }
            if let err = group.error {
                Label(err, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange).font(.callout)
            } else if filtered(group.tasks).isEmpty {
                if filter.isEmpty, let install = group.installCommand {
                    Button("Install dependencies") { runCommand(install) }
                } else if filter.isEmpty, group.bookmarks {
                    Text("No bookmarks yet.").foregroundStyle(.secondary).font(.caption)
                } else if filter.isEmpty {
                    Text("No tasks").foregroundStyle(.secondary).font(.caption)
                }
            } else {
                ForEach(filtered(group.tasks), id: \.runCommand) { t in
                    RunRow(task: t) { newTab in run(t, in: group, newTab: newTab) }
                }
            }
        }
    }

    // MARK: helpers

    private var visibleGroups: [RunGroup] {
        filter.isEmpty ? groups : groups.filter { !filtered($0.tasks).isEmpty }
    }
    private func filtered(_ tasks: [RunTask]) -> [RunTask] {
        filter.isEmpty ? tasks : tasks.filter { $0.name.localizedCaseInsensitiveContains(filter) }
    }

    private func command(for task: RunTask, in group: RunGroup) -> String {
        guard !group.managers.isEmpty else { return task.runCommand }   // non-Node: fixed
        return (nodeManager ?? group.managers[0]).runCommand(for: task.name)
    }

    private func runFirstMatch() {
        if scope == .bookmarks {
            let item = bookmarks(in: homeDir).first ?? (cwdIsHome ? nil : bookmarks(in: session.cwd).first)
            if let item = item { launch(item.bookmark.command, newTab: false, name: item.bookmark.name) }
            return
        }
        for g in visibleGroups {
            if let first = filtered(g.tasks).first { run(first, in: g, newTab: false); return }
        }
    }

    private func run(_ task: RunTask, in group: RunGroup, newTab: Bool) {
        launch(command(for: task, in: group), newTab: newTab, name: task.name)
    }

    /// Run a command, first prompting for any `<arg>` placeholders it contains.
    private func launch(_ command: String, newTab: Bool, name: String) {
        let labels = CommandTemplate.placeholders(in: command)
        if labels.isEmpty {
            runCommand(command, forceNewTab: newTab)
        } else {
            argPrompt = ArgPrompt(name: name, command: command, labels: labels, newTab: newTab)
        }
    }

    private func runCommand(_ command: String, forceNewTab: Bool = false) {
        isPresented = false
        if forceNewTab || !session.isIdleAtPrompt {
            model.open(directory: session.cwd, command: command)
        } else {
            session.run(command: command)
        }
    }
}

private struct RunRow: View {
    let task: RunTask
    let onRun: (_ newTab: Bool) -> Void
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 8) {
            if let icon = task.icon {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(task.iconColorHex.map(Color.init(hex:)) ?? Color.accentColor)
                    .frame(width: 20)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(task.name).font(.system(size: 13, weight: .medium))
                Text(task.rawCommand).font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            Button { onRun(true) } label: { Image(systemName: "arrow.up.right.square") }
                .buttonStyle(.plain).help("Run in a new tab")
                .opacity(hovering ? 1 : 0.4)
                .accessibilityLabel("Run \(task.name) in a new tab")
        }
        .padding(.horizontal, 8).padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 6).fill(hovering ? Color.primary.opacity(0.08) : .clear))
        .contentShape(Rectangle())
        .onTapGesture { onRun(NSEvent.modifierFlags.contains(.command)) }
        .onHover { hovering = $0 }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(task.name), runs \(task.rawCommand)")
        .accessibilityHint("Return runs in this tab; hold Command to run in a new tab")
        .accessibilityAddTraits(.isButton)
    }
}

/// A row for one editable bookmark: colored icon, name + command, and (on hover)
/// edit and delete controls. Tapping runs it; ⌘/↗ runs in a new tab.
private struct BookmarkRow: View {
    let bookmark: Bookmark
    let onRun: (_ newTab: Bool) -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: bookmark.icon)
                .font(.system(size: 14))
                .foregroundStyle(bookmark.color.map(Color.init(hex:)) ?? Color.accentColor)
                .frame(width: 20)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(bookmark.name).font(.system(size: 13, weight: .medium))
                Text(bookmark.command).font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            if hovering {
                Button { onEdit() } label: { Image(systemName: "pencil") }
                    .buttonStyle(.plain).help("Edit bookmark")
                    .accessibilityLabel("Edit \(bookmark.name)")
                Button { onDelete() } label: { Image(systemName: "trash") }
                    .buttonStyle(.plain).help("Delete bookmark").foregroundStyle(.secondary)
                    .accessibilityLabel("Delete \(bookmark.name)")
                Button { onRun(true) } label: { Image(systemName: "arrow.up.right.square") }
                    .buttonStyle(.plain).help("Run in a new tab")
                    .accessibilityLabel("Run \(bookmark.name) in a new tab")
            }
        }
        .padding(.horizontal, 8).padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 6).fill(hovering ? Color.primary.opacity(0.08) : .clear))
        .contentShape(Rectangle())
        .onTapGesture { onRun(NSEvent.modifierFlags.contains(.command)) }
        .onHover { hovering = $0 }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(bookmark.name), runs \(bookmark.command)")
        .accessibilityHint("Return runs in this tab; hold Command to run in a new tab")
    }
}

/// Add or edit a bookmark in `.zTerminal.json`: icon, color, name, and command.
private struct BookmarkForm: View {
    let title: String
    let onSave: (Bookmark) -> Void
    let onCancel: () -> Void

    @State private var name: String
    @State private var command: String
    @State private var icon: String
    @State private var color: Color
    @State private var showIconPicker = false
    @FocusState private var nameFocused: Bool

    init(title: String, initial: Bookmark, onSave: @escaping (Bookmark) -> Void, onCancel: @escaping () -> Void) {
        self.title = title
        self.onSave = onSave
        self.onCancel = onCancel
        _name = State(initialValue: initial.name)
        _command = State(initialValue: initial.command)
        _icon = State(initialValue: initial.icon)
        _color = State(initialValue: Color(hex: initial.color ?? "#4F8CFF"))
    }

    /// Candidate SF Symbols for bookmark icons. Filtered at load time to those
    /// actually available on this macOS (see `icons`), so the grid never shows a
    /// blank tile even as the list grows.
    private static let rawIcons = [
        // Run / build / control
        "star.fill", "play.fill", "play.circle.fill", "stop.fill", "stop.circle.fill",
        "pause.fill", "pause.circle.fill", "forward.fill", "forward.end.fill", "backward.fill",
        "playpause.fill", "hammer.fill", "hammer.circle.fill", "wrench.and.screwdriver.fill",
        "wrench.fill", "wrench.adjustable.fill", "screwdriver.fill", "arrow.clockwise",
        "arrow.clockwise.circle.fill", "arrow.triangle.2.circlepath", "arrow.2.squarepath",
        "arrow.up.right.square", "arrow.up.right.square.fill", "bolt.fill", "bolt.circle.fill",
        "gearshape.fill", "gearshape.2.fill", "gear", "slider.horizontal.3",
        "switch.2", "power", "powersleep", "restart", "playpause",
        // Files / storage
        "doc.fill", "doc.text.fill", "doc.plaintext.fill", "doc.richtext.fill",
        "doc.on.doc.fill", "doc.badge.gearshape.fill", "note.text", "folder.fill",
        "folder.fill.badge.plus", "folder.badge.gearshape", "shippingbox.fill", "archivebox.fill",
        "tray.fill", "tray.full.fill", "tray.and.arrow.down.fill", "tray.and.arrow.up.fill",
        "externaldrive.fill", "internaldrive.fill", "opticaldiscdrive.fill", "server.rack",
        "cylinder.split.1x2.fill", "cylinder.fill", "square.and.arrow.up.fill", "square.and.arrow.down.fill",
        // Dev / code / system
        "terminal.fill", "terminal", "curlybraces", "curlybraces.square.fill",
        "chevron.left.forwardslash.chevron.right", "function", "cpu", "cpu.fill",
        "memorychip", "memorychip.fill", "ant.fill", "ladybug.fill", "testtube.2",
        "sparkles", "wand.and.stars", "wand.and.rays", "keyboard.fill", "cursorarrow.rays",
        "fanblades.fill", "barometer", "gauge", "gauge.high", "speedometer",
        "checkmark.seal.fill", "xmark.seal.fill", "checkmark.circle.fill", "checkmark.shield.fill",
        "exclamationmark.triangle.fill", "exclamationmark.octagon.fill", "swift",
        // Network / cloud / comms
        "globe", "globe.americas.fill", "network", "cloud.fill", "cloud.bolt.fill",
        "cloud.rain.fill", "link", "link.circle.fill", "wifi", "personalhotspot",
        "antenna.radiowaves.left.and.right", "dot.radiowaves.left.and.right", "phone.fill",
        "message.fill", "bubble.left.fill", "envelope.fill", "envelope.badge.fill", "paperplane.fill",
        // Charts / data
        "chart.bar.fill", "chart.bar.xaxis", "chart.line.uptrend.xyaxis", "chart.pie.fill",
        "list.bullet", "list.number", "list.bullet.rectangle.fill", "checklist", "tablecells.fill",
        "square.grid.2x2.fill", "square.grid.3x3.fill", "circle.grid.3x3.fill", "rectangle.stack.fill",
        "square.stack.3d.up.fill", "square.3.layers.3d.down.right",
        // Shapes / labels
        "circle.fill", "square.fill", "triangle.fill", "diamond.fill", "hexagon.fill",
        "octagon.fill", "seal.fill", "app.fill", "cube.fill", "cube.transparent",
        "book.fill", "books.vertical.fill", "text.book.closed.fill", "graduationcap.fill",
        "tag.fill", "bookmark.fill", "pin.fill", "paperclip", "flag.fill", "flag.checkered",
        "bell.fill", "key.fill", "lock.fill", "lock.open.fill", "lock.shield.fill", "shield.fill",
        // Nature / weather
        "flame.fill", "leaf.fill", "drop.fill", "snowflake", "wind", "bolt.horizontal.fill",
        "sun.max.fill", "moon.fill", "moon.stars.fill", "cloud.sun.fill", "hare.fill",
        "tortoise.fill", "pawprint.fill", "waveform", "waveform.path.ecg",
        // Time
        "timer", "clock.fill", "alarm.fill", "stopwatch.fill", "hourglass", "calendar",
        "calendar.circle.fill", "calendar.badge.clock",
        // People / health / places
        "person.crop.circle.fill", "person.2.fill", "person.3.fill", "hand.raised.fill",
        "hand.thumbsup.fill", "heart.fill", "brain.head.profile", "eye.fill",
        "cross.case.fill", "bandage.fill", "pills.fill", "stethoscope",
        "house.fill", "building.2.fill", "building.columns.fill", "map.fill", "location.fill",
        "car.fill", "bicycle", "airplane", "tram.fill", "bus.fill", "fuelpump.fill",
        // Objects / misc
        "lightbulb.fill", "gift.fill", "crown.fill", "trophy.fill", "rosette",
        "cart.fill", "bag.fill", "creditcard.fill", "dollarsign.circle.fill", "bitcoinsign.circle.fill",
        "pencil", "pencil.tip", "highlighter", "ruler.fill", "scissors", "paintbrush.fill",
        "paintbrush.pointed.fill", "paintpalette.fill", "eyedropper.halffull", "camera.fill",
        "video.fill", "photo.fill", "film.fill", "music.note", "music.note.list", "mic.fill",
        "speaker.wave.3.fill", "tv.fill", "printer.fill", "scanner.fill",
        "trash.fill", "line.3.horizontal.decrease.circle", "magnifyingglass", "command", "questionmark.circle.fill",
    ]

    /// The candidate icons that resolve on this system (drops any unavailable
    /// symbol so the picker grid shows only real, previewable icons).
    static let icons: [String] = {
        var seen = Set<String>()
        return rawIcons.filter { sym in
            guard seen.insert(sym).inserted else { return false }
            return NSImage(systemSymbolName: sym, accessibilityDescription: nil) != nil
        }
    }()

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !command.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title).font(.ztHeading)
                Spacer()
                Button { onCancel() } label: { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
                    .accessibilityLabel("Cancel")
            }
            HStack(spacing: 10) {
                Button { showIconPicker = true } label: {
                    Image(systemName: icon).font(.system(size: 16))
                        .foregroundStyle(color).frame(width: 28, height: 28)
                        .background(RoundedRectangle(cornerRadius: 7).fill(Color.primary.opacity(0.08)))
                        .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(.white.opacity(0.12)))
                }
                .buttonStyle(.plain).fixedSize()
                .help("Pick an icon").accessibilityLabel("Bookmark icon")
                .popover(isPresented: $showIconPicker, arrowEdge: .bottom) {
                    IconGridPicker(selected: $icon, tint: color) { showIconPicker = false }
                }

                ColorPicker("", selection: $color, supportsOpacity: false)
                    .labelsHidden().fixedSize()
                    .help("Icon color").accessibilityLabel("Bookmark icon color")

                TextField("Name", text: $name)
                    .textFieldStyle(.roundedBorder).focused($nameFocused)
                    .font(.system(size: 13, weight: .medium))
            }
            VStack(alignment: .leading, spacing: 3) {
                TextField("Command (e.g. expo prebuild --clean)", text: $command)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced))
                    .onSubmit { if canSave { save() } }
                Text("Tip: use <name> for a value you'll be asked for at run time.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                Button("Save", action: save)
                    .buttonStyle(.borderedProminent).keyboardShortcut(.return).disabled(!canSave)
            }
        }
        .padding(16)
        .onAppear { DispatchQueue.main.async { nameFocused = true } }
    }

    private func save() {
        guard canSave else { return }
        onSave(Bookmark(name: name.trimmingCharacters(in: .whitespaces),
                        command: command.trimmingCharacters(in: .whitespaces),
                        icon: icon,
                        color: NSColor(color).hexString))
    }
}

/// A scrollable grid of rendered SF Symbols for picking a bookmark icon. Shows
/// each icon as a preview (in the chosen tint), highlights the current selection,
/// and can be filtered by typing part of a symbol name.
private struct IconGridPicker: View {
    @Binding var selected: String
    let tint: Color
    let onPick: () -> Void

    @State private var query = ""

    private let columns = Array(repeating: GridItem(.fixed(38), spacing: 6), count: 6)

    private var filtered: [String] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return BookmarkForm.icons }
        return BookmarkForm.icons.filter { $0.lowercased().contains(q) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Filter icons", text: $query)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12))

            ScrollView {
                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(filtered, id: \.self) { sym in
                        let isSel = sym == selected
                        Button {
                            selected = sym
                            onPick()
                        } label: {
                            Image(systemName: sym)
                                .font(.system(size: 16))
                                .foregroundStyle(isSel ? tint : .primary)
                                .frame(width: 34, height: 34)
                                .background(
                                    RoundedRectangle(cornerRadius: 7)
                                        .fill(isSel ? tint.opacity(0.18) : Color.primary.opacity(0.06))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 7)
                                        .strokeBorder(isSel ? tint : .clear, lineWidth: 1.5)
                                )
                        }
                        .buttonStyle(.plain)
                        .help(sym)
                        .accessibilityLabel(sym)
                        .accessibilityAddTraits(isSel ? [.isButton, .isSelected] : .isButton)
                    }
                }
                .padding(.vertical, 2)
            }
            .frame(width: 264, height: 240)

            if filtered.isEmpty {
                Text("No icons match “\(query)”.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(width: 288)
    }
}

/// Collects values for a command's `<arg>` placeholders, then runs the substituted
/// command. One field per placeholder; the live command preview updates as you type.
private struct ArgumentForm: View {
    let prompt: RunPopover.ArgPrompt
    let onRun: (_ finalCommand: String) -> Void
    let onCancel: () -> Void

    @State private var values: [String: String] = [:]
    @FocusState private var firstFocused: Bool

    private var finalCommand: String {
        CommandTemplate.substitute(prompt.command, values: values)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(prompt.name).font(.ztHeading)
                Spacer()
                Button { onCancel() } label: { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
                    .accessibilityLabel("Cancel")
            }
            Text("Fill in the arguments for this command.")
                .font(.caption).foregroundStyle(.secondary)

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(prompt.labels.enumerated()), id: \.element) { idx, label in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(label).font(.system(size: 12, weight: .medium))
                            TextField(label, text: Binding(
                                get: { values[label] ?? "" },
                                set: { values[label] = $0 }))
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 12, design: .monospaced))
                                .focused($firstFocused, equals: idx == 0)
                                .onSubmit { onRun(finalCommand) }
                        }
                    }
                }
            }
            .frame(maxHeight: .infinity)

            Text(finalCommand)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary).lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                Button(prompt.newTab ? "Run in new tab" : "Run") { onRun(finalCommand) }
                    .buttonStyle(.borderedProminent).keyboardShortcut(.return)
            }
        }
        .padding(16)
        .onAppear { DispatchQueue.main.async { firstFocused = true } }
    }
}
