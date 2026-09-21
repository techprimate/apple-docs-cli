@testable import CLI

struct UnexpectedRepositoryCall: Error {}

// Focused command doubles implement only the repository operations they expect.
extension DocumentationRepository {
    func type(named name: String, technology: String) async throws -> LoadedDocumentationPage {
        throw UnexpectedRepositoryCall()
    }
    func page(at destination: DocumentationDestination) async throws -> LoadedDocumentationPage {
        throw UnexpectedRepositoryCall()
    }
    func root(technology: String) async throws -> LoadedDocumentationPage {
        throw UnexpectedRepositoryCall()
    }
    func types(technology: String) async throws -> [DocumentationType] {
        throw UnexpectedRepositoryCall()
    }
    func search(query: String, technology: String) async throws -> DocumentationSearchResult {
        throw UnexpectedRepositoryCall()
    }
    func technologies() async throws -> [Technology] {
        throw UnexpectedRepositoryCall()
    }
}
