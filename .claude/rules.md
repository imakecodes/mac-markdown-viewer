# Project Rules — mac-md-viewer

## Stack
- **Language**: Swift 5.9+, targeting macOS 13+
- **UI Framework**: SwiftUI with AppKit interop (NSViewRepresentable, NSWindow, NSApplication delegate)
- **Markdown parsing**: `apple/swift-markdown` package (`import Markdown`)
- **Web rendering**: WKWebView wrapped in `MarkdownWebView` (NSViewRepresentable)
- **Build**: Swift Package Manager (`swift build`, `swift run`)
- **Distribution**: DMG via `scripts/create-dmg.sh`

## Architecture
- **`AppState`** — single `ObservableObject` shared via `.environmentObject`. One source of truth for panes and recent files.
- **`Pane`** — `ObservableObject` + `Identifiable`, owns one file's content. Never share state between panes.
- **`RecentFilesManager`** — stateless helper using `UserDefaults` with security-scoped bookmarks. Always call `save()` after mutations.
- **`MarkdownHTMLRenderer`** — pure value-type `MarkupWalker`, no side effects. Extend here for new block/inline types.
- **`MarkdownWebView`** — only reloads when `htmlContent` or `baseURL` actually changes (coordinator cache). Do not trigger reloads for unrelated state.
- **`DropAwareWebView`** — handles *AppKit/Finder* drag-and-drop at the `NSDraggingDestination` level. SwiftUI `.onDrop` handles sidebar (SwiftUI) drags at the SwiftUI layer.

## Drag-and-Drop Rules
- The whole-window `.onDrop` **must not** be placed on the outermost `HStack` in `ContentView`. It must be scoped:
  - `WelcomeView` (no panes): `.onDrop` → `openFile` (creates first pane)
  - `SplitPaneContainer` (panes exist): `.onDrop` → `openInNewPane` (creates split)
  - Individual `PaneView` with a loaded file: handled exclusively by `DropAwareWebView` (AppKit layer)
  - Empty pane (`PaneEmptyState`): handled by SwiftUI `.onDrop` on the empty state view
- Scoping prevents the full window from acting as a global drop zone (which causes the "overlay on everything" artifact)

## Sidebar Rules
- Recent files are grouped **by parent directory**, directories sorted alphabetically, files within each directory sorted alphabetically (case-insensitive).
- This grouping is a pure computed property derived from `appState.recentFiles` — it is dynamic and requires no extra state.
- When a directory has no more recent files, its header disappears automatically (no explicit removal needed).
- `RecentFileRow` accepts `showDirectory: Bool = true`; pass `false` when rendering inside a directory group header.

## Mermaid Diagrams
- Code blocks with language `mermaid` are rendered as `<div class="mermaid">` (not `<pre><code>`).
- Mermaid is loaded from jsDelivr CDN (`mermaid@11`). Theme is chosen at runtime based on `prefers-color-scheme`.
- The init script must run **after** `<body>` content so that `.mermaid` divs already exist.

## Code Style
- Prefer `withAnimation(.easeInOut(duration:))` over bare state mutations when the result is visible.
- Use `DispatchQueue.main.async` for all UI updates from `NSItemProvider.loadItem` callbacks.
- Security-scoped resource access: always `startAccessingSecurityScopedResource()` / `stopAccessingSecurityScopedResource()` around file reads.
- Maximum panes: `AppState.maxPanes = 10`. Guard this at every entry point that adds a pane.
- Supported extensions: `["md", "markdown", "mdown", "mkd", "mkdn"]` — keep this list consistent across all drop/open handlers.

## Adding New Features
- New markdown block types → add `visitXxx` to `MarkdownHTMLRenderer`.
- New CSS → add to the `wrapInHTMLPage` template in `MarkdownWebView`, respecting `--variable` tokens for dark/light mode.
- New pane-level actions → add to `AppState` and call from `PaneView` or `PaneHeader`.
- New sidebar actions → add to `SidebarView`; update `RecentFilesManager` if persistence is needed.

## What NOT to Do
- Do not add a global `.onDrop` to `ContentView`'s outer `HStack` — it causes the whole window (including sidebar) to become a drop zone.
- Do not call `appState.objectWillChange.send()` unless you mutated a sub-object (like `Pane`) that SwiftUI can't observe automatically.
- Do not load files synchronously on the main thread if they could be large.
- Do not bypass `RecentFilesManager.save()` after mutating `appState.recentFiles`.
