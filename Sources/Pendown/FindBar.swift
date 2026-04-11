import SwiftUI
import WebKit

// MARK: - Notification names

extension Notification.Name {
    static let activateFindBar = Notification.Name("com.pendown.activateFindBar")
    static let closeFindBar    = Notification.Name("com.pendown.closeFindBar")
    static let findNext        = Notification.Name("com.pendown.findNext")
    static let findPrev        = Notification.Name("com.pendown.findPrev")
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
    var placeholder: String = "Search…"
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
    var focusRequest: Binding<Bool>

    var body: some View {
        // Anchored to the top-right of the pane, like VS Code
        HStack { Spacer(); pill }
            .padding(.top, 6)
            .padding(.trailing, 8)
            .onReceive(NotificationCenter.default.publisher(for: .closeFindBar)) { _ in close() }
            .onReceive(NotificationCenter.default.publisher(for: .findNext))     { _ in controller.next() }
            .onReceive(NotificationCenter.default.publisher(for: .findPrev))     { _ in controller.prev() }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    focusRequest.wrappedValue = true
                }
            }
    }

    // The compact floating pill
    private var pill: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)

            FindTextField(
                text: $query,
                placeholder: L.searchEllipsis,
                onEscape: close,
                onEnter:  { controller.next() }
            )
            .frame(width: 160)
            .onChange(of: query) { controller.search($0) }

            // Match counter
            if !query.isEmpty {
                Text(counterText)
                    .font(.system(size: 10).monospacedDigit())
                    .foregroundStyle(controller.matchCount == 0
                                     ? Color.red.opacity(0.8)
                                     : Color.secondary)
                    .fixedSize()
            }

            Divider().frame(height: 12)

            HStack(spacing: 0) {
                arrowButton("chevron.up",   help: L.previousShortcut) { controller.prev() }
                arrowButton("chevron.down", help: L.nextShortcut)     { controller.next() }
            }
            .disabled(controller.matchCount == 0)

            Button(action: close) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help(L.closeEsc)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .liquidGlass(cornerRadius: 10)
    }

    private var counterText: String {
        guard controller.matchCount > 0 else { return "0" }
        return "\(controller.currentIndex + 1)/\(controller.matchCount)"
    }

    private func close() {
        query     = ""
        isVisible = false
        controller.clear()
    }

    private func arrowButton(_ icon: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .semibold))
                .frame(width: 20, height: 20)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .help(help)
    }
}
