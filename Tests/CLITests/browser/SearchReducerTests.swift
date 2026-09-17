import Testing

@testable import CLI

@Suite("Submitted technology search")
struct SearchReducerTests {
    private let result = DocumentationType(
        name: "String", kind: "struct", path: "string",
        url: "https://developer.apple.com/documentation/swift/string")

    @Test("dismissed search cancels work and rejects late results")
    func rejectsDismissedResults() {
        // -- Arrange --
        var state = SearchState(technology: "swift")
        state.isOpen = true
        state.pendingRequestID = 7

        // -- Act --
        let effects = SearchReducer.reduce(state: &state, action: .dismissSearch)
        _ = SearchReducer.reduce(
            state: &state,
            action: .searchLoaded(
                requestID: 7, technology: "swift",
                result: DocumentationSearchResult(types: [result], unavailableCollectionPaths: [])))

        // -- Assert --
        #expect(effects == [.cancelSearch(requestID: 7)])
        #expect(!state.isOpen)
        #expect(state.pendingRequestID == nil)
        #expect(state.results.isEmpty)
        #expect(!state.hasSearched)
    }

    @Test("editing does not fetch, submitting replaces pending work, and stale responses are ignored")
    func submitsOnlyExplicitly() {
        // -- Arrange --
        var state = SearchState(technology: "swift")
        _ = SearchReducer.reduce(state: &state, action: .showSearch)

        // -- Act --
        let edit = SearchReducer.reduce(state: &state, action: .editQuery("String"))
        let first = SearchReducer.reduce(state: &state, action: .submitSearch)
        _ = SearchReducer.reduce(state: &state, action: .editQuery("Array"))
        let second = SearchReducer.reduce(state: &state, action: .submitSearch)
        _ = SearchReducer.reduce(
            state: &state, action: .searchFailed(requestID: 1, technology: "swift", message: "Stale"))
        _ = SearchReducer.reduce(
            state: &state,
            action: .searchLoaded(
                requestID: 1, technology: "swift",
                result: DocumentationSearchResult(types: [result], unavailableCollectionPaths: [])))

        // -- Assert --
        #expect(edit.isEmpty)
        #expect(first == [.search(requestID: 1, technology: "swift", query: "String")])
        #expect(second == [.cancelSearch(requestID: 1), .search(requestID: 2, technology: "swift", query: "Array")])
        #expect(state.pendingRequestID == 2)
        #expect(state.results.isEmpty)
        #expect(state.error == nil)
    }

    @Test("partial results and selection survive closing and reopening")
    func retainsSearchResults() {
        // -- Arrange --
        var state = SearchState(technology: "swift")
        _ = SearchReducer.reduce(state: &state, action: .showSearch)
        _ = SearchReducer.reduce(state: &state, action: .editQuery("String"))
        _ = SearchReducer.reduce(state: &state, action: .submitSearch)
        _ = SearchReducer.reduce(
            state: &state,
            action: .searchLoaded(
                requestID: 1, technology: "swift",
                result: DocumentationSearchResult(
                    types: [result], unavailableCollectionPaths: ["/documentation/swift/collections"])))

        // -- Act --
        _ = SearchReducer.reduce(state: &state, action: .dismissSearch)
        let effects = SearchReducer.reduce(state: &state, action: .showSearch)

        // -- Assert --
        #expect(effects.isEmpty)
        #expect(state.isOpen)
        #expect(state.query == "String")
        #expect(state.results == [result])
        #expect(state.selectedResultIndex == 0)
        #expect(state.unavailableCollectionPaths == ["/documentation/swift/collections"])
        #expect(state.hasSearched)
        #expect(state.error == nil)
    }

    @Test("empty results are successful, while wrong-technology completions cannot mutate the search")
    func acceptsEmptyResults() {
        // -- Arrange --
        var state = SearchState(technology: "swift")
        _ = SearchReducer.reduce(state: &state, action: .showSearch)
        _ = SearchReducer.reduce(state: &state, action: .editQuery("Missing"))
        _ = SearchReducer.reduce(state: &state, action: .submitSearch)

        // -- Act --
        _ = SearchReducer.reduce(
            state: &state,
            action: .searchLoaded(
                requestID: 1, technology: "metrickit",
                result: DocumentationSearchResult(types: [result], unavailableCollectionPaths: [])))
        #expect(state.pendingRequestID == 1)
        _ = SearchReducer.reduce(
            state: &state,
            action: .searchLoaded(
                requestID: 1, technology: "swift",
                result: DocumentationSearchResult(types: [], unavailableCollectionPaths: [])))

        // -- Assert --
        #expect(state.results.isEmpty)
        #expect(state.selectedResultIndex == nil)
        #expect(state.pendingRequestID == nil)
        #expect(state.error == nil)
        #expect(state.hasSearched)
    }

    @Test("search failure preserves the query and retry receives a new request identity")
    func retriesFailure() {
        // -- Arrange --
        var state = SearchState(technology: "swift")
        _ = SearchReducer.reduce(state: &state, action: .showSearch)
        _ = SearchReducer.reduce(state: &state, action: .editQuery("String"))
        _ = SearchReducer.reduce(state: &state, action: .submitSearch)

        // -- Act --
        _ = SearchReducer.reduce(
            state: &state,
            action: .searchFailed(
                requestID: 1, technology: "swift", message: "Unavailable"))
        #expect(state.error == "Unavailable")
        #expect(state.pendingRequestID == nil)
        let retry = SearchReducer.reduce(state: &state, action: .submitSearch)

        // -- Assert --
        #expect(state.query == "String")
        #expect(state.error == nil)
        #expect(retry == [.search(requestID: 2, technology: "swift", query: "String")])
        #expect(state.isOpen)
    }

    @Test("blank input reports a local error without fetching")
    func rejectsBlankInput() {
        // -- Arrange --
        var state = SearchState(technology: "swift")
        _ = SearchReducer.reduce(state: &state, action: .showSearch)
        _ = SearchReducer.reduce(state: &state, action: .editQuery("  \n"))

        // -- Act --
        let effects = SearchReducer.reduce(state: &state, action: .submitSearch)

        // -- Assert --
        #expect(effects.isEmpty)
        #expect(state.error == "Enter a search query.")
        #expect(state.pendingRequestID == nil)
    }
}
