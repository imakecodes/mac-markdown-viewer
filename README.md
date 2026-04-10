# Markdown Viewer

A lightweight, native macOS Markdown viewer built with SwiftUI and WKWebView.

![macOS](https://img.shields.io/badge/macOS-13%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange)
![License](https://img.shields.io/badge/license-MIT-green)

## Features

- **Split panes** — open up to 10 files side by side
- **Recent files** — sidebar groups files by directory, sorted alphabetically
- **Drag & drop** — drag `.md` files onto a pane or the window to open them
- **Mermaid diagrams** — renders `mermaid` fenced code blocks as diagrams
- **Dark mode** — full system dark/light mode support
- **Zoom** — `⌘+`, `⌘-`, `⌘0` or `Ctrl+scroll` to zoom in/out
- **Syntax highlighting** — code blocks with language labels
- **Tables, task lists, blockquotes** — full CommonMark + GFM support

## Requirements

- macOS 13 Ventura or later
- Xcode Command Line Tools or Xcode (for building from source)

## Download

Pre-built DMG releases are available on the [Releases](https://github.com/imakecodes/mac-markdown-viewer/releases) page.

Download the latest `MarkdownViewer-x.y.z.dmg`, open it and drag **Markdown Viewer.app** to your Applications folder.

> **macOS Gatekeeper notice**
> Because Markdown Viewer is not notarized with an Apple Developer certificate,
> macOS may show *"Markdown Viewer is damaged and can't be opened"* the first time.
> This is a false positive caused by the quarantine flag on downloaded files.
>
> **To open it**, run this once in Terminal after dragging the app to Applications:
> ```bash
> xattr -cr /Applications/"Markdown Viewer.app"
> ```
> Alternatively, right-click the app → **Open** → **Open** in the dialog.

## Build from Source

### Prerequisites

```bash
# Install Xcode Command Line Tools if needed
xcode-select --install
```

### Run

```bash
git clone https://github.com/imakecodes/mac-markdown-viewer.git
cd mac-markdown-viewer
swift run
```

### Build Release Binary

```bash
swift build -c release
```

### Create .app Bundle

```bash
make bundle
# Output: .build/Markdown\ Viewer.app
```

### Create Distributable DMG

```bash
make dmg
# Output: .build/MarkdownViewer.dmg
```

### Install to /Applications

```bash
make install
```

## Usage

| Action | How |
|--------|-----|
| Open file | `⌘O` or click **+** in the sidebar |
| Open in new pane | `⇧⌘O` or right-click → *Abrir em Novo Painel* |
| Split via drag | Drag a `.md` file onto an existing pane |
| Close pane | Hover the pane header → click **×** |
| Zoom in/out | `⌘+` / `⌘-` / `⌘0` or `Ctrl+scroll` |
| Show in Finder | Right-click a recent file → *Mostrar no Finder* |
| Clear recents | Click the trash icon in the sidebar |

## Supported File Extensions

`.md` · `.markdown` · `.mdown` · `.mkd` · `.mkdn`

## Project Structure

```
Sources/MarkdownViewer/
  App.swift                  # NSApplicationDelegate, menu bar, window setup
  AppState.swift             # ObservableObject: panes, recent files, open/close
  ContentView.swift          # Root layout: sidebar + split pane container
  SidebarView.swift          # Recent files grouped by directory
  MarkdownHTMLRenderer.swift # swift-markdown MarkupWalker → HTML
  MarkdownWebView.swift      # WKWebView wrapper + HTML template (CSS, Mermaid)
  RecentFilesManager.swift   # UserDefaults persistence (security-scoped bookmarks)
scripts/
  create-dmg.sh              # DMG packaging script
  create-dmg-background.swift # Generates DMG background image
```

## Contributing

Pull requests are welcome. For major changes, please open an issue first to discuss what you'd like to change.

1. Fork the repository
2. Create your branch (`git checkout -b feature/my-feature`)
3. Commit your changes (`git commit -m 'feat: add my feature'`)
4. Push to the branch (`git push origin feature/my-feature`)
5. Open a Pull Request

## License

[MIT](LICENSE)
