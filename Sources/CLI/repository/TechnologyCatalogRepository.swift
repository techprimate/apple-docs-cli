import Foundation

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

#if DEBUG
    protocol TechnologyCatalogRepository: Sendable {
        func fetchTechnologies() async throws -> [Technology]
    }

    extension DefaultAppleDocumentationRepository: TechnologyCatalogRepository {}

    protocol TechnologyCatalogRepositoryProvider {
        associatedtype Repository: TechnologyCatalogRepository
        var documentationRepository: Repository { get }
    }

    extension Dependencies: TechnologyCatalogRepositoryProvider {}
#else
    typealias TechnologyCatalogRepository = DefaultAppleDocumentationRepository<
        DefaultAppleDocumentationClient<URLSession>
    >
#endif
