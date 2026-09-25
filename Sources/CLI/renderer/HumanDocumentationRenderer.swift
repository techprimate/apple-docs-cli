import Foundation

struct HumanDocumentationRenderer: Sendable {
    private let layout = DocumentationTextLayout()
    private let content = DocumentationContentRenderer(audience: .human)

    func render(_ presentation: PagePresentation) -> String {
        let page = presentation.document
        let metadata = ([page.roleHeading ?? page.kind.capitalized] + page.modules)
            .filter { !$0.isEmpty }.joined(separator: " · ")
        var header = layout.heading(page.title, prominent: true) + "\n" + metadata
        if let symbolKind = page.symbolKind {
            header += "\nSymbol kind: " + symbolKind
        }
        var sections = [header]
        let summary = content.inline(page.abstract)
        if !summary.isEmpty { sections.append(layout.paragraph(summary)) }
        append("Deprecated", content.blocks(page.deprecation, indent: "  "), to: &sections)
        append(
            "Availability", layout.table(page.availability.map { ($0.name, content.availability($0)) }), to: &sections)
        append(
            "Declaration",
            page.declarations.map {
                content.code($0.text.components(separatedBy: "\n"), language: $0.languages.first, indent: "  ")
            }.joined(separator: "\n\n"), to: &sections)
        let body = content.blocks(page.content, indent: "  ")
        if !body.isEmpty { sections.append(body) }
        sections += groups(presentation.relationships)
        appendGroups("Topics", presentation.topics, to: &sections)
        appendGroups("See Also", presentation.seeAlso, to: &sections)
        sections.append(layout.heading("Documentation") + "\n  " + page.url.absoluteString)
        return terminalSafeText(sections.joined(separator: "\n\n"))
    }

    func render(_ symbols: [SymbolPresentation]) -> String {
        guard !symbols.isEmpty else { return "No symbols found." }
        return table(
            headers: ["SYMBOL", "KIND", "PATH", "URL"],
            rows: symbols.map { [$0.name, $0.kind, $0.path, $0.url] })
    }

    func render(_ technologies: [TechnologyPresentation]) -> String {
        table(headers: ["TECHNOLOGY", "IDENTIFIER"], rows: technologies.map { [$0.name, $0.identifier] })
    }

    private func table(headers: [String], rows: [[String]]) -> String {
        let values = ([headers] + rows).map { $0.map(terminalSafeText) }
        let widths = headers.indices.map { column in values.map { $0[column].count }.max() ?? 0 }
        return values.map { row in
            row.enumerated().map { column, value in
                column == row.count - 1 ? value : value + String(repeating: " ", count: widths[column] - value.count)
            }.joined(separator: "  ")
        }.joined(separator: "\n")
    }

    private func append(_ title: String, _ body: String, to sections: inout [String]) {
        if !body.isEmpty { sections.append(layout.heading(title) + "\n" + body) }
    }

    private func appendGroups(_ title: String, _ entries: [GroupPresentation], to sections: inout [String]) {
        let rendered = groups(entries)
        if !rendered.isEmpty { sections += [layout.heading(title, prominent: true)] + rendered }
    }

    private func groups(_ groups: [GroupPresentation]) -> [String] {
        groups.compactMap { group in
            let entries = group.references.map { item in
                let reference = item.reference
                var text = layout.paragraph(reference.title, indent: "    ", firstPrefix: "  • ")
                let abstract = content.inline(reference.abstract)
                if !abstract.isEmpty { text += "\n" + layout.paragraph(abstract, indent: "    ") }
                if let url = content.url(for: reference.target) { text += "\n    " + url }
                return text
            }
            guard !entries.isEmpty else { return nil }
            return layout.heading(group.title) + "\n" + entries.joined(separator: "\n\n")
        }
    }
}
