# Pendown

A native macOS Markdown editor & viewer built with SwiftUI and WKWebView.

![macOS](https://img.shields.io/badge/macOS-13%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange)
![License](https://img.shields.io/badge/license-MIT-green)

## Features

- **Three modes** — Preview, Code Editor (syntax highlighting), and Visual WYSIWYG editor
- **Split panes** — open up to 10 files side by side
- **File browser** — VSCode-style folder navigation in the sidebar
- **Command palette** — `⌘K` to search actions, headings, and recent files
- **Live preview** — see changes as you type in code editor mode
- **Recent files** — sidebar groups files by directory, sorted alphabetically
- **Drag & drop** — drag `.md` files onto a pane or the window to open them
- **Mermaid diagrams** — renders `mermaid` fenced code blocks as diagrams
- **Dark mode** — full system dark/light mode support
- **Zoom** — `⌘+`, `⌘-`, `⌘0` or `Ctrl+scroll` to zoom in/out
- **Multi-language** — English (default) and Portuguese
- **In-document search** — `⌘F` with match highlighting and navigation
- **Tables, task lists, blockquotes** — full CommonMark + GFM support

## Requirements

- macOS 13 Ventura or later
- Xcode 15+ (for building from Xcode project)
- Or just Xcode Command Line Tools (for SPM builds)

## Download

Pre-built DMG releases are available on the [Releases](https://github.com/imakecodes/mac-markdown-viewer/releases) page.

Download the latest `Pendown-x.y.z.dmg`, open it and drag **Pendown.app** to your Applications folder.

> **macOS Gatekeeper notice**
> If the app is not notarized, macOS may block it on first launch.
>
> **To open it**, run this once in Terminal after dragging the app to Applications:
> ```bash
> xattr -cr /Applications/Pendown.app
> ```
> Alternatively, right-click the app → **Open** → **Open** in the dialog.

## Build from Source

### With Xcode (recommended for publishing)

```bash
make xcode              # generates Pendown.xcodeproj (requires: brew install xcodegen)
open Pendown.xcodeproj  # configure signing → Build & Run (⌘R)
```

To publish to the App Store: **Product → Archive** in Xcode.

### With Swift Package Manager

```bash
swift run        # build and launch
swift build      # build only
make bundle      # create .app bundle
make dmg         # create distributable DMG
make install     # install to /Applications
```

## Usage

| Action | How |
|--------|-----|
| Open file | `⌘O` or click **+** in the sidebar |
| Open in new pane | `⇧⌘O` |
| Command palette | `⌘K` |
| Find in document | `⌘F` |
| Switch mode | Click the mode selector (eye/code/pencil) |
| Split via drag | Drag a `.md` file onto an existing pane |
| Close pane | Hover the pane header → click **×** |
| Zoom in/out | `⌘+` / `⌘-` / `⌘0` or `Ctrl+scroll` |
| Change language | View → Language |

## Supported File Extensions

`.md` · `.markdown` · `.mdown` · `.mkd` · `.mkdn`

## Project Structure

```
Sources/Pendown/
  App.swift                  # NSApplicationDelegate, menu bar, window setup
  AppState.swift             # ObservableObject: panes, recent files, open/close
  ContentView.swift          # Root layout: sidebar + split pane container
  SidebarView.swift          # File browser + recent files
  Localization.swift         # i18n: English + Portuguese
  MarkdownHTMLRenderer.swift # swift-markdown MarkupWalker → HTML
  MarkdownWebView.swift      # WKWebView wrapper + HTML template (CSS, Mermaid)
  MarkdownCodeEditor.swift   # NSTextView code editor with syntax highlighting
  MarkdownVisualEditor.swift # WKWebView WYSIWYG editor with Turndown.js
  RecentFilesManager.swift   # UserDefaults persistence (security-scoped bookmarks)
  CommandPalette.swift       # ⌘K command palette
  FindBar.swift              # ⌘F search bar
  FileWatcher.swift          # FSEvents live reload
  LiquidGlass.swift          # Liquid glass styling
  Assets.xcassets/           # App icon + accent color
  Pendown.entitlements       # App Sandbox entitlements
  Info.plist                 # App metadata (Xcode builds)
  Info-SPM.plist             # App metadata (SPM/Makefile builds)
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
