import Foundation

struct DocumentationPageDecoder: Sendable {
    func decode(_ data: Data, destination: DocumentationDestination) throws -> DocumentationPage {
        let document = try JSONDecoder().decode(TypeDocumentationPageDTO.self, from: data)
        let kind = [document.metadata.symbolKind ?? "", document.metadata.role ?? "", document.kind ?? ""]
            .first { !$0.isEmpty }
        guard !document.metadata.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, let kind else {
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Missing page title or kind"))
        }
        let context = Context(references: document.references, destination: destination)
        return DocumentationPage(
            destination: destination,
            title: document.metadata.title,
            kind: kind,
            symbolKind: document.metadata.symbolKind,
            roleHeading: document.metadata.roleHeading.isEmpty ? nil : document.metadata.roleHeading,
            modules: document.metadata.modules.map(\.name),
            abstract: context.inline(document.abstract),
            deprecation: context.blocks(document.deprecationSummary ?? []),
            declarations: document.primaryContentSections.flatMap { $0.declarations ?? [] }.map {
                DocumentationDeclaration(languages: $0.languages, text: $0.tokens.map(\.text).joined())
            },
            availability: document.metadata.platforms.map {
                DocumentationAvailability(
                    name: $0.name, introducedAt: $0.introducedAt, deprecatedAt: $0.deprecatedAt,
                    obsoletedAt: $0.obsoletedAt, isBeta: $0.beta ?? false, isUnavailable: $0.unavailable ?? false
                )
            },
            content: context.blocks(document.primaryContentSections.flatMap { $0.content ?? [] }),
            relationships: context.groups(document.relationshipsSections ?? [], section: "relationships"),
            topics: context.groups(document.topicSections ?? [], section: "topics"),
            seeAlso: context.groups(document.seeAlsoSections ?? [], section: "seeAlso")
        )
    }

    private struct Context {
        let references: [String: DocumentationReferenceDTO]
        let destination: DocumentationDestination

        func inline(_ content: [DocumentationTextDTO]) -> [DocumentationInline] {
            content.flatMap { item -> [DocumentationInline] in
                if let identifier = item.identifier {
                    let label = item.overridingTitle ?? item.text ?? references[identifier]?.title ?? identifier
                    return [.link(label: [.text(label)], target: target(identifier))]
                }
                if let code = item.code { return [.code(code)] }
                if let text = item.text { return [.text(text)] }
                return inline(item.inlineContent ?? [])
            }
        }

        func blocks(_ content: [DocumentationBlockDTO]) -> [DocumentationBlock] {
            content.compactMap { block in
                switch block {
                case .paragraph(let content): return .paragraph(inline(content))
                case .heading(let text): return .heading(text)
                case .codeListing(let code, let syntax): return .codeListing(code: code, syntax: syntax)
                case .orderedList(let items, let startIndex):
                    return .orderedList(items: items.map { blocks($0.content) }, startIndex: startIndex)
                case .unorderedList(let items): return .unorderedList(items.map { blocks($0.content) })
                case .aside(let content, let style, let name):
                    return .aside(content: blocks(content), style: style, name: name)
                case .unsupported: return nil
                }
            }
        }

        func groups(_ groups: [DocumentationReferenceSectionDTO], section: String) -> [DocumentationGroup] {
            groups.enumerated().map { index, group in
                DocumentationGroup(
                    id: "\(section)/\(index)", title: group.title,
                    references: group.identifiers.compactMap { identifier in
                        guard let reference = references[identifier], let title = reference.title else { return nil }
                        return DocumentationReference(
                            id: identifier, title: title, kind: reference.kind ?? reference.role ?? "",
                            abstract: inline(reference.abstract ?? []), target: target(identifier)
                        )
                    }
                )
            }
        }

        private func target(_ identifier: String) -> DocumentationLinkTarget {
            // DocC identifiers are meaningful only in this page's reference dictionary.
            let raw = references[identifier]?.url ?? identifier
            return (try? DocumentationDestination.resolve(raw, relativeTo: destination)) ?? .unavailable(identifier)
        }
    }
}
