import Foundation

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

#if DEBUG
    protocol DocumentationTypeCatalogClient: Sendable {
        func fetchTypes(technology: String) async throws -> [DocumentationType]
    }

    extension DefaultAppleDocumentationClient: DocumentationTypeCatalogClient {}

    protocol DocumentationTypeCatalogClientProvider {
        associatedtype Client: DocumentationTypeCatalogClient
        var documentationClient: Client { get }
    }

    extension Dependencies: DocumentationTypeCatalogClientProvider {}
#else
    typealias DocumentationTypeCatalogClient = DefaultAppleDocumentationClient<URLSession>
#endif
