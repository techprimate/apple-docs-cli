import Foundation

struct TextTypeDocumentationRenderer: Sendable {
    private let layout = DocumentationTextLayout()
    private let content = DocumentationContentRenderer()

    func render(_ page: DocumentationPage) -> String {
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
        sections += groups(page.relationships)
        appendGroups("Topics", page.topics, to: &sections)
        appendGroups("See Also", page.seeAlso, to: &sections)
        sections.append(layout.heading("Documentation") + "\n  " + page.url.absoluteString)
        return terminalSafeText(sections.joined(separator: "\n\n"))
    }

    private func append(_ title: String, _ body: String, to sections: inout [String]) {
        if !body.isEmpty { sections.append(layout.heading(title) + "\n" + body) }
    }

    private func appendGroups(_ title: String, _ entries: [DocumentationGroup], to sections: inout [String]) {
        let rendered = groups(entries)
        if !rendered.isEmpty { sections += [layout.heading(title, prominent: true)] + rendered }
    }

    private func groups(_ groups: [DocumentationGroup]) -> [String] {
        groups.compactMap { group in
            let entries = group.references.map { reference in
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
