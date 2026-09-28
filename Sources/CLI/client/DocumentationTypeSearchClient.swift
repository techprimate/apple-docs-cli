import Foundation

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

struct DocumentationSearchResult: Equatable, Sendable {
    let types: [DocumentationType]
    let unavailableCollectionPaths: [String]
}

#if DEBUG
    protocol DocumentationTypeSearchClient: Sendable {
        func searchTypes(query: String, technology: String) async throws -> DocumentationSearchResult
    }

    extension DefaultAppleDocumentationClient: DocumentationTypeSearchClient {}

    protocol DocumentationTypeSearchClientProvider {
        associatedtype Client: DocumentationTypeSearchClient
        var documentationClient: Client { get }
    }

    extension Dependencies: DocumentationTypeSearchClientProvider {}
#else
    typealias DocumentationTypeSearchClient = DefaultAppleDocumentationClient<URLSession>
#endif
