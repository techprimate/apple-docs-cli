import Foundation

struct AgentDocumentationRenderer: Sendable {
    private let content = DocumentationContentRenderer(audience: .agent)

    func render(_ presentation: PagePresentation) -> String {
        let page = presentation.document
        var sections = [
            "# " + content.markdown(page.title),
            "Technology: " + content.inlineCode(page.destination.technology)
                + "\nPath: " + content.inlineCode(page.destination.path)
                + "\nKind: " + content.markdown(page.kind)
                + "\nURL: " + page.url.absoluteString,
        ]
        if !page.modules.isEmpty {
            sections.append("Modules: " + page.modules.map(content.markdown).joined(separator: ", "))
        }
        if let navigation = presentation.navigation { sections.append(command(navigation)) }
        append("Summary", content.inline(page.abstract), to: &sections)
        append("Deprecated", content.blocks(page.deprecation), to: &sections)
        append(
            "Declaration",
            page.declarations.map {
                content.code($0.text.components(separatedBy: "\n"), language: $0.languages.first)
            }.joined(separator: "\n\n"), to: &sections)
        append(
            "Availability",
            page.availability.map {
                "- " + content.markdown($0.name) + ": " + content.availability($0)
            }.joined(separator: "\n"), to: &sections)
        append("Content", content.blocks(page.content), to: &sections)
        append("Relationships", groups(presentation.relationships), to: &sections)
        append("Topics", groups(presentation.topics), to: &sections)
        append("See Also", groups(presentation.seeAlso), to: &sections)
        return terminalSafeText(sections.joined(separator: "\n\n"))
    }

    func render(_ symbols: [SymbolPresentation], technology: String) -> String {
        let header = "# Symbols\n\nTechnology: " + content.inlineCode(technology)
        let entries = symbols.map { symbol in
            var parts = [
                "## " + content.markdown(symbol.name), "Kind: " + content.markdown(symbol.kind),
                "Path: " + content.inlineCode(symbol.path), "URL: " + symbol.url,
            ]
            if let navigation = symbol.navigation { parts.append(command(navigation)) }
            return parts.joined(separator: "\n\n")
        }
        return terminalSafeText(
            ([header] + (entries.isEmpty ? ["No symbols found."] : entries)).joined(separator: "\n\n"))
    }

    func render(_ technologies: [TechnologyPresentation]) -> String {
        let entries = technologies.map { technology in
            var parts = [
                "## " + content.markdown(technology.name), "Identifier: " + content.inlineCode(technology.identifier),
            ]
            if let navigation = technology.navigation { parts.append(command(navigation)) }
            return parts.joined(separator: "\n\n")
        }
        return terminalSafeText((["# Technologies"] + entries).joined(separator: "\n\n"))
    }

    private func append(_ title: String, _ body: String, to sections: inout [String]) {
        if !body.isEmpty { sections.append("## " + title + "\n\n" + body) }
    }

    private func groups(_ groups: [GroupPresentation]) -> String {
        groups.map { group in
            let entries = group.references.map { item in
                let reference = item.reference
                var parts = [content.link(content.markdown(reference.title), target: reference.target)]
                let abstract = content.inline(reference.abstract)
                if !abstract.isEmpty { parts.append(abstract) }
                if let navigation = item.navigation { parts.append(command(navigation)) }
                return parts.joined(separator: "\n\n")
            }
            return (["### " + content.markdown(group.title)] + entries).joined(separator: "\n\n")
        }.joined(separator: "\n\n")
    }

    private func command(_ navigation: AgentNavigation) -> String {
        content.code([navigation.command], language: "sh")
    }
}
