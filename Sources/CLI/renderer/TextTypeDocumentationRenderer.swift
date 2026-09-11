struct TextTypeDocumentationRenderer: Sendable {
    private let layout = DocumentationTextLayout()

    func render(_ page: TypeDocumentationPageDTO) -> String {
        let content = DocumentationContentRenderer(references: page.references)
        let metadata = ([page.metadata.roleHeading] + page.metadata.modules.map(\.name))
            .filter { !$0.isEmpty }.joined(separator: " · ")
        var sections = [layout.heading(page.metadata.title, prominent: true) + "\n" + metadata]

        let abstract = content.inlineText(page.abstract)
        if !abstract.isEmpty {
            sections.append(layout.paragraph(abstract))
        }

        let deprecation = content.render(page.deprecationSummary ?? [])
        if !deprecation.isEmpty {
            sections.append(layout.heading("Deprecated") + "\n" + deprecation)
        }

        let availability = page.metadata.platforms.map { platform in
            (platform.name, availabilityRange(for: platform))
        }
        if !availability.isEmpty {
            sections.append(layout.heading("Availability") + "\n" + layout.table(availability))
        }

        let declarations = swiftDeclarations(in: page)
        if !declarations.isEmpty {
            sections.append(layout.heading("Declaration") + "\n" + declarations.joined(separator: "\n\n"))
        }

        let overview = content.render(
            page.primaryContentSections.filter { $0.kind == "content" }.flatMap { $0.content ?? [] }
        )
        if !overview.isEmpty {
            sections.append(overview)
        }

        sections += referenceSections(page.relationshipsSections ?? [], content: content)
        appendGroup("Topics", page.topicSections ?? [], content: content, includesAbstract: true, to: &sections)
        appendGroup("See Also", page.seeAlsoSections ?? [], content: content, to: &sections)

        if let path = page.variants?.lazy.flatMap(\.paths).first {
            sections.append(layout.heading("Documentation") + "\n  " + documentationURL(for: path))
        }

        return sections.joined(separator: "\n\n")
    }

    private func swiftDeclarations(in page: TypeDocumentationPageDTO) -> [String] {
        page.primaryContentSections
            .filter { $0.kind == "declarations" }
            .flatMap { $0.declarations ?? [] }
            .filter { $0.languages.contains("swift") }
            .map {
                let lines = $0.tokens.map(\.text).joined().split(separator: "\n", omittingEmptySubsequences: false)
                return layout.codeBlock(lines.map(String.init), language: "swift")
            }
    }

    private func appendGroup(
        _ title: String,
        _ groups: [DocumentationReferenceSectionDTO],
        content: DocumentationContentRenderer,
        includesAbstract: Bool = false,
        to sections: inout [String]
    ) {
        let rendered = referenceSections(groups, content: content, includesAbstract: includesAbstract)
        if !rendered.isEmpty {
            sections.append(layout.heading(title, prominent: true))
            sections += rendered
        }
    }

    private func referenceSections(
        _ groups: [DocumentationReferenceSectionDTO],
        content: DocumentationContentRenderer,
        includesAbstract: Bool = false
    ) -> [String] {
        groups.compactMap { group in
            let items = group.identifiers.compactMap { identifier -> String? in
                guard let reference = content.references[identifier], let title = reference.title else {
                    return nil
                }
                var item = layout.paragraph(title, indent: "    ", firstPrefix: "  • ")
                let abstract = content.inlineText(reference.abstract ?? [])
                if includesAbstract && !abstract.isEmpty {
                    item += "\n" + layout.paragraph(abstract, indent: "    ")
                }
                if let url = reference.url {
                    // Keep URLs intact so terminal link detection and copy/paste still work.
                    item += "\n    " + documentationURL(for: url)
                }
                return item
            }
            guard !items.isEmpty else { return nil }
            return layout.heading(group.title) + "\n" + items.joined(separator: "\n\n")
        }
    }

    private func availabilityRange(for platform: DocumentationPlatform) -> String {
        switch (platform.introducedAt, platform.deprecatedAt) {
        case (let introduced?, let deprecated?):
            return "\(introduced)–\(deprecated)"
        case (let introduced?, nil):
            return "\(introduced)+"
        case (nil, let deprecated?):
            return "Until \(deprecated)"
        case (nil, nil):
            return "Available"
        }
    }

    private func documentationURL(for path: String) -> String {
        if path.hasPrefix("http://") || path.hasPrefix("https://") {
            return path
        }
        return "https://developer.apple.com\(path)"
    }
}
