import Foundation

#if DEBUG
    protocol DocumentationTypeCatalogClient: Sendable {
        func fetchTypes(technology: String) async throws -> [DocumentationType]
    }

    extension DefaultAppleDocumentationClient: DocumentationTypeCatalogClient {}
#else
    typealias DocumentationTypeCatalogClient = DefaultAppleDocumentationClient<URLSession>
#endif
