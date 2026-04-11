import SwiftUI
import AppKit

// MARK: - Pane Mode

enum PaneMode: Int, CaseIterable {
    case preview = 0
    case code    = 1
    case visual  = 2

    var icon: String {
        switch self {
        case .preview: return "eye"
        case .code:    return "chevron.left.forwardslash.chevron.right"
        case .visual:  return "pencil.and.outline"
        }
    }

    var label: String {
        switch self {
        case .preview: return L.preview
        case .code:    return L.code
        case .visual:  return L.visual
        }
    }
}

// MARK: - Pane

class Pane: ObservableObject, Identifiable {
    let id = UUID()
    @Published var fileURL: URL?
    @Published var markdownContent: String = ""
    @Published var fileName: String = ""
    @Published var isLive: Bool = true
    @Published var mode: PaneMode = .preview

    let watcher = FileWatcher()
    private var saveWork: DispatchWorkItem?

    func load(url: URL) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return }
        fileURL = url
        markdownContent = content
        fileName = url.lastPathComponent
        mode = .preview

        if isLive { startWatching() }
    }

    /// Re-reads the file from disk. Only updates `markdownContent` if it actually
    /// changed, avoiding unnecessary WebView reloads.
    func reload() {
        guard let url = fileURL else { return }
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        guard let content = try? String(contentsOf: url, encoding: .utf8),
              content != markdownContent else { return }
        markdownContent = content
    }

    func clear() {
        watcher.stop()
        fileURL = nil
        markdownContent = ""
        fileName = ""
        mode = .preview
    }

    // MARK: Mode switching

    func setMode(_ newMode: PaneMode) {
        let wasEditing = mode != .preview
        let willEdit   = newMode != .preview
        mode = newMode

        if willEdit && !wasEditing {
            // Entering edit mode → pause file watcher to avoid feedback loop
            watcher.stop()
        } else if !willEdit && wasEditing {
            // Leaving edit mode → restart watcher if live
            if isLive { startWatching() }
        }
    }

    // MARK: Content updates (from editors)

    /// Called by code/visual editors. Updates content + schedules debounced save.
    func updateContent(_ newContent: String) {
        guard newContent != markdownContent else { return }
        markdownContent = newContent
        scheduleSave()
    }

    private func scheduleSave() {
        saveWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.saveToDisk() }
        saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    func saveToDisk() {
        guard let url = fileURL else { return }
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        try? markdownContent.write(to: url, atomically: true, encoding: .utf8)
    }

    func toggleLive() {
        isLive.toggle()
        // Only start/stop watcher if we're in preview mode (not editing)
        if mode == .preview {
            if isLive { startWatching() } else { watcher.stop() }
        }
    }

    func startWatching() {
        guard let url = fileURL else { return }
        watcher.onChange = { [weak self] in self?.reload() }
        watcher.watch(url: url)
    }
}

class AppState: ObservableObject {
    static let maxPanes = 10

    @Published var panes: [Pane] = []
    @Published var activePaneID: UUID?
    @Published var recentFiles: [URL] = []

    /// Convenience: first pane's URL (used for window title)
    var windowTitle: String {
        if panes.isEmpty { return L.appName }
        if panes.count == 1 { return panes[0].fileName }
        return "\(panes.count) \(L.nFiles)"
    }

    @Published var workspaceFolders: [URL] = []
    private var accessingFolders: Set<URL> = []

    init() {
        recentFiles = RecentFilesManager.load()
        workspaceFolders = WorkspaceFolderManager.load()
        for folder in workspaceFolders {
            _ = folder.startAccessingSecurityScopedResource()
            accessingFolders.insert(folder)
        }
    }

    // MARK: Workspace folders

    func addWorkspaceFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = L.selectFolder
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard !workspaceFolders.contains(url) else { return }
        _ = url.startAccessingSecurityScopedResource()
        accessingFolders.insert(url)
        workspaceFolders.append(url)
        WorkspaceFolderManager.save(workspaceFolders)
    }

    func removeWorkspaceFolder(_ url: URL) {
        workspaceFolders.removeAll { $0 == url }
        if accessingFolders.contains(url) {
            url.stopAccessingSecurityScopedResource()
            accessingFolders.remove(url)
        }
        WorkspaceFolderManager.save(workspaceFolders)
    }

    /// Opens a file in the active pane, or creates a new pane if none exists
    func openFile(url: URL) {
        recentFiles = RecentFilesManager.add(url, to: recentFiles)

        if let activePaneID, let pane = panes.first(where: { $0.id == activePaneID }) {
            pane.load(url: url)
            objectWillChange.send()
        } else if let pane = panes.first {
            pane.load(url: url)
            activePaneID = pane.id
            objectWillChange.send()
        } else {
            let pane = Pane()
            pane.load(url: url)
            panes.append(pane)
            activePaneID = pane.id
        }
    }

    /// Opens a file in a new split pane
    func openInNewPane(url: URL) {
        guard panes.count < Self.maxPanes else { return }
        recentFiles = RecentFilesManager.add(url, to: recentFiles)
        let pane = Pane()
        pane.load(url: url)
        panes.append(pane)
        activePaneID = pane.id
    }

    /// Adds an empty pane and shows the open panel for it
    func addPane() {
        guard panes.count < Self.maxPanes else { return }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.init(filenameExtension: "md")!, .init(filenameExtension: "markdown")!].compactMap { $0 }
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = L.selectMdFile

        guard panel.runModal() == .OK, let url = panel.url else { return }
        openInNewPane(url: url)
    }

    /// Removes a pane and stops its file watcher
    func closePane(_ pane: Pane) {
        pane.watcher.stop()
        panes.removeAll { $0.id == pane.id }
        if activePaneID == pane.id {
            activePaneID = panes.last?.id
        }
    }

    func showOpenPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.init(filenameExtension: "md")!, .init(filenameExtension: "markdown")!].compactMap { $0 }
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = L.selectMdFile

        guard panel.runModal() == .OK, let url = panel.url else { return }
        openFile(url: url)
    }

    func clearRecents() {
        recentFiles = []
        RecentFilesManager.save([])
    }

    /// Moves a pane from its current position to just before the target pane
    func movePane(from sourceID: UUID, to targetID: UUID) {
        guard sourceID != targetID,
              let sourceIndex = panes.firstIndex(where: { $0.id == sourceID }),
              let targetIndex = panes.firstIndex(where: { $0.id == targetID }) else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            panes.move(fromOffsets: IndexSet(integer: sourceIndex),
                       toOffset: targetIndex < sourceIndex ? targetIndex : targetIndex + 1)
        }
    }
}
