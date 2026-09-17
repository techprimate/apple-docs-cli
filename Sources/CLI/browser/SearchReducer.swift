import Foundation

enum SearchReducer {
    static func reduce(state: inout SearchState, action: BrowserAction) -> [BrowserEffect] {
        switch action {
        case .showSearch: state.isOpen = true
        case .editQuery, .selectSearchResult: edit(state: &state, action: action)
        case .submitSearch: return submit(state: &state)
        case .dismissSearch:
            state.isOpen = false
            return cancel(state: &state)
        case .searchLoaded(let requestID, let technology, let result):
            guard accepts(requestID, technology: technology, state: state) else { return [] }
            state.pendingRequestID = nil
            state.results = result.types
            state.selectedResultIndex = result.types.isEmpty ? nil : 0
            state.unavailableCollectionPaths = result.unavailableCollectionPaths
            state.error = nil
            state.hasSearched = true
        case .searchFailed(let requestID, let technology, let message):
            guard accepts(requestID, technology: technology, state: state) else { return [] }
            state.pendingRequestID = nil
            state.error = message
        default: break
        }
        return []
    }

    static func reduceBrowser(state: inout BrowserState, action: BrowserAction) -> [BrowserEffect] {
        if case .activateSearchResult(let index) = action { return activate(index, state: &state) }
        guard let requestedTechnology = action.searchTechnology ?? state.technology else { return [] }
        let technology = state.canonicalTechnology(requestedTechnology)
        let action = scoped(action, technology: technology)
        var search = state.technologySearches[technology] ?? SearchState(technology: technology)
        if action == .showSearch && !search.isOpen {
            search.previousFocus = state.focus
            search.previousLogFocus = state.previousLogFocus
        }
        search.nextRequestID = state.nextRequestID
        let effects = reduce(state: &search, action: action)
        state.nextRequestID = search.nextRequestID
        state.technologySearches[technology] = search
        if action == .showSearch { state.focus = .searchInput }
        if action == .dismissSearch { restoreFocus(search, state: &state) }
        return effects
    }

    private static func edit(state: inout SearchState, action: BrowserAction) {
        guard state.isOpen else { return }
        switch action {
        case .editQuery(let query): state.query = query
        case .selectSearchResult(let index) where state.results.indices.contains(index):
            state.selectedResultIndex = index
        default: break
        }
    }

    private static func scoped(_ action: BrowserAction, technology: String) -> BrowserAction {
        switch action {
        case .searchLoaded(let id, _, let result):
            return .searchLoaded(requestID: id, technology: technology, result: result)
        case .searchFailed(let id, _, let message):
            return .searchFailed(requestID: id, technology: technology, message: message)
        default: return action
        }
    }

    static func dismiss(state: inout BrowserState) -> [BrowserEffect] {
        guard state.search?.isOpen == true else { return [] }
        return reduceBrowser(state: &state, action: .dismissSearch)
    }

    static func focusUnderlyingPane(_ focus: BrowserFocus, state: inout BrowserState) -> Bool {
        guard var search = state.search, search.isOpen else { return false }
        if search.previousFocus == .logs {
            search.previousLogFocus = focus
            state.previousLogFocus = focus
        } else {
            search.previousFocus = focus
        }
        state.technologySearches[search.technology] = search
        return true
    }

    private static func submit(state: inout SearchState) -> [BrowserEffect] {
        guard state.isOpen else { return [] }
        let effects = cancel(state: &state)
        let query = state.query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            state.error = "Enter a search query."
            return effects
        }
        state.error = nil
        state.nextRequestID += 1
        state.pendingRequestID = state.nextRequestID
        return effects + [.search(requestID: state.nextRequestID, technology: state.technology, query: query)]
    }

    private static func accepts(_ requestID: UInt64, technology: String, state: SearchState) -> Bool {
        state.isOpen && state.pendingRequestID == requestID && state.technology == technology
    }

    private static func cancel(state: inout SearchState) -> [BrowserEffect] {
        guard let requestID = state.pendingRequestID else { return [] }
        state.pendingRequestID = nil
        return [.cancelSearch(requestID: requestID)]
    }

    private static func activate(_ index: Int, state: inout BrowserState) -> [BrowserEffect] {
        guard var search = state.search, search.isOpen, search.results.indices.contains(index) else { return [] }
        let root = DocumentationDestination(technology: search.technology, path: "/documentation/" + search.technology)
        guard let target = try? DocumentationDestination.resolve(search.results[index].url, relativeTo: root),
            case .documentation(let destination) = target
        else {
            search.error = "This result has no supported documentation destination."
            state.technologySearches[search.technology] = search
            return []
        }
        search.selectedResultIndex = index
        state.technologySearches[search.technology] = search
        let effects = dismiss(state: &state)
        return effects + BrowserReducer.reduce(state: &state, action: .open(destination))
    }

    private static func restoreFocus(_ search: SearchState, state: inout BrowserState) {
        var focus = search.previousFocus
        if focus == .logs && !state.logsVisible { focus = search.previousLogFocus }
        if focus == .navigator && !state.navigatorVisible { focus = .document }
        if state.focus == .searchInput || state.focus == .searchResults { state.focus = focus }
        if state.previousLogFocus == .searchInput || state.previousLogFocus == .searchResults {
            state.previousLogFocus = focus == .logs ? search.previousLogFocus : focus
        }
    }
}
