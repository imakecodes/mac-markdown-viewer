import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var sidebarWidth: CGFloat = 240
    @State private var showCommandPalette = false

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                SidebarView()
                    .frame(width: sidebarWidth)
                    .frame(maxHeight: .infinity)

                DividerHandle()
                    .gesture(
                        DragGesture(minimumDistance: 1)
                            .onChanged { value in
                                let newWidth = sidebarWidth + value.translation.width
                                sidebarWidth = min(max(newWidth, 180), 400)
                            }
                    )

                if appState.panes.isEmpty {
                    WelcomeView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .onDrop(of: [.fileURL], isTargeted: nil) { handleDrop($0) }
                } else {
                    SplitPaneContainer()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // ── Command Palette ──
            if showCommandPalette {
                CommandPalette(isVisible: $showCommandPalette)
                    .environmentObject(appState)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleCommandPalette)) { _ in
            withAnimation(.easeOut(duration: 0.12)) {
                showCommandPalette.toggle()
            }
        }
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
    @State private var isHoveringHeader    = false
    @State private var isFileDropTargeted  = false
    @State private var showFindBar         = false
    @State private var findQuery           = ""
    @State private var findFocusRequest    = false
    @State private var editorSplitRatio: CGFloat = 0.5
    @StateObject private var findController    = FindController()
    @StateObject private var visualController  = VisualEditorController()

    var body: some View {
        VStack(spacing: 0) {
            // Pane header (only when multiple panes)
            if appState.panes.count > 1 {
                PaneHeader(pane: pane, isHovering: isHoveringHeader)
                    .onHover { isHoveringHeader = $0 }
            }

            // Content area
            ZStack {
                if pane.fileURL != nil {
                    paneContent
                } else {
                    PaneEmptyState(pane: pane)
                        .onDrop(of: [.fileURL], isTargeted: $isFileDropTargeted) { providers in
                            handleFileDrop(providers)
                        }
                }

                if isFileDropTargeted { fileDropOverlay }

                // Mode selector (top-left)
                if pane.fileURL != nil {
                    ModeSelector(pane: pane)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .padding(.top, 6)
                        .padding(.leading, 8)
                }

                // Find bar (top-right) — available in preview & code modes
                if showFindBar && pane.fileURL != nil && pane.mode != .visual {
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
            guard isActivePane, pane.fileURL != nil, pane.mode != .visual else { return }
            if showFindBar {
                findFocusRequest = true
            } else {
                showFindBar = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .scrollToHeading)) { note in
            guard isActivePane, pane.mode == .preview, let text = note.object as? String else { return }
            let escaped = text.replacingOccurrences(of: "\\", with: "\\\\")
                              .replacingOccurrences(of: "'", with: "\\'")
            findController.webView?.evaluateJavaScript("""
                (function() {
                    var headings = document.querySelectorAll('h1,h2,h3,h4,h5,h6');
                    for (var i = 0; i < headings.length; i++) {
                        if (headings[i].textContent.trim() === '\(escaped)') {
                            headings[i].scrollIntoView({ behavior: 'smooth', block: 'start' });
                            headings[i].style.transition = 'background 0.3s ease';
                            headings[i].style.background = 'var(--accent-soft)';
                            setTimeout(function() { headings[i].style.background = ''; }, 1800);
                            break;
                        }
                    }
                })()
            """, completionHandler: nil)
        }
    }

    private var isActivePane: Bool {
        appState.activePaneID == pane.id || appState.panes.count == 1
    }

    // MARK: Mode-dependent content

    @ViewBuilder
    private var paneContent: some View {
        switch pane.mode {
        case .preview:
            previewLayout

        case .code:
            codeLayout

        case .visual:
            visualLayout
        }
    }

    /// Full-width rendered preview (original behavior)
    private var previewLayout: some View {
        let htmlBody = MarkdownHTMLRenderer.renderHTML(from: pane.markdownContent)
        return MarkdownWebView(
            htmlContent: htmlBody,
            baseURL: pane.fileURL?.deletingLastPathComponent(),
            onDropTargeted: { targeted in
                withAnimation(.easeInOut(duration: 0.12)) { isFileDropTargeted = targeted }
            },
            onFileDrop: { url in
                pane.load(url: url)
                appState.activePaneID = pane.id
                appState.recentFiles = RecentFilesManager.add(url, to: appState.recentFiles)
                appState.objectWillChange.send()
            },
            findController: findController
        )
    }

    /// Side-by-side code editor + live preview
    private var codeLayout: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                // Code editor (left)
                MarkdownCodeEditor(text: Binding(
                    get: { pane.markdownContent },
                    set: { pane.updateContent($0) }
                ))
                .frame(width: geo.size.width * editorSplitRatio)

                // Draggable divider
                Rectangle()
                    .fill(Color(nsColor: .separatorColor))
                    .frame(width: 1)
                    .overlay {
                        Rectangle()
                            .fill(Color.clear)
                            .frame(width: 8)
                            .contentShape(Rectangle())
                            .cursor(.resizeLeftRight)
                    }
                    .gesture(
                        DragGesture(minimumDistance: 1, coordinateSpace: .named("editorSplit"))
                            .onChanged { value in
                                editorSplitRatio = min(max(value.location.x / geo.size.width, 0.25), 0.75)
                            }
                    )

                // Live preview (right)
                let htmlBody = MarkdownHTMLRenderer.renderHTML(from: pane.markdownContent)
                MarkdownWebView(
                    htmlContent: htmlBody,
                    baseURL: pane.fileURL?.deletingLastPathComponent(),
                    findController: findController
                )
                .frame(maxWidth: .infinity)
            }
            .coordinateSpace(name: "editorSplit")
        }
    }

    /// Visual WYSIWYG editor with floating toolbar
    private var visualLayout: some View {
        ZStack(alignment: .top) {
            let htmlBody = MarkdownHTMLRenderer.renderHTML(from: pane.markdownContent)
            MarkdownVisualEditor(
                htmlContent: htmlBody,
                baseURL: pane.fileURL?.deletingLastPathComponent(),
                controller: visualController,
                onContentChanged: { md in pane.updateContent(md) }
            )

            // Floating formatting toolbar (top center)
            VisualEditorToolbar(controller: visualController)
                .padding(.top, 6)
        }
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
                Text(L.openInNewPaneOverlay)
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

// MARK: - Mode Selector

struct ModeSelector: View {
    @ObservedObject var pane: Pane

    var body: some View {
        HStack(spacing: 0) {
            ForEach(PaneMode.allCases, id: \.rawValue) { mode in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        pane.setMode(mode)
                    }
                } label: {
                    Image(systemName: mode.icon)
                        .font(.system(size: 10, weight: pane.mode == mode ? .bold : .regular))
                        .foregroundStyle(pane.mode == mode ? Color.accentColor : .secondary)
                        .frame(width: 28, height: 22)
                        .contentShape(Rectangle())
                        .background(
                            pane.mode == mode
                                ? Color.accentColor.opacity(0.12)
                                : Color.clear
                        )
                }
                .buttonStyle(.plain)
                .help(mode.label)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .liquidGlass(cornerRadius: 7)
    }
}

// MARK: - Pane Header

struct PaneHeader: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var pane: Pane
    let isHovering: Bool
    @State private var isPaneDropTargeted = false
    @State private var livePulse = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "grip.horizontal")
                .font(.system(size: 7))
                .foregroundStyle(.quaternary)
                .padding(.leading, -2)

            Image(systemName: "doc.text")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)

            Text(pane.fileName.isEmpty ? L.empty : pane.fileName)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
                .truncationMode(.middle)

            // Live indicator dot
            if pane.fileURL != nil {
                Button {
                    pane.toggleLive()
                } label: {
                    Circle()
                        .fill(pane.isLive ? Color.green : Color.gray.opacity(0.4))
                        .frame(width: 6, height: 6)
                        .scaleEffect(livePulse && pane.isLive ? 1.4 : 1.0)
                        .opacity(livePulse && pane.isLive ? 0.5 : 1.0)
                        .animation(
                            pane.isLive
                                ? .easeInOut(duration: 1.5).repeatForever(autoreverses: true)
                                : .default,
                            value: livePulse
                        )
                }
                .buttonStyle(.plain)
                .help(pane.isLive ? L.liveReloadActive : L.liveReloadInactive)
                .onAppear { livePulse = true }
            }

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
                .help(L.swapFile)

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
                .help(L.closePaneTooltip)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .liquidGlassBar()
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

            Text(L.dragMdHere)
                .font(.system(size: 12))
                .foregroundStyle(.quaternary)

            Button(L.open) {
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
                Image(systemName: "doc.richtext")
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(.secondary)
                    .frame(width: 100, height: 100)
                    .liquidGlass(cornerRadius: 28)
            }

            VStack(spacing: 8) {
                Text(L.appName)
                    .font(.system(size: 26, weight: .semibold, design: .rounded))

                Text(L.openMdOrDrag)
                    .font(.system(size: 13))
                    .foregroundStyle(.tertiary)
            }

            Button {
                appState.showOpenPanel()
            } label: {
                Label(L.openFileLabel, systemImage: "folder")
                    .font(.system(size: 13, weight: .semibold))
                    .padding(.horizontal, 22)
                    .padding(.vertical, 9)
                    .liquidGlass(cornerRadius: 10)
            }
            .buttonStyle(.plain)

            HStack(spacing: 16) {
                hintBadge(icon: "command", text: L.cmdOToOpen)
                hintBadge(icon: "cursorarrow.and.square.on.square.dashed", text: L.dragFiles)
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
