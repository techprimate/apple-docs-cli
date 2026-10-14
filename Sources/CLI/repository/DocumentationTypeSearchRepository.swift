import Foundation

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

struct DocumentationSearchResult: Equatable, Sendable {
    let technology: String
    let types: [DocumentationType]
    let unavailableCollections: [DocumentationCollectionFailure]

    var isComplete: Bool { unavailableCollections.isEmpty }
}

struct DocumentationCollectionFailure: Equatable, Sendable {
    enum Reason: Equatable, Sendable {
        case httpStatus(Int)
        case invalidResponse
        case transport(Int)
        case decoding
    }

    let path: String
    let reason: Reason

    static func reason(for error: any Error) -> Reason? {
        if let error = error as? AppleDocumentationClientError {
            switch error {
            case .httpStatus(let status): return .httpStatus(status)
            case .invalidResponse: return .invalidResponse
            }
        }
        if let error = error as? URLError { return .transport(error.code.rawValue) }
        if error is DecodingError { return .decoding }
        return nil
    }
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
