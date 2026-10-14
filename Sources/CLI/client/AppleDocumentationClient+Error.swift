import Foundation

enum AppleDocumentationClientError: Error, Equatable, LocalizedError {
    case httpStatus(Int)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .httpStatus(let status): return "Apple documentation returned HTTP status \(status)."
        case .invalidResponse: return "Apple documentation returned an invalid response."
        }
    }
}
