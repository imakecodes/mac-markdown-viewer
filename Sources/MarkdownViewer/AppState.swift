import SwiftUI
import AppKit

class Pane: ObservableObject, Identifiable {
    let id = UUID()
    @Published var fileURL: URL?
    @Published var markdownContent: String = ""
    @Published var fileName: String = ""

    func load(url: URL) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return }
        fileURL = url
        markdownContent = content
        fileName = url.lastPathComponent
    }

    func clear() {
        fileURL = nil
        markdownContent = ""
        fileName = ""
    }
}

class AppState: ObservableObject {
    static let maxPanes = 10

    @Published var panes: [Pane] = []
    @Published var activePaneID: UUID?
    @Published var recentFiles: [URL] = []

    /// Convenience: first pane's URL (used for window title)
    var windowTitle: String {
        if panes.isEmpty { return "Markdown Viewer" }
        if panes.count == 1 { return panes[0].fileName }
        return "\(panes.count) arquivos"
    }

    init() {
        recentFiles = RecentFilesManager.load()
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
        panel.message = "Selecione um arquivo Markdown"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        openInNewPane(url: url)
    }

    /// Removes a pane
    func closePane(_ pane: Pane) {
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
        panel.message = "Selecione um arquivo Markdown"

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
