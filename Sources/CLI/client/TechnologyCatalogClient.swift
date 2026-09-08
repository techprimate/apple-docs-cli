import Foundation

#if DEBUG
    protocol TechnologyCatalogClient: Sendable {
        func fetchTechnologies() async throws -> [Technology]
    }

    extension DefaultAppleDocumentationClient: TechnologyCatalogClient {}
#else
    typealias TechnologyCatalogClient = DefaultAppleDocumentationClient<URLSession>
#endif
