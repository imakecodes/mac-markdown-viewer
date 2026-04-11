import SwiftUI
import UniformTypeIdentifiers

struct SidebarView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var loc = Localization.shared
    @State private var hoveredURL: URL?
    @State private var expandedPaths: Set<String> = []
    @State private var folderTreeCache: [URL: [FileTreeNode]] = [:]

    // Recent files grouped by parent directory
    private var groupedFiles: [(directory: URL, files: [URL])] {
        let grouped = Dictionary(grouping: appState.recentFiles) { $0.deletingLastPathComponent() }
        return grouped
            .map { key, value in
                let sorted = value.sorted {
                    $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending
                }
                return (directory: key, files: sorted)
            }
            .sorted {
                $0.directory.path.localizedCaseInsensitiveCompare($1.directory.path) == .orderedAscending
            }
    }

    private func directoryDisplayName(_ url: URL) -> String {
        url.path.replacingOccurrences(of: NSHomeDirectory(), with: "~")
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── Action buttons ──
            HStack(spacing: 6) {
                // Add folder
                Button {
                    appState.addWorkspaceFolder()
                    refreshAllFolders()
                } label: {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 26, height: 26)
                        .liquidGlass(cornerRadius: 6)
                }
                .buttonStyle(.plain)
                .help(loc.addFolder)

                // Open file
                Button {
                    appState.showOpenPanel()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 26, height: 26)
                        .liquidGlass(cornerRadius: 6)
                }
                .buttonStyle(.plain)
                .help(loc.openFileTooltip)

                if appState.panes.count < AppState.maxPanes {
                    Button {
                        appState.addPane()
                    } label: {
                        Image(systemName: "rectangle.split.1x2")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(width: 26, height: 26)
                            .liquidGlass(cornerRadius: 6)
                    }
                    .buttonStyle(.plain)
                    .help(loc.openInNewPaneTooltip)
                }

                Spacer()

                if !appState.panes.isEmpty {
                    Text("\(appState.panes.count)/\(AppState.maxPanes)")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(.quaternary)
                }

                if !appState.recentFiles.isEmpty {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            appState.clearRecents()
                        }
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                    .help(loc.clearRecents)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 6)

            ScrollView {
                LazyVStack(spacing: 0) {
                    // ── Folders section ──
                    folderSection

                    // ── Recents section ──
                    recentsSection
                }
            }
        }
        .background(.ultraThinMaterial)
        .onAppear { refreshAllFolders() }
    }

    // MARK: - Folders Section

    @ViewBuilder
    private var folderSection: some View {
        // Section header
        sectionHeader(loc.folders)

        if appState.workspaceFolders.isEmpty {
            // Empty state
            VStack(spacing: 8) {
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 18, weight: .ultraLight))
                    .foregroundStyle(.quaternary)
                Text(loc.noFolders)
                    .font(.system(size: 11))
                    .foregroundStyle(.quaternary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        } else {
            ForEach(appState.workspaceFolders, id: \.path) { folder in
                workspaceFolderView(folder)
            }
        }
    }

    private func workspaceFolderView(_ folder: URL) -> some View {
        VStack(spacing: 0) {
            // Workspace folder header (always visible, acts as root)
            HStack(spacing: 5) {
                Button {
                    toggleExpand(folder.path)
                } label: {
                    Image(systemName: expandedPaths.contains(folder.path) ? "chevron.down" : "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.tertiary)
                        .frame(width: 12)
                }
                .buttonStyle(.plain)

                Image(systemName: expandedPaths.contains(folder.path) ? "folder.fill" : "folder")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)

                Text(folder.lastPathComponent)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()

                // Remove folder button (subtle)
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        folderTreeCache.removeValue(forKey: folder)
                        appState.removeWorkspaceFolder(folder)
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.quaternary)
                }
                .buttonStyle(.plain)
                .help(loc.removeFolder)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
            .onTapGesture { toggleExpand(folder.path) }
            .contextMenu {
                Button { refreshFolder(folder) } label: {
                    Label(loc.refreshFolder, systemImage: "arrow.clockwise")
                }
                Button {
                    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: folder.path)
                } label: {
                    Label(loc.showInFinder, systemImage: "folder")
                }
                Divider()
                Button(role: .destructive) {
                    withAnimation {
                        folderTreeCache.removeValue(forKey: folder)
                        appState.removeWorkspaceFolder(folder)
                    }
                } label: {
                    Label(loc.removeFolder, systemImage: "folder.badge.minus")
                }
            }

            // Children (tree)
            if expandedPaths.contains(folder.path) {
                let nodes = folderTreeCache[folder] ?? []
                ForEach(nodes) { node in
                    fileTreeRow(node, depth: 1)
                }
            }
        }
    }

    // File tree row (wraps the recursive struct)
    private func fileTreeRow(_ node: FileTreeNode, depth: Int) -> some View {
        FileTreeRowView(
            node: node, depth: depth,
            expandedPaths: $expandedPaths,
            hoveredURL: $hoveredURL
        )
    }

    // MARK: - Recents Section

    @ViewBuilder
    private var recentsSection: some View {
        sectionHeader(loc.recents)

        if appState.recentFiles.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "clock")
                    .font(.system(size: 18, weight: .ultraLight))
                    .foregroundStyle(.quaternary)
                Text(loc.noRecentFiles)
                    .font(.system(size: 11))
                    .foregroundStyle(.quaternary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        } else {
            ForEach(groupedFiles, id: \.directory) { group in
                HStack(spacing: 5) {
                    Image(systemName: "folder")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.tertiary)
                    Text(directoryDisplayName(group.directory))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 2)

                ForEach(group.files, id: \.self) { url in
                    RecentFileRow(
                        url: url,
                        isSelected: appState.panes.contains(where: { $0.fileURL == url }),
                        isHovered: hoveredURL == url,
                        showDirectory: false
                    )
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            appState.openFile(url: url)
                        }
                    }
                    .onHover { inside in
                        withAnimation(.easeInOut(duration: 0.1)) {
                            hoveredURL = inside ? url : nil
                        }
                    }
                    .onDrag {
                        NSItemProvider(object: url as NSURL)
                    }
                    .contextMenu {
                        Button {
                            appState.openFile(url: url)
                        } label: {
                            Label(loc.open, systemImage: "doc.text")
                        }
                        if appState.panes.count < AppState.maxPanes {
                            Button {
                                appState.openInNewPane(url: url)
                            } label: {
                                Label(loc.openInNewPane, systemImage: "rectangle.split.1x2")
                            }
                        }
                        Divider()
                        Button {
                            NSWorkspace.shared.activateFileViewerSelecting([url])
                        } label: {
                            Label(loc.showInFinder, systemImage: "folder")
                        }
                        Divider()
                        Button(role: .destructive) {
                            withAnimation {
                                appState.recentFiles.removeAll { $0 == url }
                                RecentFilesManager.save(appState.recentFiles)
                            }
                        } label: {
                            Label(loc.removeFromRecents, systemImage: "xmark.circle")
                        }
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.quaternary)
                .tracking(0.8)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 6)
    }

    private func toggleExpand(_ path: String) {
        withAnimation(.easeInOut(duration: 0.15)) {
            if expandedPaths.contains(path) {
                expandedPaths.remove(path)
            } else {
                expandedPaths.insert(path)
            }
        }
    }

    private func refreshAllFolders() {
        for folder in appState.workspaceFolders {
            refreshFolder(folder)
            // Auto-expand root folders
            expandedPaths.insert(folder.path)
        }
    }

    private func refreshFolder(_ folder: URL) {
        let accessing = folder.startAccessingSecurityScopedResource()
        let nodes = FileTreeNode.scan(folder)
        if accessing { folder.stopAccessingSecurityScopedResource() }
        folderTreeCache[folder] = nodes
    }
}

// MARK: - File Tree Row (recursive)

struct FileTreeRowView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var loc = Localization.shared
    let node: FileTreeNode
    let depth: Int
    @Binding var expandedPaths: Set<String>
    @Binding var hoveredURL: URL?

    var body: some View {
        if node.isDirectory {
            directoryRow
        } else {
            fileRow
        }
    }

    private var directoryRow: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                Image(systemName: expandedPaths.contains(node.id) ? "chevron.down" : "chevron.right")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(.quaternary)
                    .frame(width: 10)

                Image(systemName: expandedPaths.contains(node.id) ? "folder.fill" : "folder")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)

                Text(node.name)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()
            }
            .padding(.leading, CGFloat(depth) * 14 + 12)
            .padding(.trailing, 12)
            .padding(.vertical, 3)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.15)) {
                    if expandedPaths.contains(node.id) {
                        expandedPaths.remove(node.id)
                    } else {
                        expandedPaths.insert(node.id)
                    }
                }
            }
            .contextMenu {
                Button {
                    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: node.url.path)
                } label: {
                    Label(loc.showInFinder, systemImage: "folder")
                }
            }

            if expandedPaths.contains(node.id) {
                ForEach(node.children) { child in
                    FileTreeRowView(
                        node: child, depth: depth + 1,
                        expandedPaths: $expandedPaths,
                        hoveredURL: $hoveredURL
                    )
                }
            }
        }
    }

    private var fileRow: some View {
        let isSelected = appState.panes.contains { $0.fileURL == node.url }
        let isHovered = hoveredURL == node.url

        return HStack(spacing: 5) {
            Image(systemName: "doc.text")
                .font(.system(size: 9))
                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)

            Text(node.name.replacingOccurrences(of: ".md", with: ""))
                .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? Color.accentColor : .primary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()
        }
        .padding(.leading, CGFloat(depth) * 14 + 12)
        .padding(.trailing, 12)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(
                    isSelected ? Color.accentColor.opacity(0.10)
                    : isHovered ? Color.primary.opacity(0.04)
                    : Color.clear
                )
                .padding(.horizontal, 6)
        )
        .contentShape(Rectangle())
        .onTapGesture { appState.openFile(url: node.url) }
        .onHover { inside in
            withAnimation(.easeInOut(duration: 0.1)) {
                hoveredURL = inside ? node.url : nil
            }
        }
        .onDrag { NSItemProvider(object: node.url as NSURL) }
        .contextMenu {
            Button {
                appState.openFile(url: node.url)
            } label: {
                Label(loc.open, systemImage: "doc.text")
            }
            if appState.panes.count < AppState.maxPanes {
                Button {
                    appState.openInNewPane(url: node.url)
                } label: {
                    Label(loc.openInNewPane, systemImage: "rectangle.split.1x2")
                }
            }
            Divider()
            Button {
                NSWorkspace.shared.activateFileViewerSelecting([node.url])
            } label: {
                Label(loc.showInFinder, systemImage: "folder")
            }
        }
    }
}

// MARK: - Recent File Row

struct RecentFileRow: View {
    let url: URL
    let isSelected: Bool
    let isHovered: Bool
    var showDirectory: Bool = true

    private var shortenedPath: String {
        url.deletingLastPathComponent().path
            .replacingOccurrences(of: NSHomeDirectory(), with: "~")
    }

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.primary.opacity(0.04))
                    .frame(width: 30, height: 30)

                Image(systemName: "doc.text")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(url.deletingPathExtension().lastPathComponent)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)

                if showDirectory {
                    Text(shortenedPath)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(
                    isSelected
                        ? Color.accentColor.opacity(0.12)
                        : isHovered
                            ? Color.primary.opacity(0.04)
                            : Color.clear
                )
        )
        .contentShape(Rectangle())
    }
}
