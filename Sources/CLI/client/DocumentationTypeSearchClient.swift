import Foundation

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

#if DEBUG
    protocol DocumentationTypeSearchClient: Sendable {
        func searchTypes(query: String, technology: String) async throws -> [DocumentationType]
    }

    extension DefaultAppleDocumentationClient: DocumentationTypeSearchClient {}
#else
    typealias DocumentationTypeSearchClient = DefaultAppleDocumentationClient<URLSession>
#endif
