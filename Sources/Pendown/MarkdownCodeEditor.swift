import SwiftUI
import AppKit

// MARK: - Code Editor (NSViewRepresentable)

struct MarkdownCodeEditor: NSViewRepresentable {
    @Binding var text: String

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder

        let textView = EditorTextView()
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.isRichText = false
        textView.usesFontPanel = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextCompletionEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.drawsBackground = false
        textView.font = editorFont()
        textView.textColor = .labelColor
        textView.insertionPointColor = .labelColor
        textView.selectedTextAttributes = [
            .backgroundColor: NSColor.selectedTextBackgroundColor,
            .foregroundColor: NSColor.selectedTextColor
        ]
        textView.textContainerInset = NSSize(width: 20, height: 20)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(
            width: 0, height: CGFloat.greatestFiniteMagnitude
        )
        textView.textContainer?.widthTracksTextView = true
        textView.delegate = context.coordinator
        let coordinator = context.coordinator
        textView.onAppearanceChange = { [weak coordinator] in
            coordinator?.applyHighlighting()
        }

        context.coordinator.textView = textView
        scrollView.documentView = textView

        textView.string = text
        context.coordinator.applyHighlighting()

        // Focus after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            textView.window?.makeFirstResponder(textView)
        }

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? EditorTextView else { return }
        guard textView.string != text else { return }
        let ranges = textView.selectedRanges
        textView.string = text
        context.coordinator.applyHighlighting()
        textView.selectedRanges = ranges
    }

    // MARK: Coordinator

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MarkdownCodeEditor
        weak var textView: EditorTextView?
        private var highlightWork: DispatchWorkItem?

        init(_ parent: MarkdownCodeEditor) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            parent.text = tv.string

            highlightWork?.cancel()
            let work = DispatchWorkItem { [weak self] in
                self?.applyHighlighting()
            }
            highlightWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: work)
        }

        func applyHighlighting() {
            guard let tv = textView, let storage = tv.textStorage else { return }
            let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            MarkdownSyntaxHighlighter.highlight(storage: storage, isDark: isDark)
        }
    }
}

// MARK: - Custom NSTextView for editor

class EditorTextView: NSTextView {
    var onAppearanceChange: (() -> Void)?

    // Tab → 4 spaces
    override func insertTab(_ sender: Any?) {
        insertText("    ", replacementRange: selectedRange())
    }

    // Auto-indent + list continuation on newline
    override func insertNewline(_ sender: Any?) {
        let text = string as NSString
        let loc = selectedRange().location
        let lineRange = text.lineRange(for: NSRange(location: loc, length: 0))
        let line = text.substring(with: NSRange(
            location: lineRange.location,
            length: loc - lineRange.location
        ))

        var indent = ""
        for ch in line {
            if ch == " " || ch == "\t" { indent.append(ch) } else { break }
        }

        let trimmed = line.trimmingCharacters(in: .whitespaces)

        // Continue list markers
        if let marker = listContinuation(trimmed) {
            super.insertNewline(sender)
            insertText(indent + marker, replacementRange: selectedRange())
            return
        }

        super.insertNewline(sender)
        if !indent.isEmpty {
            insertText(indent, replacementRange: selectedRange())
        }
    }

    // Intercept Cmd+F → find bar, Cmd+K → palette
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let cmd = event.modifierFlags.contains(.command)
        let sft = event.modifierFlags.contains(.shift)
        switch (cmd, sft, event.characters) {
        case (true, false, "f"):
            NotificationCenter.default.post(name: .activateFindBar, object: nil)
            return true
        case (true, false, "k"):
            NotificationCenter.default.post(name: .toggleCommandPalette, object: nil)
            return true
        default:
            return super.performKeyEquivalent(with: event)
        }
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        onAppearanceChange?()
    }

    private func listContinuation(_ trimmed: String) -> String? {
        if trimmed.hasPrefix("- [ ] ") || trimmed.hasPrefix("- [x] ") { return "- [ ] " }
        if trimmed.hasPrefix("- ") { return "- " }
        if trimmed.hasPrefix("* ") { return "* " }
        if trimmed.hasPrefix("+ ") { return "+ " }
        let ns = trimmed as NSString
        if let regex = try? NSRegularExpression(pattern: "^(\\d+)\\.\\s"),
           let match = regex.firstMatch(in: trimmed, range: NSRange(location: 0, length: ns.length)),
           let numRange = Range(match.range(at: 1), in: trimmed),
           let num = Int(trimmed[numRange]) {
            return "\(num + 1). "
        }
        return nil
    }
}

// MARK: - Font helpers

func editorFont() -> NSFont {
    if let jb = NSFont(name: "JetBrainsMono-Regular", size: 13) { return jb }
    if let sf = NSFont(name: "SFMono-Regular", size: 13) { return sf }
    return NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
}

private func editorBoldFont() -> NSFont {
    if let jb = NSFont(name: "JetBrainsMono-Bold", size: 13) { return jb }
    if let sf = NSFont(name: "SFMono-Bold", size: 13) { return sf }
    return NSFont.monospacedSystemFont(ofSize: 13, weight: .bold)
}

private func editorItalicFont() -> NSFont {
    if let jb = NSFont(name: "JetBrainsMono-Italic", size: 13) { return jb }
    if let sf = NSFont(name: "SFMono-RegularItalic", size: 13) { return sf }
    let desc = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular).fontDescriptor
    return NSFont(descriptor: desc.withSymbolicTraits(.italic), size: 13)
        ?? NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
}

// MARK: - Syntax Highlighter

struct MarkdownSyntaxHighlighter {

    static func highlight(storage: NSTextStorage, isDark: Bool) {
        let length = storage.length
        guard length > 0 else { return }
        let fullRange = NSRange(location: 0, length: length)

        storage.beginEditing()

        // ── Default attributes ──
        let fg = isDark ? NSColor(white: 0.88, alpha: 1) : NSColor(white: 0.12, alpha: 1)
        storage.addAttribute(.foregroundColor, value: fg, range: fullRange)
        storage.addAttribute(.font, value: editorFont(), range: fullRange)

        let text = storage.string

        // ── Colors ──
        let accent = isDark ? NSColor(red: 0.56, green: 0.59, blue: 0.96, alpha: 1)
                            : NSColor(red: 0.39, green: 0.40, blue: 0.95, alpha: 1)
        let green  = isDark ? NSColor(red: 0.49, green: 0.78, blue: 0.49, alpha: 1)
                            : NSColor(red: 0.18, green: 0.54, blue: 0.18, alpha: 1)
        let orange = isDark ? NSColor(red: 0.90, green: 0.65, blue: 0.35, alpha: 1)
                            : NSColor(red: 0.72, green: 0.42, blue: 0.05, alpha: 1)
        let gray   = isDark ? NSColor(white: 0.55, alpha: 1)
                            : NSColor(white: 0.48, alpha: 1)
        let meta   = isDark ? NSColor(white: 0.42, alpha: 1)
                            : NSColor(white: 0.58, alpha: 1)

        // ── Apply patterns (order matters: later overwrites for overlapping ranges) ──

        // Headings (full line)
        apply("^#{1,6}\\s+.*$", to: storage, in: text,
              color: accent, font: editorBoldFont(), opts: .anchorsMatchLines)

        // Hash marks dimmed
        apply("^#{1,6}\\s", to: storage, in: text,
              color: meta, font: editorBoldFont(), opts: .anchorsMatchLines)

        // Blockquotes
        apply("^>.*$", to: storage, in: text,
              color: gray, opts: .anchorsMatchLines)

        // List markers
        apply("^\\s*[-*+]\\s", to: storage, in: text,
              color: orange, opts: .anchorsMatchLines)
        apply("^\\s*\\d+\\.\\s", to: storage, in: text,
              color: orange, opts: .anchorsMatchLines)

        // Horizontal rules
        apply("^(---+|\\*\\*\\*+|___+)\\s*$", to: storage, in: text,
              color: meta, opts: .anchorsMatchLines)

        // Italic (applied before bold so bold can overwrite)
        apply("\\*[^*\\n]+\\*", to: storage, in: text,
              color: fg, font: editorItalicFont())
        apply("(?<![\\w])_[^_\\n]+_(?![\\w])", to: storage, in: text,
              color: fg, font: editorItalicFont())

        // Bold (overwrites italic for **bold**)
        apply("\\*\\*.+?\\*\\*", to: storage, in: text,
              color: fg, font: editorBoldFont())
        apply("__.+?__", to: storage, in: text,
              color: fg, font: editorBoldFont())

        // Links [text](url)
        apply("\\[.+?\\]\\(.+?\\)", to: storage, in: text, color: accent)

        // Images ![alt](url)
        apply("!\\[.*?\\]\\(.+?\\)", to: storage, in: text, color: accent)

        // Inline code (overwrites inline formatting)
        apply("`[^`\\n]+`", to: storage, in: text, color: green)

        // Fenced code blocks (overwrites everything inside)
        apply("```[\\s\\S]*?```", to: storage, in: text, color: green)

        storage.endEditing()
    }

    private static func apply(
        _ pattern: String,
        to storage: NSTextStorage,
        in text: String,
        color: NSColor,
        font: NSFont? = nil,
        opts: NSRegularExpression.Options = []
    ) {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: opts) else { return }
        let range = NSRange(location: 0, length: (text as NSString).length)
        regex.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
            guard let r = match?.range else { return }
            storage.addAttribute(.foregroundColor, value: color, range: r)
            if let font = font {
                storage.addAttribute(.font, value: font, range: r)
            }
        }
    }
}
