import Foundation
import SwiftSoup

extension SupportHTMLParser {
    func inline(in element: Element) throws -> [SupportInline] {
        try element.getChildNodes().flatMap { node -> [SupportInline] in
            if let text = node as? TextNode {
                return [.text(text.text().replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression))]
            }
            guard let child = node as? Element, !ignored(child) else { return [] }
            let content = try inline(in: child)
            switch child.tagName() {
            case "a": return [.link(label: content, url: try resolve(child.attr("href")))]
            case "em", "i": return [.emphasis(content)]
            case "strong", "b": return [.strong(content)]
            case "sup": return [.superscript(content)]
            case "code": return [.code(try child.text())]
            case "br": return [.lineBreak]
            default: return content
            }
        }
    }

    func blocks(in element: Element) throws -> [SupportContentBlock] {
        var result: [SupportContentBlock] = []
        var pending: [SupportInline] = []
        func flush() {
            if pending.contains(where: {
                if case .text(let text) = $0 {
                    return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                }
                return true
            }) {
                result.append(.paragraph(pending))
            }
            pending = []
        }
        for node in element.getChildNodes() {
            if let text = node as? TextNode {
                pending.append(
                    .text(text.text().replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)))
            } else if let child = node as? Element, !ignored(child) {
                if ["a", "em", "i", "strong", "b", "sup", "code", "span", "br"].contains(child.tagName()) {
                    let wrapper = try Element(Tag.valueOf("p"), "")
                    try wrapper.appendChild(child.copy(parent: nil))
                    pending += try inline(in: wrapper)
                } else {
                    flush()
                    result += try block(child)
                }
            }
        }
        flush()
        return result
    }

    func block(_ element: Element) throws -> [SupportContentBlock] {
        if ignored(element) || element.tagName() == "h1" { return [] }
        switch element.tagName() {
        case "p":
            return [.paragraph(try inline(in: element))]
        case "h2", "h3", "h4", "h5", "h6":
            let anchor = try element.attr("id")
            return [
                .heading(
                    level: Int(element.tagName().dropFirst())!, text: try element.text(),
                    anchor: anchor.isEmpty ? nil : anchor)
            ]
        case "ol", "ul":
            let items = try element.children().array().filter { $0.tagName() == "li" }.map { try blocks(in: $0) }
            return [.list(ordered: element.tagName() == "ol", start: Int(try element.attr("start")) ?? 1, items: items)]
        case "pre":
            let code = try element.select("code").first()
            let language = try code?.classNames().first(where: { $0.hasPrefix("language-") })
            return [
                .codeListing(
                    try (code ?? element).text(trimAndNormaliseWhitespace: false),
                    syntax: language.map { String($0.dropFirst(9)) })
            ]
        case "table":
            return [.table(try tableRows(element))]
        case "img", "figure":
            return try imageBlocks(element)
        case "hr": return [.separator]
        default:
            if element.hasClass("callout") {
                let style = try element.classNames().first(where: { $0.hasPrefix("callout-") })
                return [
                    .aside(style: style.map { String($0.dropFirst(8)) } ?? "note", content: try blocks(in: element))
                ]
            }
            return try blocks(in: element)
        }
    }

    private func imageBlocks(_ element: Element) throws -> [SupportContentBlock] {
        if element.tagName() == "img" {
            let alt = try element.attr("alt")
            guard !alt.isEmpty else { return [] }
            return [.image(url: try resolve(element.attr("src")), alt: alt, caption: [])]
        }
        guard let image = try element.select("img[alt]").first(), !(try image.attr("alt")).isEmpty else {
            return try blocks(in: element)
        }
        let caption = try element.select("figcaption").first().map { try inline(in: $0) } ?? []
        return [.image(url: try resolve(image.attr("src")), alt: try image.attr("alt"), caption: caption)]
    }

    private func ignored(_ element: Element) -> Bool {
        ["script", "style", "link", "nav", "button", "input", "sf-symbol"].contains(element.tagName())
            || element.hasClass("article-keywords") || element.hasClass("LinkUniversal")
    }

    private func tableRows(_ table: Element) throws -> [SupportTableRow] {
        try table.select("tr").array().filter { row in
            var parent = row.parent()
            while let current = parent {
                if current.tagName() == "table" { return current === table }
                parent = current.parent()
            }
            return false
        }.map { row in
            SupportTableRow(
                cells: try row.children().array().filter { ["td", "th"].contains($0.tagName()) }.map {
                    SupportTableCell(
                        content: try blocks(in: $0), isHeader: $0.tagName() == "th",
                        columnSpan: Int(try $0.attr("colspan")) ?? 1, rowSpan: Int(try $0.attr("rowspan")) ?? 1)
                })
        }
    }
}
