import Foundation

enum AppleDocumentationRepositoryError: Swift.Error, Equatable {
    case technologyNotFound(String)
    case typeNotFound(
        name: String,
        technology: String,
        suggestion: DocumentationType?,
        technologyURL: String
    )
    case unsupportedTechnology(name: String, url: String)

}

extension DefaultAppleDocumentationRepository {
    struct ResolvedTechnology {
        let name: String
        let documentationSlug: String?
        let url: String
    }
}
