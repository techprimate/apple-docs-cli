import Foundation

struct SupportTextRenderer {
    let agent: Bool
    private let layout = DocumentationTextLayout()

    func render(_ presentation: SupportPresentation) -> String {
        var sections = render(presentation.payload)
        if let navigation = presentation.navigation, !navigation.isEmpty {
            sections.append(heading("Follow-up commands", level: 2))
            sections += navigation.map { item in
                item.title + "\n" + fenced(item.command, language: "sh")
            }
        }
        let text = sections.filter { !$0.isEmpty }.joined(separator: "\n\n")
        return String(
            text.unicodeScalars.filter {
                !CharacterSet.controlCharacters.contains($0) || $0 == "\n" || $0 == "\t"
            })
    }

    private func render(_ payload: SupportPayload) -> [String] {
        switch payload {
        case .articles(let value):
            return header(value.header)
                + value.categories.flatMap {
                    [heading($0.title, level: 2), $0.summary] + $0.links.map(reference)
                }
        case .help(let value):
            return header(value.header) + value.featuredResources.flatMap(described)
                + [heading(value.topicsTitle, level: 2)] + value.topics.flatMap(topic)
                + described(value.glossary)
        case .contents(let value):
            return header(value.header) + value.entries.flatMap { contents($0, level: 2) }
        case .glossary(let value):
            return header(value.header) + value.entries.flatMap { [heading($0.term, level: 2), blocks($0.definition)] }
        case .glossaryEntry(let value):
            return [heading(value.term, level: 1), blocks(value.definition)]
        case .terms(let value):
            return header(value.header)
                + value.categories.flatMap {
                    [heading($0.title, level: 2), blocks($0.introduction)]
                        + $0.entries.flatMap { termsEntry($0, level: 3) }
                }
        case .termsEntry(let value):
            return termsEntry(value, level: 1)
        case .article(let value):
            return [
                heading(value.title, level: 1), value.url.absoluteString, value.context ?? "", blocks(value.content),
            ]
                + (value.related.isEmpty ? [] : [heading("Related", level: 2)] + value.related.map(reference))
                + (value.notices.isEmpty ? [] : [heading("Notices", level: 2), blocks(value.notices)])
        }
    }

    private func header(_ header: SupportPageHeader) -> [String] {
        [heading(header.title, level: 1), header.url.absoluteString, header.introduction]
    }

    private func described(_ item: SupportDescribedLink) -> [String] {
        [reference(item.link), item.summary]
    }

    private func topic(_ topic: SupportHelpTopic) -> [String] {
        [heading(topic.title, level: 3)]
            + topic.groups.flatMap {
                ($0.title.map { [heading($0, level: 4)] } ?? []) + $0.links.map(reference)
            }
    }

    private func contents(_ entry: SupportContentsEntry, level: Int) -> [String] {
        [entry.link.map(reference) ?? heading(entry.title, level: level)]
            + entry.children.flatMap { contents($0, level: level + 1) }
    }

    private func termsEntry(_ entry: SupportTermsEntry, level: Int) -> [String] {
        [heading(entry.title, level: level), "ID: " + entry.id, inline(entry.description)]
            + entry.resources.flatMap { resource in
                [reference(resource.link)]
                    + (resource.translations.map {
                        [blocks($0.notice), $0.lastUpdatedLabel.map { "Last update: " + $0 } ?? ""]
                            + $0.translations.map(reference)
                    } ?? [])
            }
    }

    private func heading(_ title: String, level: Int) -> String {
        agent
            ? String(repeating: "#", count: min(level, 6)) + " " + title
            : layout.heading(title, prominent: level == 1)
    }

    private func reference(_ link: SupportPageLink) -> String {
        agent
            ? "- [" + link.title + "](" + link.url.absoluteString + ")"
            : link.title + "\n  " + link.url.absoluteString
    }

    func inline(_ values: [SupportInline]) -> String {
        values.map { item in
            switch item {
            case .image(let url, let alt):
                return agent ? "![" + alt + "](" + url.absoluteString + ")" : alt + " (" + url.absoluteString + ")"
            case .text(let text): return text
            case .code(let text): return agent ? "`" + text + "`" : text
            case .emphasis(let content): return agent ? "*" + inline(content) + "*" : inline(content)
            case .strong(let content): return agent ? "**" + inline(content) + "**" : inline(content)
            case .superscript(let content): return "[" + inline(content) + "]"
            case .link(let label, let url):
                return agent
                    ? "[" + inline(label) + "](" + url.absoluteString + ")"
                    : inline(label) + " (" + url.absoluteString + ")"
            case .lineBreak: return "\n"
            }
        }.joined()
    }

    func blocks(_ values: [SupportContentBlock]) -> String {
        values.map(block).joined(separator: "\n\n")
    }

    private func block(_ value: SupportContentBlock) -> String {
        switch value {
        case .paragraph(let content):
            return agent
                ? inline(content).trimmingCharacters(in: .whitespacesAndNewlines)
                : layout.paragraph(inline(content), indent: "")
        case .heading(let level, let text, _): return heading(text, level: level)
        case .list(let ordered, let start, let items):
            return items.enumerated().map { index, item in
                let prefix =
                    ordered
                    ? NSDecimalNumber(decimal: Decimal(start) + Decimal(index)).stringValue + ". " : "- "
                let lines = blocks(item).components(separatedBy: "\n")
                return prefix + (lines.first ?? "") + lines.dropFirst().map { "\n  " + $0 }.joined()
            }.joined(separator: "\n")
        case .codeListing(let text, let syntax):
            return agent
                ? fenced(text, language: syntax ?? "")
                : layout.codeBlock(text.components(separatedBy: "\n"), language: syntax, indent: "")
        case .aside(let style, let content):
            return style.capitalized + ":\n" + blocks(content)
        case .table(let rows): return table(rows)
        case .image(let url, let alt, let caption):
            return (agent ? "![" + alt + "](" + url.absoluteString + ")" : alt + "\n" + url.absoluteString)
                + (caption.isEmpty ? "" : "\n" + inline(caption))
        case .separator: return "---"
        }
    }

    private func table(_ rows: [SupportTableRow]) -> String {
        guard let first = rows.first else { return "" }
        let lines = rows.map { row in
            "| "
                + row.cells.map {
                    blocks($0.content).replacingOccurrences(of: "\n", with: " ")
                        .replacingOccurrences(of: "|", with: "\\|")
                }.joined(separator: " | ") + " |"
        }
        guard agent else { return lines.joined(separator: "\n") }
        let separator = "| " + first.cells.map { _ in "---" }.joined(separator: " | ") + " |"
        if first.cells.allSatisfy(\.isHeader) {
            return ([lines[0], separator] + lines.dropFirst()).joined(separator: "\n")
        }
        let header = "| " + first.cells.map { _ in " " }.joined(separator: " | ") + " |"
        return ([header, separator] + lines).joined(separator: "\n")
    }

    private func fenced(_ text: String, language: String) -> String {
        let longest = text.split(whereSeparator: { $0 != "`" }).map(\.count).max() ?? 0
        let fence = String(repeating: "`", count: max(3, longest + 1))
        return fence + language + "\n" + text + "\n" + fence
    }
}
