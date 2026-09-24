import Foundation

struct DocumentationContentRenderer {
    let audience: OutputAudience
    private let layout = DocumentationTextLayout()

    func inline(_ content: [DocumentationInline]) -> String {
        content.map { item in
            switch item {
            case .text(let text): return audience == .agent ? markdown(text) : text
            case .code(let code): return audience == .agent ? inlineCode(code) : "`\(code)`"
            case .link(let label, let target):
                return audience == .agent ? link(inline(label), target: target) : inline(label)
            }
        }.joined()
    }

    func blocks(_ content: [DocumentationBlock], indent: String = "") -> String {
        content.map { block($0, indent: indent) }.filter { !$0.isEmpty }.joined(separator: "\n\n")
    }

    func code(_ lines: [String], language: String?, indent: String = "") -> String {
        if audience == .human { return layout.codeBlock(lines, language: language, indent: indent) }
        let text = lines.joined(separator: "\n")
        let fence = String(repeating: "`", count: max(3, longestBacktickRun(text) + 1))
        // A language hint is a single Markdown info-string token, not arbitrary source text.
        let syntax = (language ?? "").filter { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "+" }
        return "\(fence)\(syntax)\n\(text)\n\(fence)"
    }

    func link(_ label: String, target: DocumentationLinkTarget) -> String {
        guard let url = url(for: target) else { return label }
        return "[\(label)](<\(url)>)"
    }

    func url(for target: DocumentationLinkTarget) -> String? {
        switch target {
        case .documentation(let destination): return destination.url.absoluteString
        case .external(let url): return url.absoluteString
        case .unavailable: return nil
        }
    }

    func markdown(_ text: String) -> String {
        text.reduce(into: "") { result, character in
            if "\\`*_[]<>#".contains(character) { result.append("\\") }
            result.append(character)
        }
    }

    func inlineCode(_ text: String) -> String {
        let fence = String(repeating: "`", count: longestBacktickRun(text) + 1)
        let padding = text.hasPrefix("`") || text.hasSuffix("`") ? " " : ""
        return fence + padding + text + padding + fence
    }

    func availability(_ platform: DocumentationAvailability) -> String {
        var parts: [String] = []
        if audience == .human {
            switch (platform.introducedAt, platform.deprecatedAt) {
            case (let introduced?, let deprecated?): parts.append("\(introduced)–\(deprecated)")
            case (let introduced?, nil): parts.append("\(introduced)+")
            case (nil, let deprecated?): parts.append("Until \(deprecated)")
            case (nil, nil): break
            }
        } else {
            if let version = platform.introducedAt { parts.append("introduced \(version)") }
            if let version = platform.deprecatedAt { parts.append("deprecated \(version)") }
        }
        if let version = platform.obsoletedAt { parts.append("obsoleted \(version)") }
        if platform.isBeta { parts.append("beta") }
        if platform.isUnavailable { parts.append("unavailable") }
        return parts.isEmpty ? "Available" : parts.joined(separator: ", ")
    }

    private func block(_ block: DocumentationBlock, indent: String) -> String {
        switch block {
        case .paragraph(let content):
            let text = inline(content)
            return audience == .human ? layout.paragraph(text, indent: indent) : text
        case .heading(let text): return audience == .human ? layout.heading(text) : "### " + markdown(text)
        case .codeListing(let lines, let language): return code(lines, language: language, indent: indent)
        case .orderedList(let items, let start): return list(items, start: start, indent: indent)
        case .unorderedList(let items): return list(items, start: nil, indent: indent)
        case .aside(let content, let style, let name):
            if audience == .human {
                return indent + (name ?? style.capitalized) + "\n" + blocks(content, indent: indent + "│ ")
            }
            let body = ([markdown(name ?? style.capitalized)] + [blocks(content)])
                .joined(separator: "\n").components(separatedBy: "\n")
            return body.map { "> " + $0 }.joined(separator: "\n")
        }
    }

    private func list(_ items: [[DocumentationBlock]], start: Int?, indent: String) -> String {
        items.enumerated().map { index, content in
            let marker = start.map { "\($0 + index). " } ?? (audience == .human ? "• " : "- ")
            let continuation = indent + String(repeating: " ", count: marker.count)
            if audience == .human {
                let body = blocks(content, indent: continuation)
                if body.hasPrefix(continuation) { return indent + marker + body.dropFirst(continuation.count) }
                return indent + marker + "\n" + body
            }
            let body = blocks(content).components(separatedBy: "\n")
            return marker + (body.first ?? "")
                + body.dropFirst().map {
                    $0.isEmpty ? "\n" : "\n" + String(repeating: " ", count: marker.count) + $0
                }.joined()
        }.joined(separator: "\n")
    }

    private func longestBacktickRun(_ text: String) -> Int {
        var longest = 0
        var current = 0
        for character in text {
            current = character == "`" ? current + 1 : 0
            longest = max(longest, current)
        }
        return longest
    }
}

func terminalSafeText(_ text: String) -> String {
    String(
        String.UnicodeScalarView(
            text.unicodeScalars.filter {
                $0 == "\n" || $0 == "\t" || !CharacterSet.controlCharacters.contains($0)
            }))
}
