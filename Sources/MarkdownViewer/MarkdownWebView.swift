import SwiftUI
import WebKit

// MARK: - Drag-aware WKWebView subclass

/// Intercepts file-URL drag events so SwiftUI's overlay can be driven from the
/// native AppKit drag session (WKWebView would otherwise swallow everything).
final class DropAwareWebView: WKWebView {
    var onDropTargeted: ((Bool) -> Void)?
    var onFileDrop: ((URL) -> Void)?

    private let mdExtensions: Set<String> = ["md", "markdown", "mdown", "mkd", "mkdn"]

    // MARK: NSDraggingDestination overrides

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        if let url = markdownURL(from: sender) {
            _ = url          // suppress warning
            onDropTargeted?(true)
            return .copy
        }
        return super.draggingEntered(sender)
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        if markdownURL(from: sender) != nil {
            return .copy
        }
        return super.draggingUpdated(sender)
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        onDropTargeted?(false)
        super.draggingExited(sender)
    }

    override func draggingEnded(_ sender: NSDraggingInfo) {
        onDropTargeted?(false)
        super.draggingEnded(sender)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        if let url = markdownURL(from: sender) {
            onDropTargeted?(false)
            onFileDrop?(url)
            return true
        }
        return super.performDragOperation(sender)
    }

    // MARK: Key intercepts – ⌘F, ⌘G, ⇧⌘G, Escape

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let cmd = event.modifierFlags.contains(.command)
        let sft = event.modifierFlags.contains(.shift)
        switch (cmd, sft, event.characters) {
        case (true, false, "f"):
            NotificationCenter.default.post(name: .activateFindBar, object: objectIdentifier)
            return true
        case (true, false, "g"):
            NotificationCenter.default.post(name: .findNext, object: objectIdentifier)
            return true
        case (true, true, "G"):
            NotificationCenter.default.post(name: .findPrev, object: objectIdentifier)
            return true
        default:
            return super.performKeyEquivalent(with: event)
        }
    }

    /// Stable identity token posted with notifications so PaneView can ignore
    /// events from other panes' web views.
    var objectIdentifier: AnyObject { self }

    // MARK: Helpers

    private func markdownURL(from info: NSDraggingInfo) -> URL? {
        let pb = info.draggingPasteboard
        let options: [NSPasteboard.ReadingOptionKey: Any] = [
            .urlReadingFileURLsOnly: true
        ]
        guard let urls = pb.readObjects(forClasses: [NSURL.self], options: options) as? [URL]
        else { return nil }
        return urls.first { mdExtensions.contains($0.pathExtension.lowercased()) }
    }
}

// MARK: - SwiftUI wrapper

struct MarkdownWebView: NSViewRepresentable {
    let htmlContent: String
    let baseURL: URL?
    var onDropTargeted: ((Bool) -> Void)? = nil
    var onFileDrop: ((URL) -> Void)? = nil
    /// Injected so the web view can register itself for JS find calls
    var findController: FindController? = nil

    // MARK: Coordinator – tracks last-loaded content to avoid redundant reloads

    class Coordinator {
        var lastHTML: String = ""
        var lastBaseURL: URL? = nil
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> DropAwareWebView {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")
        let webView = DropAwareWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        webView.onDropTargeted = onDropTargeted
        webView.onFileDrop     = onFileDrop
        findController?.webView = webView
        return webView
    }

    func updateNSView(_ webView: DropAwareWebView, context: Context) {
        webView.onDropTargeted  = onDropTargeted
        webView.onFileDrop      = onFileDrop
        findController?.webView = webView

        guard context.coordinator.lastHTML    != htmlContent
           || context.coordinator.lastBaseURL != baseURL
        else { return }

        context.coordinator.lastHTML    = htmlContent
        context.coordinator.lastBaseURL = baseURL
        webView.loadHTMLString(wrapInHTMLPage(htmlContent), baseURL: baseURL)
    }

    // MARK: HTML template

    private func wrapInHTMLPage(_ body: String) -> String {
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
            -moz-osx-font-smoothing: grayscale;
        }

        body {
            font-family: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif;
            line-height: 1.75;
            color: var(--fg);
            background: var(--bg);
            max-width: 780px;
            margin: 0 auto;
            padding: 40px 48px 80px;
        }

        /* Headings */
        h1, h2, h3, h4, h5, h6 {
            font-weight: 700;
            line-height: 1.3;
            margin-top: 2em;
            margin-bottom: 0.5em;
            letter-spacing: -0.02em;
        }

        h1 {
            font-size: 2.1em;
            margin-top: 0;
            padding-bottom: 0.4em;
            border-bottom: 2px solid var(--border);
        }

        h2 {
            font-size: 1.55em;
            padding-bottom: 0.25em;
            border-bottom: 1px solid var(--border);
        }

        h3 { font-size: 1.25em; }
        h4 { font-size: 1.05em; font-weight: 600; }
        h5, h6 { font-size: 0.95em; font-weight: 600; color: var(--fg-secondary); }

        /* Text */
        p { margin: 1em 0; }

        a {
            color: var(--accent);
            text-decoration: none;
            border-bottom: 1px solid transparent;
            transition: border-color 0.15s ease;
        }
        a:hover { border-bottom-color: var(--accent); }

        strong { font-weight: 600; }

        del { color: var(--fg-tertiary); }

        /* Code */
        code {
            font-family: 'JetBrains Mono', 'SF Mono', 'Fira Code', monospace;
            font-size: 0.85em;
            background: var(--code-bg);
            border: 1px solid var(--code-border);
            padding: 2px 7px;
            border-radius: 5px;
            font-variant-ligatures: none;
        }

        pre {
            background: var(--surface);
            border: 1px solid var(--border);
            padding: 20px 24px;
            border-radius: 10px;
            overflow-x: auto;
            line-height: 1.55;
            box-shadow: var(--shadow-sm);
            margin: 1.5em 0;
        }

        pre code {
            background: none;
            border: none;
            padding: 0;
            font-size: 0.85em;
            border-radius: 0;
        }

        /* Blockquote */
        blockquote {
            margin: 1.5em 0;
            padding: 0.8em 1.2em;
            border-left: 3px solid var(--accent);
            background: var(--accent-soft);
            border-radius: 0 8px 8px 0;
            color: var(--blockquote-fg);
        }
        blockquote p { margin: 0.4em 0; }

        /* Lists */
        ul, ol { padding-left: 1.8em; margin: 1em 0; }
        li { margin: 0.35em 0; }
        li > p { margin: 0.25em 0; }

        li::marker {
            color: var(--fg-tertiary);
        }

        /* Task lists */
        input[type="checkbox"] {
            appearance: none;
            -webkit-appearance: none;
            width: 16px;
            height: 16px;
            border: 2px solid var(--border);
            border-radius: 4px;
            vertical-align: middle;
            margin-right: 8px;
            position: relative;
            top: -1px;
        }
        input[type="checkbox"]:checked {
            background: var(--accent);
            border-color: var(--accent);
        }
        input[type="checkbox"]:checked::after {
            content: '\\2713';
            color: white;
            font-size: 11px;
            position: absolute;
            top: 50%;
            left: 50%;
            transform: translate(-50%, -50%);
        }

        /* Table */
        table {
            border-collapse: collapse;
            width: 100%;
            margin: 1.5em 0;
            border-radius: 8px;
            overflow: hidden;
            border: 1px solid var(--border);
            font-size: 0.93em;
        }
        th, td {
            padding: 10px 16px;
            text-align: left;
            border-bottom: 1px solid var(--border);
        }
        th {
            background: var(--table-header);
            font-weight: 600;
            font-size: 0.9em;
            text-transform: uppercase;
            letter-spacing: 0.03em;
            color: var(--fg-secondary);
        }
        tr:last-child td { border-bottom: none; }
        tr:hover td { background: var(--accent-soft); }

        /* HR */
        hr {
            border: none;
            height: 1px;
            background: var(--border);
            margin: 2.5em 0;
        }

        /* Images */
        img {
            max-width: 100%;
            height: auto;
            border-radius: 8px;
            box-shadow: var(--shadow-sm);
            margin: 1em 0;
        }

        /* Selection */
        ::selection {
            background: rgba(99, 102, 241, 0.25);
        }

        /* Scrollbar */
        ::-webkit-scrollbar { width: 6px; height: 6px; }
        ::-webkit-scrollbar-track { background: transparent; }
        ::-webkit-scrollbar-thumb { background: var(--border); border-radius: 3px; }
        ::-webkit-scrollbar-thumb:hover { background: var(--fg-tertiary); }

        /* Find highlights */
        mark.mvfind {
            background: rgba(253, 224, 71, 0.50);
            color: inherit;
            border-radius: 2px;
            padding: 0 1px;
            outline: none;
        }
        mark.mvfind-active {
            background: rgba(251, 146, 60, 0.80);
            outline: 2px solid rgba(251, 146, 60, 0.95);
            border-radius: 2px;
        }

        /* Mermaid diagrams – always light background for readability */
        .mermaid {
            display: flex;
            justify-content: center;
            margin: 1.5em 0;
            overflow-x: auto;
            background: #ffffff;
            border-radius: 10px;
            padding: 20px;
            border: 1px solid #e0e0e8;
        }
        .mermaid svg {
            max-width: 100%;
            height: auto;
        }
        </style>
        <script src="https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.min.js"></script>
        </head>
        <body>
        \(body)
        <script>
        // ── Find engine ──────────────────────────────────────────────
        window._mvFind = (function() {
            var matches = [], current = -1;

            function escapeRe(s) {
                return s.replace(/[.*+?^${}()|[\\]\\\\]/g, '\\\\$&');
            }

            function clearMarks() {
                document.querySelectorAll('mark.mvfind').forEach(function(m) {
                    var t = document.createTextNode(m.textContent);
                    m.parentNode.replaceChild(t, m);
                });
                // Merge adjacent text nodes so next search works correctly
                document.body.normalize();
                matches = []; current = -1;
            }

            function highlight() {
                matches.forEach(function(m, i) {
                    m.className = (i === current) ? 'mvfind mvfind-active' : 'mvfind';
                });
                if (matches[current]) {
                    matches[current].scrollIntoView({ behavior: 'smooth', block: 'center' });
                }
            }

            return {
                search: function(term) {
                    clearMarks();
                    if (!term) return 0;
                    var re = new RegExp(escapeRe(term), 'gi');
                    var walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT, {
                        acceptNode: function(n) {
                            var tag = n.parentElement && n.parentElement.tagName;
                            if (tag === 'SCRIPT' || tag === 'STYLE') return NodeFilter.FILTER_REJECT;
                            return NodeFilter.FILTER_ACCEPT;
                        }
                    });
                    var nodes = [];
                    while (walker.nextNode()) nodes.push(walker.currentNode);
                    nodes.forEach(function(node) {
                        var text = node.textContent;
                        if (!re.test(text)) { re.lastIndex = 0; return; }
                        re.lastIndex = 0;
                        var frag = document.createDocumentFragment(), last = 0, m;
                        while ((m = re.exec(text)) !== null) {
                            if (m.index > last) frag.appendChild(document.createTextNode(text.slice(last, m.index)));
                            var mark = document.createElement('mark');
                            mark.className = 'mvfind';
                            mark.textContent = m[0];
                            matches.push(mark);
                            frag.appendChild(mark);
                            last = re.lastIndex;
                        }
                        if (last < text.length) frag.appendChild(document.createTextNode(text.slice(last)));
                        node.parentNode.replaceChild(frag, node);
                    });
                    if (matches.length > 0) { current = 0; highlight(); }
                    return matches.length;
                },
                next: function() {
                    if (!matches.length) return;
                    current = (current + 1) % matches.length;
                    highlight();
                },
                prev: function() {
                    if (!matches.length) return;
                    current = (current - 1 + matches.length) % matches.length;
                    highlight();
                },
                clear: clearMarks
            };
        })();
        </script>
        <script>
        (function() {
            // Mermaid: always use default (light) theme so diagram text is legible
            mermaid.initialize({
                startOnLoad: true,
                theme: 'default',
                securityLevel: 'loose',
                fontFamily: 'Inter, -apple-system, BlinkMacSystemFont, sans-serif'
            });

            // Zoom: Ctrl+scroll and Ctrl++/- / Ctrl+0
            let scale = 1.0;
            const MIN = 0.4, MAX = 4.0, STEP = 0.1;

            function applyZoom() {
                document.body.style.transformOrigin = 'top center';
                document.body.style.transform = 'scale(' + scale + ')';
                // Keep the scrollable area sized correctly so scrollbars don't disappear
                document.body.style.width = (100 / scale) + '%';
            }

            window.addEventListener('wheel', function(e) {
                if (!e.ctrlKey && !e.metaKey) return;
                e.preventDefault();
                const delta = e.deltaY > 0 ? -STEP : STEP;
                scale = Math.min(MAX, Math.max(MIN, +(scale + delta).toFixed(2)));
                applyZoom();
            }, { passive: false });

            window.addEventListener('keydown', function(e) {
                if (!e.ctrlKey && !e.metaKey) return;
                if (e.key === '=' || e.key === '+') {
                    e.preventDefault();
                    scale = Math.min(MAX, +(scale + STEP).toFixed(2));
                    applyZoom();
                } else if (e.key === '-') {
                    e.preventDefault();
                    scale = Math.max(MIN, +(scale - STEP).toFixed(2));
                    applyZoom();
                } else if (e.key === '0') {
                    e.preventDefault();
                    scale = 1.0;
                    applyZoom();
                }
            });
        })();
        </script>
        </body>
        </html>
        """
    }
}
