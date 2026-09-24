import Foundation

struct DocumentationContentRenderer {
    private let layout = DocumentationTextLayout()

    func inline(_ content: [DocumentationInline]) -> String {
        content.map { item in
            switch item {
            case .text(let text): return text
            case .code(let code): return "`\(code)`"
            case .link(let label, _): return inline(label)
            }
        }.joined()
    }

    func blocks(_ content: [DocumentationBlock], indent: String = "") -> String {
        content.map { block($0, indent: indent) }.filter { !$0.isEmpty }.joined(separator: "\n\n")
    }

    func code(_ lines: [String], language: String?, indent: String = "") -> String {
        layout.codeBlock(lines, language: language, indent: indent)
    }

    func url(for target: DocumentationLinkTarget) -> String? {
        switch target {
        case .documentation(let destination): return destination.url.absoluteString
        case .external(let url): return url.absoluteString
        case .unavailable: return nil
        }
    }

    func availability(_ platform: DocumentationAvailability) -> String {
        var parts: [String] = []
        switch (platform.introducedAt, platform.deprecatedAt) {
        case (let introduced?, let deprecated?): parts.append("\(introduced)–\(deprecated)")
        case (let introduced?, nil): parts.append("\(introduced)+")
        case (nil, let deprecated?): parts.append("Until \(deprecated)")
        case (nil, nil): break
        }
        if let version = platform.obsoletedAt { parts.append("obsoleted \(version)") }
        if platform.isBeta { parts.append("beta") }
        if platform.isUnavailable { parts.append("unavailable") }
        return parts.isEmpty ? "Available" : parts.joined(separator: ", ")
    }

    private func block(_ block: DocumentationBlock, indent: String) -> String {
        switch block {
        case .paragraph(let content): return layout.paragraph(inline(content), indent: indent)
        case .heading(let text): return layout.heading(text)
        case .codeListing(let lines, let language): return code(lines, language: language, indent: indent)
        case .orderedList(let items, let start): return list(items, start: start, indent: indent)
        case .unorderedList(let items): return list(items, start: nil, indent: indent)
        case .aside(let content, let style, let name):
            return indent + (name ?? style.capitalized) + "\n" + blocks(content, indent: indent + "│ ")
        }
    }

    private func list(_ items: [[DocumentationBlock]], start: Int?, indent: String) -> String {
        items.enumerated().map { index, content in
            let marker = start.map { "\($0 + index). " } ?? "• "
            let continuation = indent + String(repeating: " ", count: marker.count)
            let body = blocks(content, indent: continuation)
            if body.hasPrefix(continuation) { return indent + marker + body.dropFirst(continuation.count) }
            return indent + marker + "\n" + body
        }.joined(separator: "\n")
    }
}

func terminalSafeText(_ text: String) -> String {
    String(
        String.UnicodeScalarView(
            text.unicodeScalars.filter {
                $0 == "\n" || $0 == "\t" || !CharacterSet.controlCharacters.contains($0)
            }))
}
