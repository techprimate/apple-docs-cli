import Foundation

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

#if DEBUG
    protocol DocumentationPageClient: Sendable {
        func fetchDocument(at destination: DocumentationDestination) async throws -> TypeDocumentationDocument
        func fetchRootDocument(technology: String) async throws -> TypeDocumentationDocument
    }

    extension DefaultAppleDocumentationClient: DocumentationPageClient {}
#else
    typealias DocumentationPageClient = DefaultAppleDocumentationClient<URLSession>
#endif
