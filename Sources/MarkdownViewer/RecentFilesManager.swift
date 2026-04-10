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
