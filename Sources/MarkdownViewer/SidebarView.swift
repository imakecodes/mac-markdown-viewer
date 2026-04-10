import SwiftUI
import UniformTypeIdentifiers

struct SidebarView: View {
    @EnvironmentObject var appState: AppState
    @State private var hoveredURL: URL?

    // Files grouped by parent directory, directories and files sorted alphabetically.
    // Recomputes automatically whenever recentFiles changes.
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
            // Action buttons
            HStack(spacing: 6) {
                Button {
                    appState.showOpenPanel()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 24, height: 24)
                        .background(Color.primary.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
                .help("Abrir arquivo (⌘O)")

                if appState.panes.count < AppState.maxPanes {
                    Button {
                        appState.addPane()
                    } label: {
                        Image(systemName: "rectangle.split.1x2")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(width: 24, height: 24)
                            .background(Color.primary.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                    }
                    .buttonStyle(.plain)
                    .help("Abrir em novo painel (⇧⌘O)")
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
                    .help("Limpar recentes")
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 6)

            // Header
            HStack {
                Text("Recentes")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 6)

            Divider()
                .padding(.horizontal, 12)

            if appState.recentFiles.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "clock")
                        .font(.system(size: 24, weight: .ultraLight))
                        .foregroundStyle(.quaternary)
                    Text("Nenhum arquivo recente")
                        .font(.system(size: 12))
                        .foregroundStyle(.quaternary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(groupedFiles, id: \.directory) { group in
                            // Directory section header
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
                            .padding(.top, 10)
                            .padding(.bottom, 2)

                            // Files in this directory, already sorted alphabetically
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
                                        Label("Abrir", systemImage: "doc.text")
                                    }
                                    if appState.panes.count < AppState.maxPanes {
                                        Button {
                                            appState.openInNewPane(url: url)
                                        } label: {
                                            Label("Abrir em Novo Painel", systemImage: "rectangle.split.1x2")
                                        }
                                    }
                                    Divider()
                                    Button {
                                        NSWorkspace.shared.activateFileViewerSelecting([url])
                                    } label: {
                                        Label("Mostrar no Finder", systemImage: "folder")
                                    }
                                    Divider()
                                    Button(role: .destructive) {
                                        withAnimation {
                                            appState.recentFiles.removeAll { $0 == url }
                                            RecentFilesManager.save(appState.recentFiles)
                                        }
                                    } label: {
                                        Label("Remover dos Recentes", systemImage: "xmark.circle")
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                }
            }
        }
        .background(.ultraThinMaterial)
    }
}

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
            // File icon
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
