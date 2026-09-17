enum BrowserEntry: Equatable, Sendable {
    case type(name: String, technology: String)
    case types(technology: String)
    case technologies
    case search(query: String, technology: String)

    var technology: String? {
        switch self {
        case .type(_, let technology), .types(let technology), .search(_, let technology):
            return technology.lowercased()
        case .technologies: return nil
        }
    }
}

enum BrowserLocation: Equatable, Sendable {
    case page(DocumentationDestination)
    case types(technology: String)
    case technologies

    var technology: String? {
        switch self {
        case .page(let destination): return destination.technology
        case .types(let technology): return technology.lowercased()
        case .technologies: return nil
        }
    }
}

enum BrowserFocus: Equatable, Sendable {
    case navigator, document, searchInput, searchResults, logs
}

struct BrowserViewport: Equatable, Sendable {
    var topRow = 0
    var selectedLinkID: String?
}

struct BrowserPageRequest: Equatable, Sendable {
    let id: UInt64
    let destination: DocumentationDestination
    let history: BrowserHistory?
}

struct BrowserState: Equatable, Sendable {
    let entry: BrowserEntry
    var currentLocation: BrowserLocation?
    var currentPage: DocumentationPage?
    var history = BrowserHistory()
    var focus: BrowserFocus = .document
    var navigatorVisible = true
    var technologyNavigators: [String: NavigatorState] = [:]
    var catalogNavigator = NavigatorState()
    var technologySearches: [String: SearchState] = [:]
    var viewport = BrowserViewport()
    var logsVisible = false
    var previousLogFocus: BrowserFocus = .document
    var pageError: String?
    var pendingNavigation: BrowserPageRequest?
    var failedNavigation: BrowserPageRequest?
    var nextRequestID: UInt64 = 0

    var pendingPageRequestID: UInt64? { pendingNavigation?.id }
    var technology: String? { currentLocation.map(\.technology) ?? entry.technology }

    var search: SearchState? { technology.flatMap { technologySearches[$0] } }

    var navigatorTree: NavigatorState {
        get {
            guard let technology else { return catalogNavigator }
            return technologyNavigators[technology] ?? NavigatorState()
        }
        set {
            if let technology { technologyNavigators[technology] = newValue } else { catalogNavigator = newValue }
        }
    }

    var navigator: NavigatorSnapshot {
        get { navigatorTree.snapshot }
        set { navigatorTree.snapshot = newValue }
    }

    var snapshot: BrowserHistoryEntry? {
        guard let currentLocation else { return nil }
        var mainFocus = focus == .logs ? previousLogFocus : focus
        if mainFocus == .searchInput || mainFocus == .searchResults, let search {
            mainFocus = search.previousFocus == .logs ? search.previousLogFocus : search.previousFocus
        }
        return BrowserHistoryEntry(
            location: currentLocation, viewport: viewport, navigator: navigator, focus: mainFocus
        )
    }
}
