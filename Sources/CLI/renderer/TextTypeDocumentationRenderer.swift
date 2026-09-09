struct TextTypeDocumentationRenderer: Sendable {
    func render(_ page: TypeDocumentationPageDTO) -> String {
        let modules = page.metadata.modules.map(\.name).joined(separator: ", ")
        var sections = ["\(page.metadata.title)\n\(page.metadata.roleHeading) · \(modules)"]

        let abstract = page.abstract.compactMap(\.text).joined()
        if !abstract.isEmpty {
            sections.append(abstract)
        }

        let deprecation =
            page.deprecationSummary?
            .compactMap(\.inlineContent)
            .map { inlineText($0, references: page.references) }
            .joined(separator: "\n") ?? ""
        if !deprecation.isEmpty {
            sections.append("Deprecated\n\n" + deprecation)
        }

        let declarations = swiftDeclarations(in: page)

        if !declarations.isEmpty {
            sections.append("Declaration\n\n" + declarations.joined(separator: "\n"))
        }

        let availability = page.metadata.platforms.map { platform in
            "  \(platform.name) \(availabilityRange(for: platform))"
        }
        if !availability.isEmpty {
            sections.append("Availability\n\n" + availability.joined(separator: "\n"))
        }

        appendReferenceSections(
            page.relationshipsSections ?? [],
            references: page.references,
            to: &sections
        )
        appendReferenceSections(
            page.topicSections ?? [],
            references: page.references,
            includesAbstract: true,
            to: &sections
        )
        appendReferenceSections(
            page.seeAlsoSections ?? [],
            references: page.references,
            titlePrefix: "See Also: ",
            to: &sections
        )

        if let path = page.variants?.lazy.flatMap(\.paths).first {
            sections.append("https://developer.apple.com\(path)")
        }

        return sections.joined(separator: "\n\n")
    }

    private func swiftDeclarations(in page: TypeDocumentationPageDTO) -> [String] {
        page.primaryContentSections
            .filter { $0.kind == "declarations" }
            .flatMap { $0.declarations ?? [] }
            .filter { $0.languages.contains("swift") }
            .map { "    " + $0.tokens.map(\.text).joined() }
    }

    private func appendReferenceSections(
        _ referenceSections: [DocumentationReferenceSectionDTO],
        references: [String: DocumentationReferenceDTO],
        titlePrefix: String = "",
        includesAbstract: Bool = false,
        to sections: inout [String]
    ) {
        for referenceSection in referenceSections {
            let items = referenceSection.identifiers.compactMap { identifier -> String? in
                guard let reference = references[identifier], let title = reference.title else {
                    return nil
                }

                var item = "  \(title)"
                let abstract =
                    reference.abstract.map {
                        inlineText($0, references: references)
                    } ?? ""
                if includesAbstract && !abstract.isEmpty {
                    item += " — \(abstract)"
                }
                if let url = reference.url {
                    item += "\n    \(documentationURL(for: url))"
                }
                return item
            }

            if !items.isEmpty {
                sections.append(
                    titlePrefix + referenceSection.title + "\n\n" + items.joined(separator: "\n")
                )
            }
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

    private func inlineText(
        _ content: [DocumentationTextDTO],
        references: [String: DocumentationReferenceDTO]
    ) -> String {
        content.map { item in
            if let text = item.text {
                return text
            }
            if let identifier = item.identifier {
                return references[identifier]?.title ?? identifier
            }
            // DocC encodes inline symbol spelling such as AppIntent as codeVoice, not text.
            return item.code ?? ""
        }.joined()
    }
}
