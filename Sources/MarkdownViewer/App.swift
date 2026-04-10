import SwiftUI
import AppKit

let appState = AppState()

@main
struct MarkdownViewerApp {
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
        // Build the menu bar
        let mainMenu = NSMenu()
        app(menu: mainMenu)
        fileMenu(menu: mainMenu)
        findMenu(menu: mainMenu)
        editMenu(menu: mainMenu)
        viewMenu(menu: mainMenu)
        windowMenu(menu: mainMenu)
        NSApplication.shared.mainMenu = mainMenu

        // Create the main window
        let contentView = ContentView().environmentObject(appState)
        let hostingView = NSHostingView(rootView: contentView)

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 960, height: 680),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Markdown Viewer"
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
    }

    /// Called when files are opened via Finder (double-click, "Open With", drag onto dock icon)
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

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }

    // MARK: - Menu construction

    private func app(menu mainMenu: NSMenu) {
        let appMenu = NSMenu()
        let appItem = NSMenuItem()
        appItem.submenu = appMenu
        appMenu.addItem(withTitle: "Sobre Markdown Viewer", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Encerrar Markdown Viewer", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        mainMenu.addItem(appItem)
    }

    private func fileMenu(menu mainMenu: NSMenu) {
        let fileMenu = NSMenu(title: "Arquivo")
        fileMenu.autoenablesItems = false
        let fileItem = NSMenuItem()
        fileItem.submenu = fileMenu

        let openItem = NSMenuItem(title: "Abrir Arquivo…", action: #selector(openFile), keyEquivalent: "o")
        openItem.target = self
        fileMenu.addItem(openItem)

        let splitItem = NSMenuItem(title: "Abrir em Novo Painel…", action: #selector(openInNewPane), keyEquivalent: "o")
        splitItem.keyEquivalentModifierMask = [.command, .shift]
        splitItem.target = self
        splitItem.isEnabled = true
        fileMenu.addItem(splitItem)

        let closeDocItem = NSMenuItem(title: "Fechar Documento", action: #selector(closeActiveDocument), keyEquivalent: "w")
        closeDocItem.keyEquivalentModifierMask = [.command]
        closeDocItem.target = self
        closeDocItem.isEnabled = true
        fileMenu.addItem(closeDocItem)

        let closePaneItem = NSMenuItem(title: "Fechar Painel", action: #selector(closeActivePane), keyEquivalent: "w")
        closePaneItem.keyEquivalentModifierMask = [.command, .shift]
        closePaneItem.target = self
        closePaneItem.isEnabled = true
        fileMenu.addItem(closePaneItem)

        fileMenu.addItem(.separator())

        let recentsItem = NSMenuItem(title: "Recentes", action: nil, keyEquivalent: "")
        let recentsMenu = NSMenu(title: "Recentes")
        recentsItem.submenu = recentsMenu
        fileMenu.addItem(recentsItem)

        mainMenu.addItem(fileItem)
    }

    private func findMenu(menu mainMenu: NSMenu) {
        let findMenu = NSMenu(title: "Buscar")
        findMenu.autoenablesItems = false
        let findItem = NSMenuItem()
        findItem.submenu = findMenu

        let searchItem = NSMenuItem(title: "Buscar…", action: #selector(activateFind), keyEquivalent: "f")
        searchItem.target = self
        searchItem.isEnabled = true
        findMenu.addItem(searchItem)

        let nextItem = NSMenuItem(title: "Próximo Resultado", action: #selector(findNextResult), keyEquivalent: "g")
        nextItem.target = self
        nextItem.isEnabled = true
        findMenu.addItem(nextItem)

        let prevItem = NSMenuItem(title: "Resultado Anterior", action: #selector(findPrevResult), keyEquivalent: "G")
        prevItem.keyEquivalentModifierMask = [.command, .shift]
        prevItem.target = self
        prevItem.isEnabled = true
        findMenu.addItem(prevItem)

        mainMenu.addItem(findItem)
    }

    private func editMenu(menu mainMenu: NSMenu) {
        let editMenu = NSMenu(title: "Editar")
        let editItem = NSMenuItem()
        editItem.submenu = editMenu
        editMenu.addItem(withTitle: "Copiar", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Selecionar Tudo", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        mainMenu.addItem(editItem)
    }

    private func viewMenu(menu mainMenu: NSMenu) {
        let viewMenu = NSMenu(title: "Visualizar")
        let viewItem = NSMenuItem()
        viewItem.submenu = viewMenu
        let fullScreen = NSMenuItem(title: "Entrar em Tela Cheia", action: #selector(NSWindow.toggleFullScreen(_:)), keyEquivalent: "f")
        fullScreen.keyEquivalentModifierMask = [.control, .command]
        viewMenu.addItem(fullScreen)
        mainMenu.addItem(viewItem)
    }

    private func windowMenu(menu mainMenu: NSMenu) {
        let windowMenu = NSMenu(title: "Janela")
        let windowItem = NSMenuItem()
        windowItem.submenu = windowMenu
        windowMenu.addItem(withTitle: "Minimizar", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        NSApplication.shared.windowsMenu = windowMenu
        mainMenu.addItem(windowItem)
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(openInNewPane):
            return appState.panes.count < AppState.maxPanes
        case #selector(closeActiveDocument):
            // Enabled when the active pane has a document loaded
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

    @objc func openFile() {
        appState.showOpenPanel()
    }

    @objc func activateFind() {
        NotificationCenter.default.post(name: .activateFindBar, object: nil)
    }

    @objc func findNextResult() {
        NotificationCenter.default.post(name: .findNext, object: nil)
    }

    @objc func findPrevResult() {
        NotificationCenter.default.post(name: .findPrev, object: nil)
    }

    @objc func closeActiveDocument() {
        guard let activeID = appState.activePaneID,
              let pane = appState.panes.first(where: { $0.id == activeID }) else { return }
        // If only one pane exists, just clear the document; otherwise close the pane
        if appState.panes.count == 1 {
            pane.clear()
            appState.objectWillChange.send()
        } else {
            appState.closePane(pane)
        }
    }

    @objc func openInNewPane() {
        appState.addPane()
    }

    @objc func closeActivePane() {
        guard let activeID = appState.activePaneID,
              let pane = appState.panes.first(where: { $0.id == activeID }) else { return }
        appState.closePane(pane)
    }
}
