import Foundation
import Logging

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

#if DEBUG
    protocol DocumentationRepository: Sendable {
        func type(named name: String, technology: String) async throws -> LoadedDocumentationPage
        func page(at destination: DocumentationDestination) async throws -> LoadedDocumentationPage
        func root(technology: String) async throws -> LoadedDocumentationPage
        func types(technology: String) async throws -> [DocumentationType]
        func search(query: String, technology: String) async throws -> DocumentationSearchResult
        func technologies() async throws -> [Technology]
    }

    typealias DefaultDocumentationRepositoryDependencies = AppleDocumentationClient & DocumentationPageClient
        & DocumentationTypeCatalogClient & DocumentationTypeSearchClient & TechnologyCatalogClient
    extension DefaultDocumentationRepository: DocumentationRepository {}
#else
    typealias DefaultDocumentationRepositoryDependencies = DefaultAppleDocumentationClient<URLSession>
    typealias DocumentationRepository = DefaultDocumentationRepository
#endif

struct LoadedDocumentationPage: Equatable, Sendable {
    let page: DocumentationPage
    let responseByteCount: Int
}

struct DefaultDocumentationRepository: Sendable {
    let logger: Logger
    let dependencies: DefaultDocumentationRepositoryDependencies
    private let decoder = DocumentationPageDecoder()

    func type(named name: String, technology: String) async throws -> LoadedDocumentationPage {
        let document = try await dependencies.fetchType(named: name, technology: technology)
        return try normalize(document, destination: document.destination)
    }

    func page(at destination: DocumentationDestination) async throws -> LoadedDocumentationPage {
        try normalize(try await dependencies.fetchDocument(at: destination), destination: destination)
    }

    func root(technology: String) async throws -> LoadedDocumentationPage {
        let root = try await dependencies.fetchRootDocument(technology: technology)
        return try normalize(root, destination: root.destination)
    }

    func types(technology: String) async throws -> [DocumentationType] {
        try await dependencies.fetchTypes(technology: technology)
    }

    func search(query: String, technology: String) async throws -> DocumentationSearchResult {
        try await dependencies.searchTypes(query: query, technology: technology)
    }

    func technologies() async throws -> [Technology] {
        try await dependencies.fetchTechnologies()
    }

    private func normalize(
        _ document: TypeDocumentationDocument, destination: DocumentationDestination
    ) throws -> LoadedDocumentationPage {
        let metadata: Logger.Metadata = [
            "path": .string(destination.path), "apple_docs.technology": .string(destination.technology),
            "bytes": .stringConvertible(document.data.count),
        ]
        logger.debug("Normalizing documentation page", metadata: metadata)
        do {
            let page = try decoder.decode(document.data, destination: destination)
            logger.debug("Normalized documentation page", metadata: metadata)
            return LoadedDocumentationPage(page: page, responseByteCount: document.data.count)
        } catch {
            logger.error("Failed to normalize documentation page", metadata: metadata)
            throw error
        }
    }
}
