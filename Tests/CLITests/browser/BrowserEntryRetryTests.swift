import Testing

@testable import CLI

@Suite("Browser entry retries")
struct BrowserEntryRetryTests {
    @Test("root failure stays local and retry preserves the visible document")
    func retriesRoot() {
        // -- Arrange --
        var state = BrowserState(entry: .type(name: "String", technology: "Swift"))
        _ = BrowserReducer.reduce(state: &state, action: .start)
        let page = DocumentationPage(
            destination: DocumentationDestination(technology: "swift", path: "/documentation/swift/string"),
            title: "String", kind: "struct")
        _ = BrowserReducer.reduce(
            state: &state,
            action: .pageLoaded(
                requestID: 1,
                page: LoadedDocumentationPage(page: page, responseByteCount: 100)))
        _ = BrowserReducer.reduce(
            state: &state, action: .rootFailed(requestID: 2, technology: "Swift", message: "Unavailable"))
        #expect(state.catalog.rootErrors["swift"] == "Unavailable")

        // -- Act --
        let effects = BrowserReducer.reduce(state: &state, action: .retryRoot(technology: "swift"))
        _ = BrowserReducer.reduce(
            state: &state, action: .rootFailed(requestID: 2, technology: "Swift", message: "Stale"))

        // -- Assert --
        #expect(effects == [.loadRoot(requestID: 3, technology: "swift")])
        #expect(state.currentPage == page)
        #expect(state.pageError == nil)
        #expect(state.catalog.rootErrors["swift"] == nil)
        #expect(state.catalog.pendingRoots["swift"] == 3)
    }

    @Test("catalog retry keeps its location and clears only its own error", arguments: [false, true])
    func retriesCatalog(global: Bool) {
        // -- Arrange --
        var state = BrowserState(entry: global ? .technologies : .types(technology: "Swift"))
        _ = BrowserReducer.reduce(state: &state, action: .start)
        _ = BrowserReducer.reduce(
            state: &state,
            action: global
                ? .technologiesFailed(requestID: 1, message: "Unavailable")
                : .typesFailed(requestID: 1, technology: "Swift", message: "Unavailable"))
        let history = state.history

        // -- Act --
        let effects = BrowserReducer.reduce(state: &state, action: .retry)

        // -- Assert --
        #expect(
            effects == (global ? [.loadTechnologies(requestID: 2)] : [.loadTypes(requestID: 3, technology: "swift")]))
        #expect(state.catalog.technologiesError == nil)
        #expect(state.catalog.typeErrors["swift"] == nil)
        #expect(state.history == history)
        #expect(state.currentLocation == (global ? .technologies : .types(technology: "swift")))
    }
}
