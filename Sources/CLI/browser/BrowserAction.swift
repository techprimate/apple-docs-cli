enum BrowserAction: Equatable, Sendable {
    case open(DocumentationDestination)
    case pageLoaded(requestID: UInt64, page: LoadedDocumentationPage)
    case pageFailed(requestID: UInt64, message: String)
    case retry
    case back
    case forward
    case toggleNavigator
    case toggleLogs
    case tab
    case escape
    case quit
}

enum BrowserEffect: Equatable, Sendable {
    case loadPage(requestID: UInt64, destination: DocumentationDestination)
    case cancelPage(requestID: UInt64)
    case quit
}
