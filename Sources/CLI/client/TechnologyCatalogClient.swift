import Foundation

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

#if DEBUG
    protocol TechnologyCatalogClient: Sendable {
        func fetchTechnologies() async throws -> [Technology]
    }

    extension DefaultAppleDocumentationClient: TechnologyCatalogClient {}

    protocol TechnologyCatalogClientProvider {
        associatedtype Client: TechnologyCatalogClient
        var documentationClient: Client { get }
    }

    extension Dependencies: TechnologyCatalogClientProvider {}
#else
    typealias TechnologyCatalogClient = DefaultAppleDocumentationClient<URLSession>
#endif
