import SwiftUI
import AppKit

let appState = AppState()

@main
struct PendownApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation {
    var window: NSWindow!

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMenuBar()

        let contentView = ContentView().environmentObject(appState)
        let hostingView = NSHostingView(rootView: contentView)

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 960, height: 680),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = L.appName
        window.minSize = NSSize(width: 480, height: 360)
        window.contentView = hostingView
        window.titlebarAppearsTransparent = false
        window.titleVisibility = .visible
        window.isReleasedWhenClosed = false
        window.center()
        window.setFrameAutosaveName("MainWindow")
        window.makeKeyAndOrderFront(nil)
        window.collectionBehavior.insert(.fullScreenPrimary)

        NSApplication.shared.activate(ignoringOtherApps: true)

        // Rebuild menus when language changes
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleLanguageChange),
            name: .languageChanged, object: nil
        )
    }

    @objc private func handleLanguageChange() {
        buildMenuBar()
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        let mdURLs = urls.filter { ["md", "markdown", "mdown", "mkd", "mkdn"].contains($0.pathExtension.lowercased()) }
        if mdURLs.count == 1 {
            appState.openFile(url: mdURLs[0])
        } else {
            for url in mdURLs {
                appState.openInNewPane(url: url)
            }
        }
        window?.title = appState.windowTitle
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }

    // MARK: - Menu construction

    func buildMenuBar() {
        let mainMenu = NSMenu()
        appMenu(menu: mainMenu)
        fileMenu(menu: mainMenu)
        editMenu(menu: mainMenu)
        findMenu(menu: mainMenu)
        viewMenu(menu: mainMenu)
        windowMenu(menu: mainMenu)
        NSApplication.shared.mainMenu = mainMenu
    }

    private func appMenu(menu mainMenu: NSMenu) {
        let appMenu = NSMenu()
        let appItem = NSMenuItem()
        appItem.submenu = appMenu
        appMenu.addItem(withTitle: L.about, action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: L.quit, action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        mainMenu.addItem(appItem)
    }

    private func fileMenu(menu mainMenu: NSMenu) {
        let fileMenu = NSMenu(title: L.fileMenu)
        fileMenu.autoenablesItems = false
        let fileItem = NSMenuItem()
        fileItem.submenu = fileMenu

        let openItem = NSMenuItem(title: L.openFile, action: #selector(openFile), keyEquivalent: "o")
        openItem.target = self
        fileMenu.addItem(openItem)

        let splitItem = NSMenuItem(title: L.openInNewPane, action: #selector(openInNewPane), keyEquivalent: "o")
        splitItem.keyEquivalentModifierMask = [.command, .shift]
        splitItem.target = self
        splitItem.isEnabled = true
        fileMenu.addItem(splitItem)

        let closeDocItem = NSMenuItem(title: L.closeDocument, action: #selector(closeActiveDocument), keyEquivalent: "w")
        closeDocItem.keyEquivalentModifierMask = [.command]
        closeDocItem.target = self
        closeDocItem.isEnabled = true
        fileMenu.addItem(closeDocItem)

        let closePaneItem = NSMenuItem(title: L.closePane, action: #selector(closeActivePane), keyEquivalent: "w")
        closePaneItem.keyEquivalentModifierMask = [.command, .shift]
        closePaneItem.target = self
        closePaneItem.isEnabled = true
        fileMenu.addItem(closePaneItem)

        fileMenu.addItem(.separator())

        let recentsItem = NSMenuItem(title: L.recents, action: nil, keyEquivalent: "")
        let recentsMenu = NSMenu(title: L.recents)
        recentsItem.submenu = recentsMenu
        fileMenu.addItem(recentsItem)

        mainMenu.addItem(fileItem)
    }

    private func editMenu(menu mainMenu: NSMenu) {
        let editMenu = NSMenu(title: L.editMenu)
        let editItem = NSMenuItem()
        editItem.submenu = editMenu
        editMenu.addItem(withTitle: L.undo, action: Selector(("undo:")), keyEquivalent: "z")
        let redoItem = NSMenuItem(title: L.redo, action: Selector(("redo:")), keyEquivalent: "z")
        redoItem.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(redoItem)
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: L.cut, action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: L.copy, action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: L.paste, action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: L.selectAll, action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        mainMenu.addItem(editItem)
    }

    private func findMenu(menu mainMenu: NSMenu) {
        let findMenu = NSMenu(title: L.findMenu)
        findMenu.autoenablesItems = false
        let findItem = NSMenuItem()
        findItem.submenu = findMenu

        let searchItem = NSMenuItem(title: L.findEllipsis, action: #selector(activateFind), keyEquivalent: "f")
        searchItem.target = self
        searchItem.isEnabled = true
        findMenu.addItem(searchItem)

        let nextItem = NSMenuItem(title: L.nextResult, action: #selector(findNextResult), keyEquivalent: "g")
        nextItem.target = self
        nextItem.isEnabled = true
        findMenu.addItem(nextItem)

        let prevItem = NSMenuItem(title: L.previousResult, action: #selector(findPrevResult), keyEquivalent: "G")
        prevItem.keyEquivalentModifierMask = [.command, .shift]
        prevItem.target = self
        prevItem.isEnabled = true
        findMenu.addItem(prevItem)

        mainMenu.addItem(findItem)
    }

    private func viewMenu(menu mainMenu: NSMenu) {
        let viewMenu = NSMenu(title: L.viewMenu)
        viewMenu.autoenablesItems = false
        let viewItem = NSMenuItem()
        viewItem.submenu = viewMenu

        let paletteItem = NSMenuItem(title: L.commandPalette, action: #selector(togglePalette), keyEquivalent: "k")
        paletteItem.target = self
        paletteItem.isEnabled = true
        viewMenu.addItem(paletteItem)

        viewMenu.addItem(.separator())

        // Language submenu
        let langItem = NSMenuItem(title: L.languageMenu, action: nil, keyEquivalent: "")
        let langMenu = NSMenu(title: L.languageMenu)
        for lang in Language.allCases {
            let item = NSMenuItem(title: lang.displayName, action: #selector(changeLanguage(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = lang
            item.state = Localization.shared.language == lang ? .on : .off
            langMenu.addItem(item)
        }
        langItem.submenu = langMenu
        viewMenu.addItem(langItem)

        viewMenu.addItem(.separator())

        let fullScreen = NSMenuItem(title: L.fullScreen, action: #selector(NSWindow.toggleFullScreen(_:)), keyEquivalent: "f")
        fullScreen.keyEquivalentModifierMask = [.control, .command]
        viewMenu.addItem(fullScreen)

        mainMenu.addItem(viewItem)
    }

    private func windowMenu(menu mainMenu: NSMenu) {
        let windowMenu = NSMenu(title: L.windowMenu)
        let windowItem = NSMenuItem()
        windowItem.submenu = windowMenu
        windowMenu.addItem(withTitle: L.minimize, action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        NSApplication.shared.windowsMenu = windowMenu
        mainMenu.addItem(windowItem)
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(openInNewPane):
            return appState.panes.count < AppState.maxPanes
        case #selector(closeActiveDocument):
            if let id = appState.activePaneID,
               let pane = appState.panes.first(where: { $0.id == id }) {
                return pane.fileURL != nil
            }
            return false
        case #selector(closeActivePane):
            return appState.panes.count > 0
        default:
            return true
        }
    }

    // MARK: - Actions

    @objc func openFile() { appState.showOpenPanel() }
    @objc func togglePalette() { NotificationCenter.default.post(name: .toggleCommandPalette, object: nil) }
    @objc func activateFind() { NotificationCenter.default.post(name: .activateFindBar, object: nil) }
    @objc func findNextResult() { NotificationCenter.default.post(name: .findNext, object: nil) }
    @objc func findPrevResult() { NotificationCenter.default.post(name: .findPrev, object: nil) }

    @objc func closeActiveDocument() {
        guard let activeID = appState.activePaneID,
              let pane = appState.panes.first(where: { $0.id == activeID }) else { return }
        if appState.panes.count == 1 {
            pane.clear()
            appState.objectWillChange.send()
        } else {
            appState.closePane(pane)
        }
    }

    @objc func openInNewPane() { appState.addPane() }

    @objc func closeActivePane() {
        guard let activeID = appState.activePaneID,
              let pane = appState.panes.first(where: { $0.id == activeID }) else { return }
        appState.closePane(pane)
    }

    @objc func changeLanguage(_ sender: NSMenuItem) {
        guard let lang = sender.representedObject as? Language else { return }
        Localization.shared.language = lang
    }
}
