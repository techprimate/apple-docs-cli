import Foundation

enum SupportPayload: Sendable {
    case articles(SupportArticlesCatalog)
    case help(SupportHelpCatalog)
    case contents(SupportGuideContents)
    case glossary(SupportGlossary)
    case glossaryEntry(SupportGlossaryEntry)
    case terms(SupportTermsCatalog)
    case termsEntry(SupportTermsEntry)
    case article(SupportArticle)
    case pdf(SupportPDF)

    var kind: String {
        switch self {
        case .articles: return "articlesCatalog"
        case .help: return "helpCatalog"
        case .contents: return "guideContents"
        case .glossary: return "glossary"
        case .glossaryEntry: return "glossaryEntry"
        case .terms: return "termsCatalog"
        case .termsEntry: return "termsEntry"
        case .article: return "article"
        case .pdf: return "pdf"
        }
    }

    func encodeContent(to encoder: any Encoder) throws {
        switch self {
        case .articles(let value): try value.encode(to: encoder)
        case .help(let value): try value.encode(to: encoder)
        case .contents(let value): try value.encode(to: encoder)
        case .glossary(let value): try value.encode(to: encoder)
        case .glossaryEntry(let value): try value.encode(to: encoder)
        case .terms(let value): try value.encode(to: encoder)
        case .termsEntry(let value): try value.encode(to: encoder)
        case .article(let value): try value.encode(to: encoder)
        case .pdf(let value): try value.encode(to: encoder)
        }
    }
}

struct SupportNavigation: Encodable, Sendable {
    let title: String
    let url: URL?
    let command: String
}

struct SupportPresentation: Encodable, Sendable {
    let payload: SupportPayload
    let navigation: [SupportNavigation]?

    private enum CodingKeys: CodingKey { case kind, navigation }

    func encode(to encoder: any Encoder) throws {
        try payload.encodeContent(to: encoder)
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(payload.kind, forKey: .kind)
        try container.encodeIfPresent(navigation, forKey: .navigation)
    }
}

struct SupportPresenter {
    func present(_ payload: SupportPayload, audience: OutputAudience) -> SupportPresentation {
        SupportPresentation(payload: payload, navigation: audience == .agent ? navigation(payload) : nil)
    }

    private func navigation(_ payload: SupportPayload) -> [SupportNavigation] {
        switch payload {
        case .glossary(let glossary):
            return glossary.entries.map { glossaryNavigation($0) }
        case .glossaryEntry(let entry):
            return [glossaryNavigation(entry)]
        case .terms(let catalog):
            return catalog.categories.flatMap(\.entries).map(termsNavigation)
        case .termsEntry(let entry):
            return entry.resources.compactMap { followUp($0.link) }
        default:
            return references(payload).compactMap(followUp)
        }
    }

    private func glossaryNavigation(_ entry: SupportGlossaryEntry) -> SupportNavigation {
        SupportNavigation(
            title: entry.term, url: nil,
            command: "apple-docs support glossary view --term " + quote(entry.term) + " --agent")
    }

    private func termsNavigation(_ entry: SupportTermsEntry) -> SupportNavigation {
        SupportNavigation(
            title: entry.title, url: nil,
            command: "apple-docs support terms view --name " + quote(entry.id) + " --agent")
    }

    private func references(_ payload: SupportPayload) -> [SupportPageLink] {
        switch payload {
        case .articles(let catalog): return catalog.categories.flatMap(\.links)
        case .help(let catalog):
            return catalog.featuredResources.map(\.link) + catalog.topics.flatMap { $0.groups.flatMap(\.links) }
                + [catalog.glossary.link]
        case .contents(let contents): return contents.entries.flatMap(contentsReferences)
        case .article(let article): return article.related
        default: return []
        }
    }

    private func contentsReferences(_ entry: SupportContentsEntry) -> [SupportPageLink] {
        (entry.link.map { [$0] } ?? []) + entry.children.flatMap(contentsReferences)
    }

    private func followUp(_ link: SupportPageLink) -> SupportNavigation? {
        guard let destination = try? SupportDestination(responseURL: link.url) else { return nil }
        let path = destination.path
        let parts = path.split(separator: "/")
        let command: String
        switch path {
        case "help": command = "apple-docs support guides list"
        case "help/glossary": command = "apple-docs support glossary list"
        case "support/articles": command = "apple-docs support articles list"
        case "support/terms": command = "apple-docs support terms list"
        default:
            if parts.count == 2, parts[0] == "help", ["account", "app-store-connect", "app-review"].contains(parts[1]) {
                command = "apple-docs support guides contents --name " + quote(String(parts[1]))
            } else if isReadable(path) {
                command = "apple-docs support view --path " + quote(path)
            } else {
                return nil
            }
        }
        return SupportNavigation(title: link.title, url: link.url, command: command + " --agent")
    }

    private func isReadable(_ path: String) -> Bool {
        let parts = path.split(separator: "/")
        guard !path.lowercased().hasSuffix(".pdf") else { return false }
        return
            (parts.count > 2 && parts[0] == "help"
            && ["account", "app-store-connect", "app-review"].contains(parts[1]))
            || path.hasPrefix("support/")
            || path == "xcode/system-requirements"
    }

    private func quote(_ text: String) -> String {
        "'" + text.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
