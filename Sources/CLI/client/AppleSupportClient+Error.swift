import Foundation

enum AppleSupportClientError: Error, Equatable, LocalizedError {
    case invalidPath
    case invalidResponse
    case httpStatus(Int)
    case unsupportedContentType(String?)
    case invalidEncoding

    var errorDescription: String? {
        switch self {
        case .invalidPath:
            return "Expected a developer-site-relative path under help/ or support/ without a query or fragment."
        case .invalidResponse:
            return "Apple support returned an invalid response or redirected outside supported developer pages."
        case .httpStatus(let status):
            return "Apple support returned HTTP status \(status)."
        case .unsupportedContentType(let type):
            return "Apple support returned \(type ?? "no content type"); expected HTML."
        case .invalidEncoding:
            return "Apple support returned HTML that is not valid UTF-8."
        }
    }
}
