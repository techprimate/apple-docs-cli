import Foundation

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

#if DEBUG
    protocol AppleSupportService: Sendable {
        func fetchArticles(category: String?) async throws -> SupportArticlesCatalog
        func fetchHelp() async throws -> SupportHelpCatalog
        func fetchGuideContents(named name: String) async throws -> SupportGuideContents
        func fetchGlossary(query: String?) async throws -> SupportGlossary
        func fetchGlossaryEntry(term: String) async throws -> SupportGlossaryEntry
        func fetchTerms(category: String?) async throws -> SupportTermsCatalog
        func fetchTermsEntry(named name: String) async throws -> SupportTermsEntry
        func fetchDocument(path: String) async throws -> SupportDocument
    }
    extension DefaultAppleSupportService: AppleSupportService {}
    typealias DefaultAppleSupportServiceDependencies = AppleSupportClient
#else
    typealias AppleSupportService = DefaultAppleSupportService<DefaultAppleSupportClient<URLSession>>
    typealias DefaultAppleSupportServiceDependencies = DefaultAppleSupportClient<URLSession>
#endif

final class DefaultAppleSupportService<Dependencies: DefaultAppleSupportServiceDependencies>: Sendable {
    private let dependencies: Dependencies

    init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }

    func fetchArticles(category: String?) async throws -> SupportArticlesCatalog {
        var catalog = try await parser(path: "support/articles").articles()
        if let category {
            guard catalog.categories.contains(where: { $0.id == category }) else {
                throw SupportServiceError.notFound(kind: "article category", name: category)
            }
            catalog.categories = catalog.categories.filter { $0.id == category }
        }
        return catalog
    }

    func fetchHelp() async throws -> SupportHelpCatalog {
        try await parser(path: "help").help()
    }

    func fetchGuideContents(named name: String) async throws -> SupportGuideContents {
        guard !name.isEmpty,
            name.unicodeScalars.allSatisfy({
                CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789-").contains($0)
            })
        else { throw SupportServiceError.invalidGuideName }
        return try await parser(path: "help/" + name).contents()
    }

    func fetchGlossary(query: String?) async throws -> SupportGlossary {
        var glossary = try await parser(path: "help/glossary").glossary()
        if let query {
            glossary.entries = glossary.entries.filter { $0.term.localizedCaseInsensitiveContains(query) }
        }
        return glossary
    }

    func fetchGlossaryEntry(term: String) async throws -> SupportGlossaryEntry {
        let glossary = try await fetchGlossary(query: nil)
        guard let entry = glossary.entries.first(where: { $0.term.caseInsensitiveCompare(term) == .orderedSame }) else {
            throw SupportServiceError.notFound(kind: "glossary term", name: term)
        }
        return entry
    }

    func fetchTerms(category: String?) async throws -> SupportTermsCatalog {
        var catalog = try await parser(path: "support/terms").terms()
        if let category {
            guard catalog.categories.contains(where: { $0.id == category }) else {
                throw SupportServiceError.notFound(kind: "terms category", name: category)
            }
            catalog.categories = catalog.categories.filter { $0.id == category }
        }
        return catalog
    }

    func fetchTermsEntry(named name: String) async throws -> SupportTermsEntry {
        let catalog = try await fetchTerms(category: nil)
        guard let entry = catalog.categories.flatMap(\.entries).first(where: { $0.id == name }) else {
            throw SupportServiceError.notFound(kind: "terms entry", name: name)
        }
        return entry
    }

    func fetchDocument(path: String) async throws -> SupportDocument {
        let destination = try SupportDestination(path: path)
        switch try await dependencies.fetchDocument(at: destination) {
        case .html(let document): return try .article(SupportHTMLParser(document: document).article())
        case .pdf(let url): return .pdf(SupportPDF(url: url))
        }
    }

    private func parser(path: String) async throws -> SupportHTMLParser {
        let destination = try SupportDestination(path: path)
        return try await SupportHTMLParser(document: dependencies.fetchHTML(at: destination))
    }
}

enum SupportServiceError: Error, Equatable, LocalizedError {
    case invalidGuideName
    case notFound(kind: String, name: String)

    var errorDescription: String? {
        switch self {
        case .invalidGuideName: return "Expected a guide identifier such as app-store-connect, not a path or URL."
        case .notFound(let kind, let name): return "No Apple support \(kind) found for '\(name)'."
        }
    }
}
