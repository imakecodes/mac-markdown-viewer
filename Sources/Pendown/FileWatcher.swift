import Foundation

/// Watches a single file for changes using GCD's `DispatchSource`.
/// Handles editors that write-then-rename (vim, Atom, VS Code) by re-watching
/// after rename/delete events.  Debounces rapid writes (150 ms).
final class FileWatcher {
    private var source: DispatchSourceFileSystemObject?
    private(set) var currentURL: URL?
    private var debounceWork: DispatchWorkItem?

    /// Called on the main thread when the file content changes.
    var onChange: (() -> Void)?

    // MARK: Public API

    func watch(url: URL) {
        stop()
        currentURL = url

        let fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else { return }

        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .delete, .extend],
            queue: .main
        )

        src.setEventHandler { [weak self] in
            guard let self else { return }

            // Debounce rapid events
            self.debounceWork?.cancel()
            let work = DispatchWorkItem { [weak self] in self?.onChange?() }
            self.debounceWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: work)

            // Editors like vim replace files via rename → re-watch
            if src.data.contains(.rename) || src.data.contains(.delete) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                    guard let self, let url = self.currentURL else { return }
                    self.watch(url: url)
                }
            }
        }

        // Each closure captures its own fd so cancellation never closes a
        // file descriptor that belongs to a later watch() call.
        src.setCancelHandler { close(fd) }

        self.source = src
        src.resume()
    }

    func stop() {
        debounceWork?.cancel()
        debounceWork = nil
        source?.cancel()
        source = nil
    }

    deinit { stop() }
}
