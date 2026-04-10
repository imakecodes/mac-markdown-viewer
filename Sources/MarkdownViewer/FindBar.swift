import SwiftUI
import WebKit

// MARK: - Notification names

extension Notification.Name {
    static let activateFindBar = Notification.Name("com.markdownviewer.activateFindBar")
    static let closeFindBar    = Notification.Name("com.markdownviewer.closeFindBar")
    static let findNext        = Notification.Name("com.markdownviewer.findNext")
    static let findPrev        = Notification.Name("com.markdownviewer.findPrev")
}

// MARK: - FindController

/// Drives JS-based text search inside a DropAwareWebView.
final class FindController: ObservableObject {
    weak var webView: DropAwareWebView?
    @Published var matchCount:  Int = 0
    @Published var currentIndex: Int = 0

    func search(_ query: String) {
        guard let wv = webView else { return }
        guard !query.isEmpty else { clear(); return }
        let safe = query
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'",  with: "\\'")
        wv.evaluateJavaScript("window._mvFind.search('\(safe)')") { [weak self] res, _ in
            let n = (res as? Int) ?? 0
            self?.matchCount   = n
            self?.currentIndex = 0
        }
    }

    func next() {
        guard matchCount > 0 else { return }
        currentIndex = (currentIndex + 1) % matchCount
        webView?.evaluateJavaScript("window._mvFind.next()", completionHandler: nil)
    }

    func prev() {
        guard matchCount > 0 else { return }
        currentIndex = (currentIndex - 1 + matchCount) % matchCount
        webView?.evaluateJavaScript("window._mvFind.prev()", completionHandler: nil)
    }

    func clear() {
        webView?.evaluateJavaScript("window._mvFind.clear()", completionHandler: nil)
        matchCount   = 0
        currentIndex = 0
    }
}

// MARK: - Custom NSTextField that intercepts Escape / Return

class FindNSTextField: NSTextField {
    var onEscape: (() -> Void)?
    var onEnter:  (() -> Void)?
}

struct FindTextField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String = "Buscar…"
    var onEscape: () -> Void
    var onEnter:  () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> FindNSTextField {
        let f = FindNSTextField()
        f.placeholderString  = placeholder
        f.isBezeled          = false
        f.drawsBackground    = false
        f.font               = .systemFont(ofSize: 12)
        f.focusRingType      = .none
        f.delegate           = context.coordinator
        f.onEscape           = onEscape
        f.onEnter            = onEnter
        return f
    }

    func updateNSView(_ f: FindNSTextField, context: Context) {
        if f.stringValue != text { f.stringValue = text }
        f.onEscape = onEscape
        f.onEnter  = onEnter
    }

    // Make it first responder when the view appears
    static func dismantleNSView(_ nsView: FindNSTextField, coordinator: Coordinator) {}

    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: FindTextField
        init(_ p: FindTextField) { self.parent = p }

        func controlTextDidChange(_ n: Notification) {
            if let f = n.object as? NSTextField { parent.text = f.stringValue }
        }

        func control(_ control: NSControl, textView: NSTextView,
                     doCommandBy sel: Selector) -> Bool {
            if sel == #selector(NSResponder.cancelOperation(_:)) {
                parent.onEscape(); return true
            }
            if sel == #selector(NSResponder.insertNewline(_:)) {
                parent.onEnter();  return true
            }
            return false
        }
    }
}

// MARK: - FindBar view

struct FindBar: View {
    @ObservedObject var controller: FindController
    @Binding var query:     String
    @Binding var isVisible: Bool
    /// Called after the bar is inserted into the layout so we can focus the field
    var focusRequest: Binding<Bool>

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            // Custom field so Escape is reliable across macOS 13+
            FindTextField(
                text: $query,
                onEscape: close,
                onEnter:  { controller.next() }
            )
            .frame(minWidth: 120, maxWidth: 220)
            .onChange(of: query) { controller.search($0) }

            // Counter
            Group {
                if !query.isEmpty && controller.matchCount == 0 {
                    Text("sem resultados")
                        .foregroundStyle(.red.opacity(0.75))
                } else if controller.matchCount > 0 {
                    Text("\(controller.currentIndex + 1) / \(controller.matchCount)")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                } else {
                    Color.clear
                }
            }
            .font(.system(size: 11))
            .frame(minWidth: 70, alignment: .leading)

            Divider().frame(height: 14)

            // Prev / Next
            HStack(spacing: 1) {
                arrowButton("chevron.up",   help: "Anterior (⇧⌘G)", action: { controller.prev() })
                arrowButton("chevron.down", help: "Próximo (⌘G)",    action: { controller.next() })
            }
            .disabled(controller.matchCount == 0)

            Spacer(minLength: 0)

            // Close
            Button(action: close) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .semibold))
                    .padding(4)
                    .background(Color(nsColor: .separatorColor).opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .buttonStyle(.plain)
            .help("Fechar (Esc)")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) { Divider() }
        .onReceive(NotificationCenter.default.publisher(for: .closeFindBar)) { _ in close() }
        .onReceive(NotificationCenter.default.publisher(for: .findNext))     { _ in controller.next() }
        .onReceive(NotificationCenter.default.publisher(for: .findPrev))     { _ in controller.prev() }
        .onAppear {
            // Small delay so the view is fully in the hierarchy before we ask for focus
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                focusRequest.wrappedValue = true
            }
        }
    }

    private func close() {
        query      = ""
        isVisible  = false
        controller.clear()
    }

    private func arrowButton(_ icon: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .frame(width: 24, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}
