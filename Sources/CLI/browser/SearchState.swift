struct SearchState: Equatable, Sendable {
    var technology: String
    var query = ""
    var results: [DocumentationType] = []
    var selectedResultIndex: Int?
    var unavailableCollectionPaths: [String] = []
    var error: String?
    var pendingRequestID: UInt64?
    var nextRequestID: UInt64 = 0
    var isOpen = false
    var hasSearched = false
    var previousFocus: BrowserFocus = .document
    var previousLogFocus: BrowserFocus = .document
}
