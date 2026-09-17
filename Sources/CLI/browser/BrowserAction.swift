import Foundation

enum BrowserAction: Equatable, Sendable {
    case start
    case openNamed(name: String, technology: String)
    case ensureRoot(technology: String)
    case retryRoot(technology: String)
    case rootLoaded(requestID: UInt64, technology: String, page: LoadedDocumentationPage)
    case rootFailed(requestID: UInt64, technology: String, message: String)
    case typesLoaded(requestID: UInt64, technology: String, types: [DocumentationType])
    case typesFailed(requestID: UInt64, technology: String, message: String)
    case technologiesLoaded(requestID: UInt64, technologies: [Technology])
    case technologiesFailed(requestID: UInt64, message: String)
    case openExternal(URL)
    case externalOpened(requestID: UInt64)
    case externalFailed(requestID: UInt64, message: String)
    case open(DocumentationDestination)
    case pageLoaded(requestID: UInt64, page: LoadedDocumentationPage)
    case pageFailed(requestID: UInt64, message: String)
    case expand(NavigatorNodeID)
    case collapse(NavigatorNodeID)
    case childrenLoaded(nodeID: NavigatorNodeID, requestID: UInt64, page: DocumentationPage)
    case childrenFailed(nodeID: NavigatorNodeID, requestID: UInt64, message: String)
    case showSearch
    case editQuery(String)
    case submitSearch
    case searchLoaded(requestID: UInt64, technology: String, result: DocumentationSearchResult)
    case searchFailed(requestID: UInt64, technology: String, message: String)
    case activateSearchResult(Int)
    case dismissSearch
    case operationCancelled(UInt64)
    case retry
    case back
    case forward
    case toggleNavigator
    case toggleLogs
    case tab
    case escape
    case quit

    var searchTechnology: String? {
        switch self {
        case .searchLoaded(_, let technology, _), .searchFailed(_, let technology, _): return technology
        default: return nil
        }
    }

    var navigatorNodeID: NavigatorNodeID? {
        switch self {
        case .expand(let id), .collapse(let id), .childrenLoaded(let id, _, _), .childrenFailed(let id, _, _):
            return id
        default: return nil
        }
    }
}

enum BrowserEffect: Equatable, Sendable {
    case openExternal(requestID: UInt64, url: URL)
    case loadNamedPage(requestID: UInt64, name: String, technology: String)
    case loadRoot(requestID: UInt64, technology: String)
    case loadTypes(requestID: UInt64, technology: String)
    case loadTechnologies(requestID: UInt64)
    case loadPage(requestID: UInt64, destination: DocumentationDestination)
    case cancelPage(requestID: UInt64)
    case search(requestID: UInt64, technology: String, query: String)
    case cancelSearch(requestID: UInt64)
    case loadChildren(nodeID: NavigatorNodeID, requestID: UInt64, destination: DocumentationDestination)
    case quit
}
