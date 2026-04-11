import SwiftUI
import WebKit

// MARK: - Visual Editor Controller

/// Drives formatting commands on the visual editor's WKWebView.
class VisualEditorController: ObservableObject {
    weak var webView: WKWebView?

    func bold()          { exec("window._mvFormat.bold()") }
    func italic()        { exec("window._mvFormat.italic()") }
    func strikethrough() { exec("window._mvFormat.strikethrough()") }
    func heading(_ l: Int) { exec("window._mvFormat.heading(\(l))") }
    func paragraph()     { exec("window._mvFormat.paragraph()") }
    func code()          { exec("window._mvFormat.code()") }
    func blockquote()    { exec("window._mvFormat.blockquote()") }
    func unorderedList() { exec("window._mvFormat.unorderedList()") }
    func orderedList()   { exec("window._mvFormat.orderedList()") }
    func horizontalRule(){ exec("window._mvFormat.horizontalRule()") }

    private func exec(_ js: String) {
        webView?.evaluateJavaScript(js, completionHandler: nil)
    }
}

// MARK: - Visual Editor WebView subclass

/// Intercepts key equivalents so the command palette still works.
private final class VisualEditorWebView: WKWebView {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let cmd = event.modifierFlags.contains(.command)
        if cmd, event.characters == "k" {
            NotificationCenter.default.post(name: .toggleCommandPalette, object: nil)
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}

// MARK: - Visual Editor (NSViewRepresentable)

struct MarkdownVisualEditor: NSViewRepresentable {
    let htmlContent: String
    let baseURL: URL?
    var controller: VisualEditorController?
    var onContentChanged: ((String) -> Void)?

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")
        config.userContentController.add(context.coordinator, name: "contentChanged")

        let webView = VisualEditorWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        webView.navigationDelegate = context.coordinator
        controller?.webView = webView

        let fullHTML = wrapInEditableHTML(htmlContent)
        webView.loadHTMLString(fullHTML, baseURL: baseURL)

        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        // We never push content back to the webview during editing.
        // The initial load happens in makeNSView.
        // If the user switches modes, SwiftUI destroys and recreates the view.
        controller?.webView = webView
    }

    // MARK: Coordinator

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: MarkdownVisualEditor
        init(_ parent: MarkdownVisualEditor) { self.parent = parent }

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            if message.name == "contentChanged", let md = message.body as? String {
                parent.onContentChanged?(md)
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Focus the editable area
            webView.evaluateJavaScript("document.body.focus()", completionHandler: nil)
        }
    }

    // MARK: HTML template

    private func wrapInEditableHTML(_ body: String) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
        @import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&family=JetBrains+Mono:wght@400;500&display=swap');

        :root {
            color-scheme: light dark;
            --bg: #ffffff;
            --fg: #1a1a2e;
            --fg-secondary: #64648c;
            --fg-tertiary: #9999b3;
            --accent: #6366f1;
            --accent-soft: rgba(99, 102, 241, 0.08);
            --border: #e8e8f0;
            --surface: #f8f8fc;
            --code-bg: #f3f3f9;
            --code-border: #e4e4ee;
            --blockquote-bar: #c7c7d8;
            --blockquote-fg: #6b6b8a;
            --table-header: #f5f5fb;
            --shadow-sm: 0 1px 2px rgba(0,0,0,0.04);
        }

        @media (prefers-color-scheme: dark) {
            :root {
                --bg: #16161e;
                --fg: #e4e4ef;
                --fg-secondary: #9999b3;
                --fg-tertiary: #666680;
                --accent: #818cf8;
                --accent-soft: rgba(129, 140, 248, 0.1);
                --border: #2a2a3c;
                --surface: #1e1e2e;
                --code-bg: #1e1e2e;
                --code-border: #2d2d40;
                --blockquote-bar: #3a3a50;
                --blockquote-fg: #8888a0;
                --table-header: #1c1c2c;
                --shadow-sm: 0 1px 2px rgba(0,0,0,0.2);
            }
        }

        * { box-sizing: border-box; }

        html {
            font-size: 15px;
            -webkit-font-smoothing: antialiased;
        }

        body {
            font-family: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif;
            line-height: 1.75;
            color: var(--fg);
            background: var(--bg);
            max-width: 780px;
            margin: 0 auto;
            padding: 56px 48px 80px;
            outline: none;
            min-height: 100vh;
        }

        body:focus { outline: none; }

        /* Caret color */
        body { caret-color: var(--accent); }

        h1, h2, h3, h4, h5, h6 {
            font-weight: 700; line-height: 1.3;
            margin-top: 1.5em; margin-bottom: 0.5em;
            letter-spacing: -0.02em;
        }
        h1 { font-size: 2.1em; margin-top: 0; padding-bottom: 0.4em; border-bottom: 2px solid var(--border); }
        h2 { font-size: 1.55em; padding-bottom: 0.25em; border-bottom: 1px solid var(--border); }
        h3 { font-size: 1.25em; }
        h4 { font-size: 1.05em; font-weight: 600; }

        p { margin: 1em 0; }

        a { color: var(--accent); text-decoration: none; }
        a:hover { text-decoration: underline; }

        strong { font-weight: 600; }
        del { color: var(--fg-tertiary); }

        code {
            font-family: 'JetBrains Mono', 'SF Mono', monospace;
            font-size: 0.85em;
            background: var(--code-bg);
            border: 1px solid var(--code-border);
            padding: 2px 7px;
            border-radius: 5px;
        }

        pre {
            background: var(--surface);
            border: 1px solid var(--border);
            padding: 20px 24px;
            border-radius: 10px;
            overflow-x: auto;
            line-height: 1.55;
            margin: 1.5em 0;
        }
        pre code { background: none; border: none; padding: 0; font-size: 0.85em; }

        blockquote {
            margin: 1.5em 0; padding: 0.8em 1.2em;
            border-left: 3px solid var(--accent);
            background: var(--accent-soft);
            border-radius: 0 8px 8px 0;
            color: var(--blockquote-fg);
        }
        blockquote p { margin: 0.4em 0; }

        ul, ol { padding-left: 1.8em; margin: 1em 0; }
        li { margin: 0.35em 0; }
        li::marker { color: var(--fg-tertiary); }

        table { border-collapse: collapse; width: 100%; margin: 1.5em 0; border: 1px solid var(--border); font-size: 0.93em; }
        th, td { padding: 10px 16px; text-align: left; border-bottom: 1px solid var(--border); }
        th { background: var(--table-header); font-weight: 600; }

        hr { border: none; height: 1px; background: var(--border); margin: 2.5em 0; }

        img { max-width: 100%; height: auto; border-radius: 8px; margin: 1em 0; }

        ::selection { background: rgba(99, 102, 241, 0.25); }

        ::-webkit-scrollbar { width: 6px; height: 6px; }
        ::-webkit-scrollbar-track { background: transparent; }
        ::-webkit-scrollbar-thumb { background: var(--border); border-radius: 3px; }

        /* Editing placeholder */
        body:empty::before {
            content: '\(L.startTyping)';
            color: var(--fg-tertiary);
            font-style: italic;
        }

        /* Empty paragraphs need min height so they're clickable/visible */
        p:empty,
        p:has(> br:only-child) {
            min-height: 1.75em;
        }

        /* Notion-like: subtle hover indicator between blocks */
        .mv-insert-hint {
            height: 4px;
            margin: -2px 0;
            border-radius: 2px;
            background: var(--accent);
            opacity: 0.25;
            pointer-events: none;
            transition: opacity 0.15s ease;
        }
        </style>
        <script src="https://cdn.jsdelivr.net/npm/turndown@7.2.0/dist/turndown.js"></script>
        <script src="https://cdn.jsdelivr.net/npm/turndown-plugin-gfm@1.0.2/dist/turndown-plugin-gfm.js"></script>
        </head>
        <body contenteditable="true" spellcheck="true">
        \(body)
        <script>
        (function() {
            // ── Turndown setup ──
            if (typeof TurndownService === 'undefined') {
                // Offline fallback: disable editing, show message
                document.body.contentEditable = false;
                var msg = document.createElement('div');
                msg.style.cssText = 'position:fixed;top:0;left:0;right:0;padding:10px;background:var(--accent-soft);color:var(--accent);text-align:center;font-size:13px;z-index:9999;border-bottom:1px solid var(--border)';
                msg.textContent = '\(L.visualEditorOffline)';
                document.body.parentElement.insertBefore(msg, document.body);
                return;
            }

            var td = new TurndownService({
                headingStyle: 'atx',
                codeBlockStyle: 'fenced',
                bulletListMarker: '-',
                emDelimiter: '*',
                strongDelimiter: '**',
                hr: '---'
            });

            // GFM plugin for tables + strikethrough
            if (typeof turndownPluginGfm !== 'undefined') {
                td.use(turndownPluginGfm.gfm);
            }

            // ── Debounced content change reporter ──
            var debounce;
            function reportChange() {
                clearTimeout(debounce);
                debounce = setTimeout(function() {
                    try {
                        var md = td.turndown(document.body.innerHTML);
                        window.webkit.messageHandlers.contentChanged.postMessage(md);
                    } catch(e) { console.error('Turndown error:', e); }
                }, 300);
            }

            document.body.addEventListener('input', reportChange);

            // Also observe DOM mutations for non-input changes (like execCommand)
            var observer = new MutationObserver(reportChange);
            observer.observe(document.body, {
                childList: true, characterData: true, subtree: true, attributes: true
            });

            // ── Format commands ──
            window._mvFormat = {
                bold: function() { document.execCommand('bold'); },
                italic: function() { document.execCommand('italic'); },
                strikethrough: function() { document.execCommand('strikeThrough'); },
                heading: function(level) {
                    document.execCommand('formatBlock', false, 'h' + level);
                },
                paragraph: function() {
                    document.execCommand('formatBlock', false, 'p');
                },
                code: function() {
                    var sel = window.getSelection();
                    if (sel.rangeCount > 0 && !sel.isCollapsed) {
                        var range = sel.getRangeAt(0);
                        var code = document.createElement('code');
                        try {
                            range.surroundContents(code);
                        } catch(e) {
                            // If selection crosses element boundaries, wrap text
                            code.textContent = sel.toString();
                            range.deleteContents();
                            range.insertNode(code);
                        }
                    }
                },
                blockquote: function() {
                    document.execCommand('formatBlock', false, 'blockquote');
                },
                unorderedList: function() {
                    document.execCommand('insertUnorderedList');
                },
                orderedList: function() {
                    document.execCommand('insertOrderedList');
                },
                horizontalRule: function() {
                    document.execCommand('insertHorizontalRule');
                }
            };

            // ── Notion-like click-to-create paragraphs ──

            function contentChildren() {
                return Array.from(document.body.children).filter(function(el) {
                    return el.tagName !== 'SCRIPT' && !el.classList.contains('mv-insert-hint');
                });
            }

            function focusNode(node) {
                var r = document.createRange();
                r.setStart(node, 0);
                r.collapse(true);
                var s = window.getSelection();
                s.removeAllRanges();
                s.addRange(r);
            }

            function makeParagraph() {
                var p = document.createElement('p');
                p.appendChild(document.createElement('br'));
                return p;
            }

            // Always keep a trailing empty <p> so users can click to continue
            function ensureTrailingParagraph() {
                var kids = contentChildren();
                var last = kids[kids.length - 1];
                if (!last || last.tagName !== 'P' || last.textContent.trim() !== '') {
                    document.body.appendChild(makeParagraph());
                }
            }
            ensureTrailingParagraph();

            // After DOM mutations, ensure trailing paragraph persists
            var trailingObs = new MutationObserver(function() {
                trailingObs.disconnect();
                ensureTrailingParagraph();
                trailingObs.observe(document.body, { childList: true });
            });
            trailingObs.observe(document.body, { childList: true });

            // Click on empty body space → insert/focus paragraph (Notion-style)
            document.body.addEventListener('mousedown', function(e) {
                // Only handle clicks directly on <body>, not on child elements
                if (e.target !== document.body) return;

                var kids = contentChildren();
                if (kids.length === 0) {
                    var p = makeParagraph();
                    document.body.appendChild(p);
                    setTimeout(function() { focusNode(p); }, 0);
                    return;
                }

                var y = e.clientY + window.scrollY;

                // Click above first element → insert paragraph at top
                var first = kids[0];
                var firstTop = first.offsetTop;
                if (y < firstTop) {
                    e.preventDefault();
                    var p = makeParagraph();
                    document.body.insertBefore(p, first);
                    setTimeout(function() { focusNode(p); }, 0);
                    return;
                }

                // Click below last element → focus/create trailing paragraph
                var last = kids[kids.length - 1];
                var lastBottom = last.offsetTop + last.offsetHeight;
                if (y > lastBottom) {
                    e.preventDefault();
                    if (last.tagName === 'P' && last.textContent.trim() === '') {
                        setTimeout(function() { focusNode(last); }, 0);
                    } else {
                        var p = makeParagraph();
                        document.body.appendChild(p);
                        setTimeout(function() { focusNode(p); }, 0);
                    }
                    return;
                }

                // Click between two elements → insert paragraph between them
                for (var i = 0; i < kids.length - 1; i++) {
                    var botCur  = kids[i].offsetTop + kids[i].offsetHeight;
                    var topNext = kids[i + 1].offsetTop;
                    if (y > botCur && y < topNext) {
                        e.preventDefault();
                        var p = makeParagraph();
                        document.body.insertBefore(p, kids[i + 1]);
                        setTimeout(function() { focusNode(p); }, 0);
                        return;
                    }
                }
            });

            // ── Enter key: prevent block duplication ──
            // contenteditable duplicates the current block on Enter (e.g. H1→H1, PRE→PRE).
            // We intercept to create a clean <p> instead.

            function findTopBlock(node) {
                var b = node;
                while (b && b !== document.body) {
                    if (b.parentNode === document.body) return b;
                    b = b.parentNode;
                }
                return null;
            }

            function isAtBlockEnd(block) {
                var sel = window.getSelection();
                if (!sel.rangeCount) return false;
                var range = sel.getRangeAt(0);
                var test = document.createRange();
                test.selectNodeContents(block);
                test.setStart(range.endContainer, range.endOffset);
                return test.toString().trim().length === 0;
            }

            function insertParagraphAfter(block) {
                var p = document.createElement('p');
                p.appendChild(document.createElement('br'));
                block.parentNode.insertBefore(p, block.nextSibling);
                var r = document.createRange();
                r.setStart(p, 0);
                r.collapse(true);
                var s = window.getSelection();
                s.removeAllRanges();
                s.addRange(r);
            }

            document.body.addEventListener('keydown', function(e) {
                // Formatting shortcuts
                if (e.metaKey || e.ctrlKey) {
                    switch(e.key) {
                        case 'b': e.preventDefault(); window._mvFormat.bold(); return;
                        case 'i': e.preventDefault(); window._mvFormat.italic(); return;
                    }
                    return;
                }

                if (e.key !== 'Enter' || e.shiftKey) return;

                var sel = window.getSelection();
                if (!sel.rangeCount) return;
                var block = findTopBlock(sel.anchorNode);
                if (!block) return;
                var tag = (block.tagName || '').toUpperCase();

                // ── Headings: Enter at end → new <p>; Enter mid → let default, then convert ──
                if (/^H[1-6]$/.test(tag)) {
                    if (isAtBlockEnd(block)) {
                        e.preventDefault();
                        insertParagraphAfter(block);
                    } else {
                        // Let default split happen, then convert the new heading to <p>
                        var original = block;
                        setTimeout(function() {
                            var s = window.getSelection();
                            if (!s.rangeCount) return;
                            var nb = findTopBlock(s.anchorNode);
                            if (nb && nb !== original && /^H[1-6]$/i.test(nb.tagName || '')) {
                                document.execCommand('formatBlock', false, 'p');
                            }
                        }, 0);
                    }
                    return;
                }

                // ── Code blocks (PRE): Enter at end → exit to <p> ──
                if (tag === 'PRE') {
                    if (isAtBlockEnd(block)) {
                        var text = block.textContent || '';
                        // If last line is empty (user pressed Enter on empty line) → exit
                        if (text.endsWith('\\n') || text === '') {
                            e.preventDefault();
                            // Trim trailing newline
                            if (text.endsWith('\\n')) {
                                block.textContent = text.slice(0, -1);
                            }
                            insertParagraphAfter(block);
                            return;
                        }
                    }
                    // Inside PRE, default Enter should insert newline (which it does)
                    return;
                }

                // ── Blockquote: Enter on empty inner paragraph → exit ──
                if (tag === 'BLOCKQUOTE') {
                    // Find the inner block (p, div) inside the blockquote
                    var inner = sel.anchorNode;
                    while (inner && inner.parentNode !== block) {
                        inner = inner.parentNode;
                    }
                    if (inner && inner.textContent.trim() === '') {
                        e.preventDefault();
                        block.removeChild(inner);
                        // If blockquote is now empty, remove it
                        if (block.textContent.trim() === '') {
                            var p = document.createElement('p');
                            p.appendChild(document.createElement('br'));
                            block.parentNode.replaceChild(p, block);
                            var r = document.createRange();
                            r.setStart(p, 0);
                            r.collapse(true);
                            sel.removeAllRanges();
                            sel.addRange(r);
                        } else {
                            insertParagraphAfter(block);
                        }
                    }
                    return;
                }

                // ── DIV (some browsers wrap in div instead of p) → convert to <p> ──
                if (tag === 'DIV') {
                    setTimeout(function() {
                        var s = window.getSelection();
                        if (!s.rangeCount) return;
                        var nb = findTopBlock(s.anchorNode);
                        if (nb && nb.tagName === 'DIV') {
                            document.execCommand('formatBlock', false, 'p');
                        }
                    }, 0);
                }
            });
        })();
        </script>
        </body>
        </html>
        """
    }
}

// MARK: - Formatting Toolbar

struct VisualEditorToolbar: View {
    @ObservedObject var controller: VisualEditorController
    @State private var showHeadingMenu = false

    var body: some View {
        HStack(spacing: 2) {
            fmtButton(L.boldTooltip, icon: "bold") { controller.bold() }
            fmtButton(L.italicTooltip, icon: "italic") { controller.italic() }
            fmtButton(L.strikethroughTooltip, icon: "strikethrough") { controller.strikethrough() }

            pill

            Menu {
                Button(L.heading1) { controller.heading(1) }
                Button(L.heading2) { controller.heading(2) }
                Button(L.heading3) { controller.heading(3) }
                Divider()
                Button(L.paragraph) { controller.paragraph() }
            } label: {
                Image(systemName: "textformat.size")
                    .font(.system(size: 12))
                    .frame(width: 26, height: 22)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help(L.headingTooltip)

            pill

            fmtButton(L.codeTooltip, icon: "chevron.left.forwardslash.chevron.right") { controller.code() }
            fmtButton(L.quoteTooltip, icon: "text.quote") { controller.blockquote() }

            pill

            fmtButton(L.listTooltip, icon: "list.bullet") { controller.unorderedList() }
            fmtButton(L.orderedListTooltip, icon: "list.number") { controller.orderedList() }

            pill

            fmtButton(L.hrTooltip, icon: "minus") { controller.horizontalRule() }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .liquidGlass(cornerRadius: 10)
    }

    private var pill: some View {
        Divider().frame(height: 14).padding(.horizontal, 2)
    }

    private func fmtButton(_ help: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .frame(width: 26, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .help(help)
    }
}
