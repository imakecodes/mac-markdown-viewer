# CLAUDE.md — mac-md-viewer

macOS Markdown viewer built with SwiftUI + WKWebView. Supports split panes, recent files, drag-and-drop, Mermaid diagrams, and dark mode.

## Documentation

| File | Purpose |
|---|---|
| [.claude/rules.md](.claude/rules.md) | Architecture decisions, coding conventions, drag-and-drop rules, do/don't list |

## Quick Reference

```
Sources/MarkdownViewer/
  App.swift                  # NSApplicationDelegate, menu bar, window setup
  AppState.swift             # ObservableObject: panes, recent files, open/close actions
  ContentView.swift          # Root layout: sidebar + split pane container + drop handling
  SidebarView.swift          # Recent files grouped by directory; RecentFileRow
  MarkdownHTMLRenderer.swift # swift-markdown MarkupWalker → HTML string
  MarkdownWebView.swift      # WKWebView wrapper + HTML template (CSS, Mermaid)
  RecentFilesManager.swift   # UserDefaults persistence with security-scoped bookmarks
```

## Build & Run

```bash
swift run          # build and launch
swift build        # build only
make               # see Makefile for DMG packaging targets
```
