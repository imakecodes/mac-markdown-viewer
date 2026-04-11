import SwiftUI

// MARK: - Notifications

extension Notification.Name {
    static let toggleCommandPalette = Notification.Name("com.pendown.toggleCommandPalette")
    static let scrollToHeading      = Notification.Name("com.pendown.scrollToHeading")
}

// MARK: - Model

enum PaletteCategory: Int, CaseIterable {
    case action  = 0
    case heading = 1
    case file    = 2

    var label: String {
        switch self {
        case .action:  return L.actions
        case .heading: return L.indexCategory
        case .file:    return L.recentsCategory
        }
    }
}

struct PaletteItem: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let subtitle: String
    let shortcut: String
    let category: PaletteCategory
    let action: () -> Void
}

// MARK: - Command Palette

struct CommandPalette: View {
    @EnvironmentObject var appState: AppState
    @Binding var isVisible: Bool
    @State private var query = ""
    @State private var selectedIndex = 0

    var body: some View {
        ZStack {
            // Tap outside to dismiss
            Color.black.opacity(0.15)
                .ignoresSafeArea()
                .onTapGesture { close() }

            VStack {
                paletteContent
                    .frame(width: 520)
                    .frame(maxHeight: 380)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .liquidGlass(cornerRadius: 14)
                    .shadow(color: .black.opacity(0.30), radius: 28, y: 10)

                Spacer()
            }
            .padding(.top, 50)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .top)))
    }

    // MARK: Content

    private var paletteContent: some View {
        VStack(spacing: 0) {
            // Search row
            HStack(spacing: 10) {
                Image(systemName: "command")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.tertiary)

                PaletteTextField(
                    text: $query,
                    placeholder: L.searchPlaceholder,
                    onEscape: close,
                    onEnter: executeSelected,
                    onArrowUp:   { moveSelection(-1) },
                    onArrowDown: { moveSelection(1) }
                )
                .font(.system(size: 14))

                if !query.isEmpty {
                    Button { query = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider().padding(.horizontal, 8)

            // Results
            if filtered.isEmpty {
                emptyState
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(filtered.enumerated()), id: \.element.id) { index, item in
                                // Category header
                                if index == 0 || filtered[index - 1].category != item.category {
                                    Text(item.category.label)
                                        .font(.system(size: 10, weight: .bold, design: .rounded))
                                        .foregroundStyle(.quaternary)
                                        .padding(.horizontal, 16)
                                        .padding(.top, index == 0 ? 8 : 14)
                                        .padding(.bottom, 4)
                                }

                                PaletteRow(item: item, isSelected: index == selectedIndex)
                                    .id(item.id)
                                    .contentShape(Rectangle())
                                    .onTapGesture { execute(item) }
                            }
                        }
                        .padding(.bottom, 8)
                    }
                    .onChange(of: selectedIndex) { _ in
                        guard selectedIndex < filtered.count else { return }
                        withAnimation(.easeOut(duration: 0.1)) {
                            proxy.scrollTo(filtered[selectedIndex].id, anchor: .center)
                        }
                    }
                }
            }
        }
        .onChange(of: query) { _ in selectedIndex = 0 }
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "tray")
                .font(.system(size: 20, weight: .light))
                .foregroundStyle(.quaternary)
            Text(L.noResults)
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }

    // MARK: Data source

    private var allItems: [PaletteItem] {
        var items: [PaletteItem] = []

        // ── Actions ──
        items.append(.init(icon: "doc.badge.plus", title: L.openFileAction, subtitle: "",
                           shortcut: "⌘O", category: .action) { appState.showOpenPanel() })

        if appState.panes.count < AppState.maxPanes {
            items.append(.init(icon: "rectangle.split.1x2", title: L.newPane, subtitle: "",
                               shortcut: "⇧⌘O", category: .action) { appState.addPane() })
        }

        if !appState.panes.isEmpty {
            items.append(.init(icon: "xmark.rectangle", title: L.closePaneAction, subtitle: "",
                               shortcut: "⇧⌘W", category: .action) {
                if let pane = activePane { appState.closePane(pane) }
            })
        }

        items.append(.init(icon: "magnifyingglass", title: L.searchInDocument, subtitle: "",
                           shortcut: "⌘F", category: .action) {
            NotificationCenter.default.post(name: .activateFindBar, object: nil)
        })

        if activePane?.fileURL != nil {
            items.append(.init(icon: "arrow.clockwise", title: L.reloadDocument, subtitle: "",
                               shortcut: "", category: .action) {
                if let pane = activePane, let url = pane.fileURL {
                    pane.load(url: url); appState.objectWillChange.send()
                }
            })
        }

        items.append(.init(icon: "moon.fill", title: L.toggleDarkLight, subtitle: "",
                           shortcut: "", category: .action) {
            let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            NSApp.appearance = NSAppearance(named: isDark ? .aqua : .darkAqua)
        })

        if let pane = activePane, pane.fileURL != nil {
            let liveLabel = pane.isLive ? L.disableLiveReload : L.enableLiveReload
            let liveIcon  = pane.isLive ? "bolt.slash" : "bolt"
            items.append(.init(icon: liveIcon, title: liveLabel, subtitle: "",
                               shortcut: "", category: .action) { pane.toggleLive() })
        }

        items.append(.init(icon: "trash", title: L.clearRecentsAction, subtitle: "",
                           shortcut: "", category: .action) { appState.clearRecents() })

        // ── Mode switching ──
        if let pane = activePane, pane.fileURL != nil {
            if pane.mode != .preview {
                items.append(.init(icon: "eye", title: L.modePreview, subtitle: "",
                                   shortcut: "", category: .action) { pane.setMode(.preview) })
            }
            if pane.mode != .code {
                items.append(.init(icon: "chevron.left.forwardslash.chevron.right",
                                   title: L.modeCodeEditor, subtitle: "",
                                   shortcut: "", category: .action) { pane.setMode(.code) })
            }
            if pane.mode != .visual {
                items.append(.init(icon: "pencil.and.outline",
                                   title: L.modeVisualEditor, subtitle: "",
                                   shortcut: "", category: .action) { pane.setMode(.visual) })
            }
        }

        // ── Headings from active document ──
        for h in headings {
            items.append(.init(
                icon: "text.alignleft",
                title: h.text,
                subtitle: "H\(h.level)",
                shortcut: "",
                category: .heading
            ) {
                NotificationCenter.default.post(name: .scrollToHeading, object: h.text)
            })
        }

        // ── Recent files ──
        for url in appState.recentFiles {
            let name = url.deletingPathExtension().lastPathComponent
            let dir = url.deletingLastPathComponent().path
                .replacingOccurrences(of: NSHomeDirectory(), with: "~")
            items.append(.init(icon: "doc.text", title: name, subtitle: dir,
                               shortcut: "", category: .file) {
                appState.openFile(url: url)
            })
        }

        return items
    }

    private var filtered: [PaletteItem] {
        guard !query.isEmpty else { return allItems }
        return allItems
            .compactMap { item -> (PaletteItem, Int)? in
                guard let score = fuzzyScore(query, in: item.title) else { return nil }
                return (item, score)
            }
            .sorted { $0.1 > $1.1 }
            .map(\.0)
    }

    private var activePane: Pane? {
        appState.panes.first { $0.id == appState.activePaneID } ?? appState.panes.first
    }

    private var headings: [(level: Int, text: String)] {
        guard let content = activePane?.markdownContent, !content.isEmpty else { return [] }
        var result: [(Int, String)] = []
        for line in content.components(separatedBy: .newlines) {
            let t = line.trimmingCharacters(in: .whitespaces)
            guard t.hasPrefix("#") else { continue }
            let level = t.prefix(while: { $0 == "#" }).count
            guard level <= 6 else { continue }
            let text = String(t.dropFirst(level)).trimmingCharacters(in: .whitespaces)
            if !text.isEmpty { result.append((level, text)) }
        }
        return result
    }

    // MARK: Actions

    private func moveSelection(_ delta: Int) {
        guard !filtered.isEmpty else { return }
        selectedIndex = (selectedIndex + delta + filtered.count) % filtered.count
    }

    private func executeSelected() {
        guard selectedIndex < filtered.count else { return }
        execute(filtered[selectedIndex])
    }

    private func execute(_ item: PaletteItem) {
        close()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { item.action() }
    }

    private func close() {
        withAnimation(.easeOut(duration: 0.12)) { isVisible = false }
        query = ""
        selectedIndex = 0
    }

    // MARK: Fuzzy search

    private func fuzzyScore(_ query: String, in text: String) -> Int? {
        let q = query.lowercased()
        let t = text.lowercased()
        guard !q.isEmpty else { return 100 }

        if t.hasPrefix(q)  { return 200 - t.count }
        if t.contains(q)   { return 100 - (t.distance(from: t.startIndex, to: t.range(of: q)!.lowerBound)) }

        // Subsequence match
        var qi = q.startIndex, gaps = 0, lastIdx = -1
        for (i, ch) in t.enumerated() {
            guard qi < q.endIndex else { break }
            if ch == q[qi] {
                if lastIdx >= 0 && i > lastIdx + 1 { gaps += 1 }
                lastIdx = i
                qi = q.index(after: qi)
            }
        }
        return qi == q.endIndex ? max(1, 50 - gaps * 8) : nil
    }
}

// MARK: - Palette Row

private struct PaletteRow: View {
    let item: PaletteItem
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: item.icon)
                .font(.system(size: 11))
                .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                .frame(width: 18)

            Text(item.title)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .lineLimit(1)
                .foregroundStyle(isSelected ? .primary : .primary)

            if !item.subtitle.isEmpty {
                Text(item.subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            if !item.shortcut.isEmpty {
                Text(item.shortcut)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(nsColor: .separatorColor).opacity(0.25))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor.opacity(0.12) : .clear)
                .padding(.horizontal, 6)
        )
    }
}

// MARK: - Custom TextField for palette (handles ↑ ↓ Enter Esc)

class PaletteNSTextField: NSTextField {}

struct PaletteTextField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var onEscape:    () -> Void
    var onEnter:     () -> Void
    var onArrowUp:   () -> Void
    var onArrowDown: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> PaletteNSTextField {
        let f = PaletteNSTextField()
        f.placeholderString = placeholder
        f.isBezeled         = false
        f.drawsBackground   = false
        f.font              = .systemFont(ofSize: 14)
        f.focusRingType     = .none
        f.delegate          = context.coordinator
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
            f.window?.makeFirstResponder(f)
        }
        return f
    }

    func updateNSView(_ f: PaletteNSTextField, context: Context) {
        if f.stringValue != text { f.stringValue = text }
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: PaletteTextField
        init(_ p: PaletteTextField) { self.parent = p }

        func controlTextDidChange(_ n: Notification) {
            if let f = n.object as? NSTextField { parent.text = f.stringValue }
        }

        func control(_ control: NSControl, textView: NSTextView,
                     doCommandBy sel: Selector) -> Bool {
            switch sel {
            case #selector(NSResponder.cancelOperation(_:)):
                parent.onEscape(); return true
            case #selector(NSResponder.insertNewline(_:)):
                parent.onEnter();  return true
            case #selector(NSResponder.moveUp(_:)):
                parent.onArrowUp(); return true
            case #selector(NSResponder.moveDown(_:)):
                parent.onArrowDown(); return true
            default:
                return false
            }
        }
    }
}
