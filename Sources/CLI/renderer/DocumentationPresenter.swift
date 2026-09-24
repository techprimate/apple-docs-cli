import Foundation

struct DocumentationPresenter: Sendable {
    func page(_ page: DocumentationPage, audience: OutputAudience) -> PagePresentation {
        PagePresentation(
            document: page, audience: audience,
            navigation: audience == .agent ? navigation(for: page.destination) : nil,
            relationships: groups(page.relationships, audience: audience),
            topics: groups(page.topics, audience: audience),
            seeAlso: groups(page.seeAlso, audience: audience)
        )
    }

    func symbols(
        _ symbols: [DocumentationType], technology: String, audience: OutputAudience
    ) -> [SymbolPresentation] {
        let root = DocumentationDestination(
            technology: technology.lowercased(), path: "/documentation/\(technology.lowercased())"
        )
        return symbols.map { symbol in
            let target = try? DocumentationDestination.resolve(symbol.url, relativeTo: root)
            return SymbolPresentation(
                name: symbol.name, kind: symbol.kind, path: symbol.path, url: symbol.url,
                navigation: audience == .agent ? target.flatMap(navigation(for:)) : nil
            )
        }
    }

    func technologies(_ technologies: [Technology], audience: OutputAudience) -> [TechnologyPresentation] {
        technologies.map { technology in
            TechnologyPresentation(
                name: technology.name, identifier: technology.identifier,
                navigation: audience == .agent ? technologyNavigation(technology.identifier) : nil
            )
        }
    }

    private func groups(_ groups: [DocumentationGroup], audience: OutputAudience) -> [GroupPresentation] {
        groups.map { group in
            GroupPresentation(
                id: group.id, title: group.title,
                references: group.references.map {
                    ReferencePresentation(
                        reference: $0, navigation: audience == .agent ? navigation(for: $0.target) : nil
                    )
                }
            )
        }
    }

    private func technologyNavigation(_ identifier: String) -> AgentNavigation? {
        guard let components = URLComponents(string: identifier) else { return nil }
        let raw = components.scheme == "doc" ? components.path : identifier
        let base = DocumentationDestination(technology: "", path: "/documentation")
        guard let target = try? DocumentationDestination.resolve(raw, relativeTo: base),
            case .documentation(let destination) = target,
            destination.path.split(separator: "/").count == 2
        else { return nil }
        return navigation(for: destination)
    }

    private func navigation(for target: DocumentationLinkTarget) -> AgentNavigation? {
        guard case .documentation(let destination) = target else { return nil }
        return navigation(for: destination)
    }

    private func navigation(for destination: DocumentationDestination) -> AgentNavigation? {
        let components = destination.path.split(separator: "/")
        guard components.count >= 2, components[0] == "documentation",
            components[1].lowercased() == destination.technology
        else { return nil }
        let technology = shellQuote(destination.technology)
        if components.count == 2 {
            return AgentNavigation(
                technology: destination.technology, path: nil,
                command: "apple-docs types list --technology \(technology) --agent"
            )
        }
        let path = components.dropFirst(2).joined(separator: "/")
        // Named CLI input interprets dots as Swift hierarchy separators and lowercases paths.
        // Do not advertise an exact-link command that that input path cannot round-trip.
        guard !path.contains("."), path == path.lowercased() else { return nil }
        let command =
            path.hasPrefix("-")
            ? "apple-docs types view --technology \(technology) --agent -- \(shellQuote(path))"
            : "apple-docs types view \(shellQuote(path)) --technology \(technology) --agent"
        return AgentNavigation(technology: destination.technology, path: path, command: command)
    }
}

func shellQuote(_ value: String) -> String {
    "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
}
