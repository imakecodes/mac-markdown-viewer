import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var sidebarWidth: CGFloat = 240

    var body: some View {
        HStack(spacing: 0) {
            SidebarView()
                .frame(width: sidebarWidth)
                .frame(maxHeight: .infinity)

            // Draggable sidebar divider
            DividerHandle()
                .gesture(
                    DragGesture(minimumDistance: 1)
                        .onChanged { value in
                            let newWidth = sidebarWidth + value.translation.width
                            sidebarWidth = min(max(newWidth, 180), 400)
                        }
                )

            // Detail area: panes or welcome
            if appState.panes.isEmpty {
                WelcomeView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    // Drop when no pane is open yet → open as first pane
                    .onDrop(of: [.fileURL], isTargeted: nil) { handleDrop($0) }
            } else {
                SplitPaneContainer()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                // Drops on loaded panes are handled entirely by DropAwareWebView
                // at the AppKit level. Adding SwiftUI .onDrop here would compete
                // with it and prevent the second drag from registering.
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
            guard let url = extractURL(from: item),
                  ["md", "markdown", "mdown", "mkd", "mkdn"].contains(url.pathExtension.lowercased())
            else { return }
            DispatchQueue.main.async {
                appState.openFile(url: url)
            }
        }
        return true
    }

}

// MARK: - URL extraction helper

func extractURL(from item: NSSecureCoding?) -> URL? {
    if let data = item as? Data {
        return URL(dataRepresentation: data, relativeTo: nil)
    } else if let url = item as? URL {
        return url
    } else if let nsurl = item as? NSURL {
        return nsurl as URL
    }
    return nil
}

// MARK: - Split Pane Container

struct SplitPaneContainer: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(appState.panes.enumerated()), id: \.element.id) { index, pane in
                if index > 0 {
                    PaneDivider()
                }
                PaneView(pane: pane)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

// MARK: - Single Pane

struct PaneView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var pane: Pane
    @State private var isHoveringHeader   = false
    @State private var isFileDropTargeted = false
    @State private var showFindBar        = false
    @State private var findQuery          = ""
    @State private var findFocusRequest   = false
    @StateObject private var findController = FindController()

    var body: some View {
        VStack(spacing: 0) {
            // Pane header (only when multiple panes)
            if appState.panes.count > 1 {
                PaneHeader(pane: pane, isHovering: isHoveringHeader)
                    .onHover { isHoveringHeader = $0 }
            }

            // Content area with file-drop support
            ZStack {
                if pane.fileURL != nil {
                    let htmlBody = MarkdownHTMLRenderer.renderHTML(from: pane.markdownContent)
                    MarkdownWebView(
                        htmlContent: htmlBody,
                        baseURL: pane.fileURL?.deletingLastPathComponent(),
                        onDropTargeted: { targeted in
                            withAnimation(.easeInOut(duration: 0.12)) {
                                isFileDropTargeted = targeted
                            }
                        },
                        onFileDrop: { url in
                            pane.load(url: url)
                            appState.activePaneID = pane.id
                            appState.recentFiles = RecentFilesManager.add(url, to: appState.recentFiles)
                            appState.objectWillChange.send()
                        },
                        findController: findController
                    )
                } else {
                    PaneEmptyState(pane: pane)
                        .onDrop(of: [.fileURL], isTargeted: $isFileDropTargeted) { providers in
                            handleFileDrop(providers)
                        }
                }

                if isFileDropTargeted { fileDropOverlay }

                // Find bar floats over content, top-right corner
                if showFindBar && pane.fileURL != nil {
                    FindBar(
                        controller:   findController,
                        query:        $findQuery,
                        isVisible:    $showFindBar,
                        focusRequest: $findFocusRequest
                    )
                    .background(FocusTrigger(focused: $findFocusRequest))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .allowsHitTesting(true)
                }
            }
        }
        .overlay(
            appState.activePaneID == pane.id && appState.panes.count > 1
                ? RoundedRectangle(cornerRadius: 0)
                    .strokeBorder(Color.accentColor.opacity(0.35), lineWidth: 2)
                : nil
        )
        .contentShape(Rectangle())
        .onTapGesture { appState.activePaneID = pane.id }
        .onReceive(NotificationCenter.default.publisher(for: .activateFindBar)) { _ in
            guard isActivePane, pane.fileURL != nil else { return }
            if showFindBar {
                findFocusRequest = true   // already open – re-focus the field
            } else {
                showFindBar      = true   // FindBar.onAppear triggers focus
            }
        }
    }

    private var isActivePane: Bool {
        appState.activePaneID == pane.id || appState.panes.count == 1
    }

    // MARK: Drop overlay

    private var fileDropOverlay: some View {
        ZStack {
            Color.accentColor.opacity(0.09)

            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(
                    Color.accentColor,
                    style: StrokeStyle(lineWidth: 2.5, dash: [10, 5])
                )
                .padding(12)

            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.12))
                        .frame(width: 72, height: 72)
                    Image(systemName: "rectangle.split.1x2.fill")
                        .font(.system(size: 26, weight: .light))
                        .foregroundStyle(Color.accentColor)
                }
                Text("Abrir em novo painel")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: Drop handler

    private func handleFileDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
            guard let url = extractURL(from: item),
                  ["md", "markdown", "mdown", "mkd", "mkdn"].contains(url.pathExtension.lowercased())
            else { return }
            DispatchQueue.main.async {
                pane.load(url: url)
                appState.activePaneID = pane.id
                appState.recentFiles = RecentFilesManager.add(url, to: appState.recentFiles)
                appState.objectWillChange.send()
            }
        }
        return true
    }
}

// MARK: - Pane Header

struct PaneHeader: View {
    @EnvironmentObject var appState: AppState
    let pane: Pane
    let isHovering: Bool
    @State private var isPaneDropTargeted = false

    var body: some View {
        HStack(spacing: 6) {
            // Subtle drag handle dots
            Image(systemName: "grip.horizontal")
                .font(.system(size: 7))
                .foregroundStyle(.quaternary)
                .padding(.leading, -2)

            Image(systemName: "doc.text")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)

            Text(pane.fileName.isEmpty ? "Vazio" : pane.fileName)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            // Replace file button
            if isHovering {
                Button {
                    let panel = NSOpenPanel()
                    panel.allowedContentTypes = [
                        .init(filenameExtension: "md")!,
                        .init(filenameExtension: "markdown")!
                    ].compactMap { $0 }
                    panel.allowsMultipleSelection = false
                    panel.canChooseDirectories = false
                    guard panel.runModal() == .OK, let url = panel.url else { return }
                    pane.load(url: url)
                    appState.recentFiles = RecentFilesManager.add(url, to: appState.recentFiles)
                    appState.objectWillChange.send()
                } label: {
                    Image(systemName: "arrow.triangle.swap")
                        .font(.system(size: 9))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tertiary)
                .help("Trocar arquivo")

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        appState.closePane(pane)
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tertiary)
                .help("Fechar painel")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Group {
                if isPaneDropTargeted {
                    Color.accentColor.opacity(0.18)
                } else if appState.activePaneID == pane.id {
                    Color.accentColor.opacity(0.06)
                } else {
                    Color(nsColor: .separatorColor).opacity(0.15)
                }
            }
        )
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(isPaneDropTargeted ? Color.accentColor : Color(nsColor: .separatorColor))
                .frame(height: isPaneDropTargeted ? 2 : 0.5)
                .animation(.easeInOut(duration: 0.1), value: isPaneDropTargeted)
        }
        // Drag this pane header to reorder
        .onDrag {
            NSItemProvider(object: pane.id.uuidString as NSString)
        }
        // Accept other pane headers dropped here → reorder
        .onDrop(of: [UTType.utf8PlainText], isTargeted: $isPaneDropTargeted) { providers in
            handlePaneReorder(providers)
        }
    }

    private func handlePaneReorder(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: UTType.utf8PlainText.identifier, options: nil) { item, _ in
            let uuidString: String?
            if let s = item as? String {
                uuidString = s
            } else if let ns = item as? NSString {
                uuidString = ns as String
            } else if let data = item as? Data {
                uuidString = String(data: data, encoding: .utf8)
            } else {
                uuidString = nil
            }
            guard let uuidString,
                  let sourceID = UUID(uuidString: uuidString),
                  sourceID != pane.id
            else { return }
            DispatchQueue.main.async {
                appState.movePane(from: sourceID, to: pane.id)
            }
        }
        return true
    }
}

// MARK: - Pane Empty State

struct PaneEmptyState: View {
    @EnvironmentObject var appState: AppState
    let pane: Pane

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.badge.plus")
                .font(.system(size: 28, weight: .ultraLight))
                .foregroundStyle(.quaternary)

            Text("Arraste um .md aqui")
                .font(.system(size: 12))
                .foregroundStyle(.quaternary)

            Button("Abrir") {
                let panel = NSOpenPanel()
                panel.allowedContentTypes = [
                    .init(filenameExtension: "md")!,
                    .init(filenameExtension: "markdown")!
                ].compactMap { $0 }
                panel.allowsMultipleSelection = false
                panel.canChooseDirectories = false
                guard panel.runModal() == .OK, let url = panel.url else { return }
                pane.load(url: url)
                appState.recentFiles = RecentFilesManager.add(url, to: appState.recentFiles)
                appState.objectWillChange.send()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Dividers

struct DividerHandle: View {
    var body: some View {
        Rectangle()
            .fill(Color(nsColor: .separatorColor))
            .frame(width: 1)
            .frame(maxHeight: .infinity)
            .overlay {
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: 8)
                    .contentShape(Rectangle())
                    .cursor(.resizeLeftRight)
            }
    }
}

struct PaneDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color(nsColor: .separatorColor))
            .frame(width: 1)
            .frame(maxHeight: .infinity)
    }
}

// MARK: - Welcome View

struct WelcomeView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 100, height: 100)

                Image(systemName: "doc.richtext")
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 8) {
                Text("Markdown Viewer")
                    .font(.system(size: 26, weight: .semibold, design: .rounded))

                Text("Abra um arquivo .md ou arraste para a janela")
                    .font(.system(size: 13))
                    .foregroundStyle(.tertiary)
            }

            Button {
                appState.showOpenPanel()
            } label: {
                Label("Abrir Arquivo", systemImage: "folder")
                    .font(.system(size: 13, weight: .medium))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(.accentColor)
            .controlSize(.large)

            HStack(spacing: 16) {
                hintBadge(icon: "command", text: "⌘O para abrir")
                hintBadge(icon: "cursorarrow.and.square.on.square.dashed", text: "Arraste arquivos")
            }
            .padding(.top, 4)

            Spacer()
            Spacer()
        }
    }

    private func hintBadge(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(text)
                .font(.system(size: 11))
        }
        .foregroundStyle(.quaternary)
    }
}

// MARK: - Cursor Extension

extension View {
    func cursor(_ cursor: NSCursor) -> some View {
        onHover { inside in
            if inside { cursor.push() }
            else { NSCursor.pop() }
        }
    }
}

// MARK: - FocusTrigger
// Walks the NSView hierarchy to find a FindNSTextField and make it first responder.

struct FocusTrigger: NSViewRepresentable {
    @Binding var focused: Bool

    func makeNSView(context: Context) -> NSView { NSView() }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard focused else { return }
        focused = false
        // Defer so the view tree is fully laid out before we search it
        DispatchQueue.main.async {
            guard let window = nsView.window else { return }
            if let field = findFindTextField(in: window.contentView) {
                window.makeFirstResponder(field)
            }
        }
    }

    private func findFindTextField(in view: NSView?) -> FindNSTextField? {
        guard let view else { return nil }
        if let f = view as? FindNSTextField { return f }
        for sub in view.subviews {
            if let found = findFindTextField(in: sub) { return found }
        }
        return nil
    }
}
