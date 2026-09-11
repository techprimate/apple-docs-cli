import Foundation

struct DocumentationContentRenderer: Sendable {
    let references: [String: DocumentationReferenceDTO]
    private let layout = DocumentationTextLayout()

    func inlineText(_ content: [DocumentationTextDTO]) -> String {
        content.map { item in
            if let text = item.text {
                return text
            }
            if let code = item.code {
                return "`\(code)`"
            }
            if let identifier = item.identifier {
                return references[identifier]?.title ?? identifier
            }
            return inlineText(item.inlineContent ?? [])
        }.joined()
    }

    func render(_ blocks: [DocumentationBlockDTO], indent: String = "  ") -> String {
        blocks.map { render($0, indent: indent) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
    }

    private func render(_ block: DocumentationBlockDTO, indent: String) -> String {
        switch block {
        case .paragraph(let content):
            return layout.paragraph(inlineText(content), indent: indent)
        case .heading(let text):
            return text.isEmpty ? "" : layout.heading(text)
        case .codeListing(let code, let syntax):
            return layout.codeBlock(code, language: syntax, indent: indent)
        case .orderedList(let items, let startIndex):
            return renderList(items, startIndex: startIndex, indent: indent)
        case .unorderedList(let items):
            return renderList(items, indent: indent)
        case .aside(let content, let style, let name):
            let body = render(content, indent: indent + "│ ")
            guard !body.isEmpty else { return "" }
            return indent + (name ?? style.capitalized) + "\n" + body
        case .unsupported:
            return ""
        }
    }

    private func renderList(
        _ items: [DocumentationListItemDTO],
        startIndex: Int? = nil,
        indent: String
    ) -> String {
        items.enumerated().compactMap { index, item -> String? in
            let marker = startIndex.map { "\($0 + index). " } ?? "• "
            let continuation = indent + String(repeating: " ", count: marker.count)
            let body = render(item.content, indent: continuation)
            guard !body.isEmpty else { return nil }
            if body.hasPrefix(continuation) {
                return indent + marker + body.dropFirst(continuation.count)
            }
            return indent + marker + "\n" + body
        }.joined(separator: "\n")
    }
}
