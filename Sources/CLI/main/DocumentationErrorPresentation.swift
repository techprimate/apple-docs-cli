import Foundation

extension AppleDocumentationRepositoryError: LocalizedError, ExpectedCommandError {
    var isExpected: Bool {
        switch self {
        case .technologyNotFound, .typeNotFound, .unsupportedTechnology:
            return true
        }
    }

    var errorDescription: String? {
        switch self {
        case .technologyNotFound(let technology):
            return """
                Apple documentation technology '\(technology)' was not found.

                Browse available technologies:
                  apple-docs technologies list
                """
        case .typeNotFound(let name, let technology, let suggestion, let technologyURL):
            var sections = ["No Apple documentation found for '\(name)' in \(technology)."]
            if let suggestion {
                sections.append(
                    """
                    Did you mean:
                      \(suggestion.name)
                      \(suggestion.url)
                    """
                )
            }
            sections.append(
                """
                Browse available types:
                  apple-docs types list --technology "\(technology)"
                  \(technologyURL)
                """
            )
            return sections.joined(separator: "\n\n")
        case .unsupportedTechnology(let name, let url):
            return """
                Type retrieval is unavailable for \(name).

                Continue in the technology documentation:
                  \(url)
                """
        }
    }
}
