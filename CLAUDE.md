# CLAUDE.md — Pendown

macOS Markdown editor & viewer built with SwiftUI + WKWebView. Supports split panes, code editor, visual WYSIWYG editor, file browser, live preview, Mermaid diagrams, and dark mode.

## Documentation

| File | Purpose |
| --- | --- |
| [.claude/rules.md](.claude/rules.md) | Architecture decisions, coding conventions, drag-and-drop rules, do/don't list |

## Quick Reference

```
Sources/Pendown/
  App.swift                  # NSApplicationDelegate, menu bar, window setup
  AppState.swift             # ObservableObject: panes, recent files, open/close actions
  ContentView.swift          # Root layout: sidebar + split pane container + drop handling
  SidebarView.swift          # File browser + recent files; FileTreeNode
  Localization.swift         # i18n: English (default) + Portuguese
  MarkdownHTMLRenderer.swift # swift-markdown MarkupWalker → HTML string
  MarkdownWebView.swift      # WKWebView wrapper + HTML template (CSS, Mermaid)
  MarkdownCodeEditor.swift   # NSTextView code editor with syntax highlighting
  MarkdownVisualEditor.swift # WKWebView WYSIWYG editor with Turndown.js
  RecentFilesManager.swift   # UserDefaults persistence with security-scoped bookmarks
  CommandPalette.swift       # ⌘K command palette (actions, headings, recents)
  FindBar.swift              # ⌘F in-document search
  FileWatcher.swift          # FSEvents live reload
  LiquidGlass.swift          # Liquid glass styling modifier
```

## Build & Run

```bash
swift run           # build and launch (SPM)
swift build         # build only
make xcode          # generate Pendown.xcodeproj (requires xcodegen)
make bundle         # create .app bundle
make dmg            # create distributable DMG
```

## Xcode

```bash
make xcode          # generates Pendown.xcodeproj via xcodegen
open Pendown.xcodeproj
# → Configure signing team in Xcode → Build & Run (⌘R)
# → Product → Archive for App Store submission
```
