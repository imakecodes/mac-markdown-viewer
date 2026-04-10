import Foundation
import Markdown

struct MarkdownHTMLRenderer: MarkupWalker {
    private var html = ""
    private var listItemIndex = 0
    private var orderedListCounters: [Int] = []

    static func renderHTML(from markdown: String) -> String {
        let document = Document(parsing: markdown)
        var renderer = MarkdownHTMLRenderer()
        renderer.visit(document)
        return renderer.html
    }

    // MARK: - Block elements

    mutating func visitDocument(_ document: Document) -> () {
        for child in document.children {
            visit(child)
        }
    }

    mutating func visitHeading(_ heading: Heading) -> () {
        let level = heading.level
        html += "<h\(level)>"
        for child in heading.children { visit(child) }
        html += "</h\(level)>\n"
    }

    mutating func visitParagraph(_ paragraph: Paragraph) -> () {
        html += "<p>"
        for child in paragraph.children { visit(child) }
        html += "</p>\n"
    }

    mutating func visitBlockQuote(_ blockQuote: BlockQuote) -> () {
        html += "<blockquote>\n"
        for child in blockQuote.children { visit(child) }
        html += "</blockquote>\n"
    }

    mutating func visitCodeBlock(_ codeBlock: CodeBlock) -> () {
        let lang = (codeBlock.language ?? "").trimmingCharacters(in: .whitespaces)
        if lang.lowercased() == "mermaid" {
            // Mermaid reads textContent, so HTML-escaping is safe – browsers decode entities
            let escaped = escapeHTML(codeBlock.code)
            html += "<div class=\"mermaid\">\(escaped)</div>\n"
            return
        }
        let escaped = escapeHTML(codeBlock.code)
        if lang.isEmpty {
            html += "<pre><code>\(escaped)</code></pre>\n"
        } else {
            html += "<pre><code class=\"language-\(lang)\">\(escaped)</code></pre>\n"
        }
    }

    mutating func visitOrderedList(_ orderedList: OrderedList) -> () {
        html += "<ol>\n"
        orderedListCounters.append(0)
        for child in orderedList.children { visit(child) }
        orderedListCounters.removeLast()
        html += "</ol>\n"
    }

    mutating func visitUnorderedList(_ unorderedList: UnorderedList) -> () {
        html += "<ul>\n"
        for child in unorderedList.children { visit(child) }
        html += "</ul>\n"
    }

    mutating func visitListItem(_ listItem: ListItem) -> () {
        if let checkbox = listItem.checkbox {
            let checked = checkbox == .checked ? " checked disabled" : " disabled"
            html += "<li><input type=\"checkbox\"\(checked)> "
        } else {
            html += "<li>"
        }
        for child in listItem.children { visit(child) }
        html += "</li>\n"
    }

    mutating func visitThematicBreak(_ thematicBreak: ThematicBreak) -> () {
        html += "<hr>\n"
    }

    mutating func visitHTMLBlock(_ htmlBlock: HTMLBlock) -> () {
        html += htmlBlock.rawHTML
    }

    mutating func visitTable(_ table: Table) -> () {
        html += "<table>\n<thead>\n<tr>\n"
        for cell in table.head.cells {
            html += "<th>"
            for child in cell.children { visit(child) }
            html += "</th>\n"
        }
        html += "</tr>\n</thead>\n"
        let bodyRows = Array(table.body.rows)
        if !bodyRows.isEmpty {
            html += "<tbody>\n"
            for row in bodyRows {
                html += "<tr>\n"
                for cell in row.cells {
                    html += "<td>"
                    for child in cell.children { visit(child) }
                    html += "</td>\n"
                }
                html += "</tr>\n"
            }
            html += "</tbody>\n"
        }
        html += "</table>\n"
    }

    // MARK: - Inline elements

    mutating func visitText(_ text: Text) -> () {
        html += escapeHTML(text.string)
    }

    mutating func visitEmphasis(_ emphasis: Emphasis) -> () {
        html += "<em>"
        for child in emphasis.children { visit(child) }
        html += "</em>"
    }

    mutating func visitStrong(_ strong: Strong) -> () {
        html += "<strong>"
        for child in strong.children { visit(child) }
        html += "</strong>"
    }

    mutating func visitStrikethrough(_ strikethrough: Strikethrough) -> () {
        html += "<del>"
        for child in strikethrough.children { visit(child) }
        html += "</del>"
    }

    mutating func visitInlineCode(_ inlineCode: InlineCode) -> () {
        html += "<code>\(escapeHTML(inlineCode.code))</code>"
    }

    mutating func visitLink(_ link: Link) -> () {
        let dest = link.destination ?? ""
        html += "<a href=\"\(escapeHTML(dest))\">"
        for child in link.children { visit(child) }
        html += "</a>"
    }

    mutating func visitImage(_ image: Image) -> () {
        let src = image.source ?? ""
        let alt = image.plainText
        html += "<img src=\"\(escapeHTML(src))\" alt=\"\(escapeHTML(alt))\">"
    }

    mutating func visitSoftBreak(_ softBreak: SoftBreak) -> () {
        html += "\n"
    }

    mutating func visitLineBreak(_ lineBreak: LineBreak) -> () {
        html += "<br>\n"
    }

    mutating func visitInlineHTML(_ inlineHTML: InlineHTML) -> () {
        html += inlineHTML.rawHTML
    }

    // MARK: - Helpers

    private func escapeHTML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private func alignmentAttr(_ colspan: UInt) -> String {
        return ""
    }
}
