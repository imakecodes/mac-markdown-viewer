import Foundation

struct RecentFilesManager {
    private static let key = "recentFiles"
    private static let maxRecents = 15

    static func load() -> [URL] {
        guard let bookmarks = UserDefaults.standard.array(forKey: key) as? [Data] else {
            return []
        }
        return bookmarks.compactMap { data in
            var isStale = false
            guard let url = try? URL(resolvingBookmarkData: data, options: .withSecurityScope, bookmarkDataIsStale: &isStale) else {
                return nil
            }
            if isStale { return nil }
            return url
        }
    }

    static func save(_ urls: [URL]) {
        let bookmarks = urls.prefix(maxRecents).compactMap { url in
            try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
        }
        UserDefaults.standard.set(bookmarks, forKey: key)
    }

    static func add(_ url: URL, to existing: [URL]) -> [URL] {
        var urls = existing.filter { $0 != url }
        urls.insert(url, at: 0)
        if urls.count > maxRecents {
            urls = Array(urls.prefix(maxRecents))
        }
        save(urls)
        return urls
    }
}

// MARK: - Workspace Folder Manager

struct WorkspaceFolderManager {
    private static let key = "workspaceFolders"

    static func load() -> [URL] {
        guard let bookmarks = UserDefaults.standard.array(forKey: key) as? [Data] else {
            return []
        }
        return bookmarks.compactMap { data in
            var isStale = false
            guard let url = try? URL(resolvingBookmarkData: data, options: .withSecurityScope, bookmarkDataIsStale: &isStale) else {
                return nil
            }
            if isStale { return nil }
            return url
        }
    }

    static func save(_ urls: [URL]) {
        let bookmarks = urls.compactMap { url in
            try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
        }
        UserDefaults.standard.set(bookmarks, forKey: key)
    }
}

// MARK: - File Tree Node

struct FileTreeNode: Identifiable {
    let id: String
    let url: URL
    let name: String
    let isDirectory: Bool
    var children: [FileTreeNode]

    private static let mdExtensions: Set<String> = ["md", "markdown", "mdown", "mkd", "mkdn"]

    /// Recursively scans a directory for markdown files.
    /// Directories that contain no markdown files (recursively) are excluded.
    static func scan(_ root: URL) -> [FileTreeNode] {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var dirs: [FileTreeNode] = []
        var files: [FileTreeNode] = []

        for item in items {
            let isDir = (try? item.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            if isDir {
                let children = scan(item)
                if !children.isEmpty {
                    dirs.append(FileTreeNode(
                        id: item.path, url: item,
                        name: item.lastPathComponent,
                        isDirectory: true, children: children
                    ))
                }
            } else if mdExtensions.contains(item.pathExtension.lowercased()) {
                files.append(FileTreeNode(
                    id: item.path, url: item,
                    name: item.lastPathComponent,
                    isDirectory: false, children: []
                ))
            }
        }

        // Sort: directories first (alphabetical), then files (alphabetical)
        dirs.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        files.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        return dirs + files
    }
}
