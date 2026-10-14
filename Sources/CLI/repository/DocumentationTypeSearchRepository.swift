import Foundation

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

struct DocumentationSearchResult: Equatable, Sendable {
    let types: [DocumentationType]
    let unavailableCollectionPaths: [String]
}

#if DEBUG
    protocol DocumentationTypeSearchRepository: Sendable {
        func searchTypes(query: String, technology: String) async throws -> DocumentationSearchResult
    }

    extension DefaultAppleDocumentationRepository: DocumentationTypeSearchRepository {}

    protocol DocumentationTypeSearchRepositoryProvider {
        associatedtype Repository: DocumentationTypeSearchRepository
        var documentationRepository: Repository { get }
    }

    extension Dependencies: DocumentationTypeSearchRepositoryProvider {}
#else
    typealias DocumentationTypeSearchRepository = DefaultAppleDocumentationRepository<
        DefaultAppleDocumentationClient<URLSession>
    >
#endif
