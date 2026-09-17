import Testing

@testable import CLI

@Suite("Browser search integration")
struct BrowserSearchTests {
    private let string = DocumentationDestination(technology: "swift", path: "/documentation/swift/string")
    private let result = DocumentationType(
        name: "String", kind: "struct", path: "string",
        url: "https://developer.apple.com/documentation/swift/string")

    @Test("global catalogs have no search technology")
    func rejectsGlobalSearch() {
        // -- Arrange --
        var state = BrowserState(entry: .technologies)
        state.currentLocation = .technologies

        // -- Act --
        let effects = BrowserReducer.reduce(state: &state, action: .showSearch)

        // -- Assert --
        #expect(effects.isEmpty)
        #expect(state.search == nil)
        #expect(state.focus == .document)
    }

    @Test("search Tab and Escape stay local and restore the preceding pane")
    func managesSearchFocus() {
        // -- Arrange --
        var state = BrowserState(entry: .types(technology: "Swift"))
        state.focus = .navigator
        _ = BrowserReducer.reduce(state: &state, action: .showSearch)
        #expect(state.focus == .searchInput)
        _ = BrowserReducer.reduce(state: &state, action: .editQuery("String"))
        let searchEffects = BrowserReducer.reduce(state: &state, action: .submitSearch)

        // -- Act --
        _ = BrowserReducer.reduce(state: &state, action: .tab)
        #expect(state.focus == .searchResults)
        let dismissEffects = BrowserReducer.reduce(state: &state, action: .escape)
        _ = BrowserReducer.reduce(
            state: &state,
            action: .searchLoaded(
                requestID: 1, technology: "swift",
                result: DocumentationSearchResult(types: [result], unavailableCollectionPaths: [])))

        // -- Assert --
        #expect(searchEffects == [.search(requestID: 1, technology: "swift", query: "String")])
        #expect(dismissEffects == [.cancelSearch(requestID: 1)])
        #expect(state.focus == .navigator)
        #expect(state.search?.isOpen == false)
        #expect(state.search?.results.isEmpty == true)
        #expect(state.search?.query == "String")
    }

    @Test("activating a result navigates normally and reopening retains results without another fetch")
    func opensSearchResult() {
        // -- Arrange --
        var state = completedSearch()

        // -- Act --
        let effects = BrowserReducer.reduce(state: &state, action: .activateSearchResult(0))
        _ = BrowserReducer.reduce(
            state: &state,
            action: .pageLoaded(
                requestID: 2,
                page: LoadedDocumentationPage(
                    page: DocumentationPage(destination: string, title: "String", kind: "struct"),
                    responseByteCount: 100)))
        let reopen = BrowserReducer.reduce(state: &state, action: .showSearch)

        // -- Assert --
        #expect(effects == [.loadPage(requestID: 2, destination: string)])
        #expect(reopen.isEmpty)
        #expect(state.history.current?.location == .page(string))
        #expect(state.search?.results == [result])
        #expect(state.search?.selectedResultIndex == 0)
        #expect(state.search?.query == "String")
        #expect(state.focus == .searchInput)
    }

    @Test("cross-technology navigation cancels search and retains separate query state")
    func scopesRetainedSearch() {
        // -- Arrange --
        var state = completedSearch()
        _ = BrowserReducer.reduce(state: &state, action: .submitSearch)
        let other = DocumentationDestination(technology: "metrickit", path: "/documentation/metrickit")

        // -- Act --
        let effects = BrowserReducer.reduce(state: &state, action: .open(other))
        _ = BrowserReducer.reduce(
            state: &state,
            action: .pageLoaded(
                requestID: 3,
                page: LoadedDocumentationPage(
                    page: DocumentationPage(destination: other, title: "MetricKit", kind: "collection"),
                    responseByteCount: 100)))
        _ = BrowserReducer.reduce(state: &state, action: .showSearch)
        _ = BrowserReducer.reduce(
            state: &state, action: .searchFailed(requestID: 2, technology: "swift", message: "Late"))

        // -- Assert --
        #expect(effects == [.cancelSearch(requestID: 2), .loadPage(requestID: 3, destination: other)])
        #expect(state.search?.technology == "metrickit")
        #expect(state.search?.query == "")
        #expect(state.technologySearches["swift"]?.query == "String")
        #expect(state.technologySearches["swift"]?.results == [result])
        #expect(state.technologySearches["swift"]?.isOpen == false)
        #expect(state.technologySearches["swift"]?.error == nil)
    }

    @Test("Escape dismisses search before logs, then restores the original pane")
    func appliesOverlayPriority() {
        // -- Arrange --
        var state = BrowserState(entry: .types(technology: "Swift"))
        state.focus = .navigator
        _ = BrowserReducer.reduce(state: &state, action: .showSearch)
        _ = BrowserReducer.reduce(state: &state, action: .toggleLogs)

        // -- Act --
        _ = BrowserReducer.reduce(state: &state, action: .escape)
        #expect(state.focus == .logs)
        #expect(state.logsVisible)
        #expect(state.search?.isOpen == false)
        _ = BrowserReducer.reduce(state: &state, action: .escape)

        // -- Assert --
        #expect(!state.logsVisible)
        #expect(state.focus == .navigator)
    }

    @Test("page completion preserves search focus and records only underlying browser focus in history")
    func preservesSearchDuringPageCompletion() {
        // -- Arrange --
        var state = BrowserState(entry: .types(technology: "Swift"))
        _ = BrowserReducer.reduce(state: &state, action: .open(string))
        _ = BrowserReducer.reduce(state: &state, action: .showSearch)

        // -- Act --
        _ = BrowserReducer.reduce(
            state: &state,
            action: .pageLoaded(
                requestID: 1,
                page: LoadedDocumentationPage(
                    page: DocumentationPage(destination: string, title: "String", kind: "struct"),
                    responseByteCount: 100)))

        // -- Assert --
        #expect(state.focus == .searchInput)
        #expect(state.search?.isOpen == true)
        #expect(state.history.current?.focus == .document)
    }

    @Test("a cross-technology page completion dismisses and cancels a search opened during navigation")
    func dismissesSearchOnTechnologyCompletion() {
        // -- Arrange --
        var state = BrowserState(entry: .types(technology: "MetricKit"))
        _ = BrowserReducer.reduce(state: &state, action: .open(string))
        _ = BrowserReducer.reduce(state: &state, action: .showSearch)
        _ = BrowserReducer.reduce(state: &state, action: .editQuery("Diagnostic"))
        _ = BrowserReducer.reduce(state: &state, action: .submitSearch)

        // -- Act --
        let effects = BrowserReducer.reduce(
            state: &state,
            action: .pageLoaded(
                requestID: 1,
                page: LoadedDocumentationPage(
                    page: DocumentationPage(destination: string, title: "String", kind: "struct"),
                    responseByteCount: 100)))

        // -- Assert --
        #expect(effects == [.cancelSearch(requestID: 2)])
        #expect(state.technologySearches["metrickit"]?.pendingRequestID == nil)
        #expect(state.technologySearches["metrickit"]?.isOpen == false)
        #expect(state.technologySearches["metrickit"]?.query == "Diagnostic")
        #expect(state.focus == .document)
    }

    @Test("unsafe search result destinations remain local errors instead of navigation")
    func rejectsUnsafeResult() {
        // -- Arrange --
        var state = completedSearch()
        state.technologySearches["swift"]?.results = [
            DocumentationType(name: "Unsafe", kind: "symbol", path: "unsafe", url: "javascript:alert(1)")
        ]

        // -- Act --
        let effects = BrowserReducer.reduce(state: &state, action: .activateSearchResult(0))

        // -- Assert --
        #expect(effects.isEmpty)
        #expect(state.search?.error == "This result has no supported documentation destination.")
        #expect(state.search?.isOpen == true)
        #expect(state.pendingNavigation == nil)
    }

    private func completedSearch() -> BrowserState {
        var state = BrowserState(entry: .types(technology: "Swift"))
        _ = BrowserReducer.reduce(state: &state, action: .showSearch)
        _ = BrowserReducer.reduce(state: &state, action: .editQuery("String"))
        _ = BrowserReducer.reduce(state: &state, action: .submitSearch)
        _ = BrowserReducer.reduce(
            state: &state,
            action: .searchLoaded(
                requestID: 1, technology: "swift",
                result: DocumentationSearchResult(types: [result], unavailableCollectionPaths: [])))
        return state
    }
}
