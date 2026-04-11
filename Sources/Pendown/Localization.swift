import Foundation

// MARK: - Language

enum Language: String, CaseIterable {
    case en = "en"
    case pt = "pt"

    var displayName: String {
        switch self {
        case .en: return "English"
        case .pt: return "Portugues"
        }
    }
}

// MARK: - Localization

final class Localization: ObservableObject {
    static let shared = Localization()

    @Published var language: Language {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: "appLanguage")
            NotificationCenter.default.post(name: .languageChanged, object: nil)
        }
    }

    private init() {
        let saved = UserDefaults.standard.string(forKey: "appLanguage") ?? "en"
        language = Language(rawValue: saved) ?? .en
    }

    private var pt: Bool { language == .pt }

    // ── App ──
    var appName: String { "Pendown" }
    var about: String { pt ? "Sobre Pendown" : "About Pendown" }
    var quit: String { pt ? "Encerrar Pendown" : "Quit Pendown" }

    // ── File menu ──
    var fileMenu: String { pt ? "Arquivo" : "File" }
    var openFile: String { pt ? "Abrir Arquivo…" : "Open File…" }
    var openInNewPane: String { pt ? "Abrir em Novo Painel…" : "Open in New Pane…" }
    var closeDocument: String { pt ? "Fechar Documento" : "Close Document" }
    var closePane: String { pt ? "Fechar Painel" : "Close Pane" }
    var recents: String { pt ? "Recentes" : "Recents" }

    // ── Edit menu ──
    var editMenu: String { pt ? "Editar" : "Edit" }
    var undo: String { pt ? "Desfazer" : "Undo" }
    var redo: String { pt ? "Refazer" : "Redo" }
    var cut: String { pt ? "Recortar" : "Cut" }
    var copy: String { pt ? "Copiar" : "Copy" }
    var paste: String { pt ? "Colar" : "Paste" }
    var selectAll: String { pt ? "Selecionar Tudo" : "Select All" }

    // ── Find menu ──
    var findMenu: String { pt ? "Buscar" : "Find" }
    var findEllipsis: String { pt ? "Buscar…" : "Find…" }
    var nextResult: String { pt ? "Proximo Resultado" : "Next Result" }
    var previousResult: String { pt ? "Resultado Anterior" : "Previous Result" }

    // ── View menu ──
    var viewMenu: String { pt ? "Visualizar" : "View" }
    var commandPalette: String { pt ? "Paleta de Comandos…" : "Command Palette…" }
    var fullScreen: String { pt ? "Entrar em Tela Cheia" : "Enter Full Screen" }
    var languageMenu: String { pt ? "Idioma" : "Language" }

    // ── Window menu ──
    var windowMenu: String { pt ? "Janela" : "Window" }
    var minimize: String { pt ? "Minimizar" : "Minimize" }

    // ── Sidebar ──
    var folders: String { pt ? "PASTAS" : "FOLDERS" }
    var addFolder: String { pt ? "Adicionar pasta" : "Add folder" }
    var removeFolder: String { pt ? "Remover pasta" : "Remove folder" }
    var refreshFolder: String { pt ? "Atualizar" : "Refresh" }
    var showInFinder: String { pt ? "Mostrar no Finder" : "Show in Finder" }
    var noRecentFiles: String { pt ? "Nenhum arquivo recente" : "No recent files" }
    var clearRecents: String { pt ? "Limpar recentes" : "Clear recents" }
    var openFileTooltip: String { pt ? "Abrir arquivo (⌘O)" : "Open file (⌘O)" }
    var openInNewPaneTooltip: String { pt ? "Abrir em novo painel (⇧⌘O)" : "Open in new pane (⇧⌘O)" }
    var removeFromRecents: String { pt ? "Remover dos Recentes" : "Remove from Recents" }
    var open: String { pt ? "Abrir" : "Open" }
    var selectFolder: String { pt ? "Selecione uma pasta" : "Select a folder" }
    var noFolders: String { pt ? "Adicione uma pasta para navegar" : "Add a folder to browse" }

    // ── Content view ──
    var dragMdHere: String { pt ? "Arraste um .md aqui" : "Drag a .md file here" }
    var openInNewPaneOverlay: String { pt ? "Abrir em novo painel" : "Open in new pane" }
    var empty: String { pt ? "Vazio" : "Empty" }
    var liveReloadActive: String { pt ? "Live reload ativo" : "Live reload active" }
    var liveReloadInactive: String { pt ? "Live reload inativo" : "Live reload inactive" }
    var swapFile: String { pt ? "Trocar arquivo" : "Swap file" }
    var closePaneTooltip: String { pt ? "Fechar painel" : "Close pane" }
    var openFileLabel: String { pt ? "Abrir Arquivo" : "Open File" }
    var cmdOToOpen: String { pt ? "⌘O para abrir" : "⌘O to open" }
    var dragFiles: String { pt ? "Arraste arquivos" : "Drag files" }
    var openMdOrDrag: String { pt ? "Abra um arquivo .md ou arraste para a janela" : "Open a .md file or drag it to the window" }
    var nFiles: String { pt ? "arquivos" : "files" }
    var selectMdFile: String { pt ? "Selecione um arquivo Markdown" : "Select a Markdown file" }

    // ── Command palette ──
    var actions: String { pt ? "ACOES" : "ACTIONS" }
    var indexCategory: String { pt ? "INDICE" : "INDEX" }
    var recentsCategory: String { pt ? "RECENTES" : "RECENTS" }
    var searchPlaceholder: String { pt ? "Buscar comandos, titulos, recentes…" : "Search commands, headings, recents…" }
    var noResults: String { pt ? "Nenhum resultado" : "No results" }
    var openFileAction: String { pt ? "Abrir arquivo" : "Open file" }
    var newPane: String { pt ? "Novo painel" : "New pane" }
    var closePaneAction: String { pt ? "Fechar painel" : "Close pane" }
    var searchInDocument: String { pt ? "Buscar no documento" : "Search in document" }
    var reloadDocument: String { pt ? "Recarregar documento" : "Reload document" }
    var toggleDarkLight: String { pt ? "Alternar modo claro / escuro" : "Toggle light / dark mode" }
    var disableLiveReload: String { pt ? "Desativar live reload" : "Disable live reload" }
    var enableLiveReload: String { pt ? "Ativar live reload" : "Enable live reload" }
    var clearRecentsAction: String { pt ? "Limpar recentes" : "Clear recents" }
    var modePreview: String { pt ? "Modo Preview" : "Preview Mode" }
    var modeCodeEditor: String { pt ? "Modo Editor de Codigo" : "Code Editor Mode" }
    var modeVisualEditor: String { pt ? "Modo Editor Visual" : "Visual Editor Mode" }

    // ── Find bar ──
    var searchEllipsis: String { pt ? "Buscar…" : "Search…" }
    var previousShortcut: String { pt ? "Anterior ⇧⌘G" : "Previous ⇧⌘G" }
    var nextShortcut: String { pt ? "Proximo ⌘G" : "Next ⌘G" }
    var closeEsc: String { pt ? "Fechar  Esc" : "Close  Esc" }

    // ── Visual editor ──
    var boldTooltip: String { pt ? "Negrito (⌘B)" : "Bold (⌘B)" }
    var italicTooltip: String { pt ? "Italico (⌘I)" : "Italic (⌘I)" }
    var strikethroughTooltip: String { pt ? "Tachado" : "Strikethrough" }
    var heading1: String { pt ? "Titulo 1" : "Heading 1" }
    var heading2: String { pt ? "Titulo 2" : "Heading 2" }
    var heading3: String { pt ? "Titulo 3" : "Heading 3" }
    var paragraph: String { pt ? "Paragrafo" : "Paragraph" }
    var headingTooltip: String { pt ? "Titulo" : "Heading" }
    var codeTooltip: String { pt ? "Codigo" : "Code" }
    var quoteTooltip: String { pt ? "Citacao" : "Quote" }
    var listTooltip: String { pt ? "Lista" : "List" }
    var orderedListTooltip: String { pt ? "Lista numerada" : "Numbered list" }
    var hrTooltip: String { pt ? "Linha horizontal" : "Horizontal rule" }
    var visualEditorOffline: String { pt ? "Editor visual requer conexao para carregar dependencias. Use o modo Codigo." : "Visual editor requires internet to load dependencies. Use Code mode." }
    var startTyping: String { pt ? "Comece a digitar…" : "Start typing…" }

    // ── Mode labels ──
    var preview: String { "Preview" }
    var code: String { pt ? "Codigo" : "Code" }
    var visual: String { "Visual" }
}

// MARK: - Notification

extension Notification.Name {
    static let languageChanged = Notification.Name("com.pendown.languageChanged")
}

// MARK: - Global accessor

let L = Localization.shared
