import Foundation

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

#if DEBUG
    protocol DocumentationTypeCatalogRepository: Sendable {
        func fetchTypes(technology: String) async throws -> [DocumentationType]
    }

    extension DefaultAppleDocumentationRepository: DocumentationTypeCatalogRepository {}

    protocol DocumentationTypeCatalogRepositoryProvider {
        associatedtype Repository: DocumentationTypeCatalogRepository
        var documentationRepository: Repository { get }
    }

    extension Dependencies: DocumentationTypeCatalogRepositoryProvider {}
#else
    typealias DocumentationTypeCatalogRepository = DefaultAppleDocumentationRepository<
        DefaultAppleDocumentationClient<URLSession>
    >
#endif
