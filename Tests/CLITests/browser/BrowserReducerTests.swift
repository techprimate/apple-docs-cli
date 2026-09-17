import Testing

@testable import CLI

@Suite("Browser navigation and focus")
struct BrowserReducerTests {
    private let first = DocumentationDestination(technology: "swift", path: "/documentation/swift/string")
    private let second = DocumentationDestination(
        technology: "metrickit", path: "/documentation/metrickit/mxhangdiagnostic")

    @Test("opens pages through effects and rejects superseded completions")
    func rejectsStaleCompletions() {
        // -- Arrange --
        var state = BrowserState(entry: .type(name: "String", technology: "Swift"))
        let initial = BrowserReducer.reduce(state: &state, action: .open(first))

        // -- Act --
        let replacement = BrowserReducer.reduce(state: &state, action: .open(second))
        _ = BrowserReducer.reduce(state: &state, action: .pageLoaded(requestID: 1, page: loaded(first)))

        // -- Assert --
        #expect(initial == [.loadPage(requestID: 1, destination: first)])
        #expect(replacement == [.cancelPage(requestID: 1), .loadPage(requestID: 2, destination: second)])
        #expect(state.currentPage == nil)
        #expect(state.pendingPageRequestID == 2)
        #expect(state.history.current == nil)
    }

    @Test("successful cross-technology navigation commits history and changes technology")
    func opensCrossTechnologyPage() {
        // -- Arrange --
        var state = readingFirstPage()
        let node = NavigatorNodeID(components: ["swift", "string"])
        state.navigator = NavigatorSnapshot(expandedIDs: [node], selectedID: node, topRow: 4)
        _ = BrowserReducer.reduce(state: &state, action: .open(second))

        // -- Act --
        _ = BrowserReducer.reduce(state: &state, action: .pageLoaded(requestID: 2, page: loaded(second)))

        // -- Assert --
        #expect(state.currentPage?.destination == second)
        #expect(state.technology == "metrickit")
        #expect(state.history.current?.location == .page(second))
        #expect(state.navigator == NavigatorSnapshot())
        #expect(state.pendingPageRequestID == nil)
    }

    @Test("Back and Forward restore scroll, selected link, navigator state, and main-pane focus")
    func restoresHistoryState() {
        // -- Arrange --
        var state = readingFirstPage()
        let node = NavigatorNodeID(components: ["swift", "string"])
        state.viewport = BrowserViewport(topRow: 42, selectedLinkID: "link-7")
        state.navigator = NavigatorSnapshot(expandedIDs: [node], selectedID: node, topRow: 9)
        state.focus = .navigator
        _ = BrowserReducer.reduce(state: &state, action: .open(second))
        _ = BrowserReducer.reduce(state: &state, action: .pageLoaded(requestID: 2, page: loaded(second)))
        state.viewport = BrowserViewport(topRow: 10, selectedLinkID: "member")

        // -- Act --
        let effects = BrowserReducer.reduce(state: &state, action: .back)
        _ = BrowserReducer.reduce(state: &state, action: .pageLoaded(requestID: 3, page: loaded(first)))

        // -- Assert --
        #expect(effects == [.loadPage(requestID: 3, destination: first)])
        #expect(state.viewport == BrowserViewport(topRow: 42, selectedLinkID: "link-7"))
        #expect(state.navigator == NavigatorSnapshot(expandedIDs: [node], selectedID: node, topRow: 9))
        #expect(state.focus == .navigator)
        #expect(
            BrowserReducer.reduce(state: &state, action: .forward) == [.loadPage(requestID: 4, destination: second)])
        _ = BrowserReducer.reduce(state: &state, action: .pageLoaded(requestID: 4, page: loaded(second)))
        #expect(state.viewport == BrowserViewport(topRow: 10, selectedLinkID: "member"))
    }

    @Test("failed navigation leaves the current page and forward history intact")
    func preservesPageAfterFailure() {
        // -- Arrange --
        var state = readingFirstPage()
        _ = BrowserReducer.reduce(state: &state, action: .open(second))
        _ = BrowserReducer.reduce(state: &state, action: .pageLoaded(requestID: 2, page: loaded(second)))
        _ = BrowserReducer.reduce(state: &state, action: .back)
        _ = BrowserReducer.reduce(state: &state, action: .pageLoaded(requestID: 3, page: loaded(first)))
        _ = BrowserReducer.reduce(state: &state, action: .open(second))

        // -- Act --
        _ = BrowserReducer.reduce(state: &state, action: .pageFailed(requestID: 4, message: "Unavailable"))

        // -- Assert --
        #expect(state.currentPage?.destination == first)
        #expect(state.pageError == "Unavailable")
        #expect(state.history.current?.location == .page(first))
        #expect(
            BrowserReducer.reduce(state: &state, action: .forward) == [.loadPage(requestID: 5, destination: second)])
    }

    @Test("initial failure offers retry with a new operation identity")
    func retriesInitialFailure() {
        // -- Arrange --
        var state = BrowserState(entry: .type(name: "String", technology: "Swift"))
        _ = BrowserReducer.reduce(state: &state, action: .open(first))
        _ = BrowserReducer.reduce(state: &state, action: .pageFailed(requestID: 1, message: "Unavailable"))

        // -- Act --
        let effects = BrowserReducer.reduce(state: &state, action: .retry)

        // -- Assert --
        #expect(effects == [.loadPage(requestID: 2, destination: first)])
        #expect(state.pageError == nil)
        #expect(state.currentPage == nil)
        _ = BrowserReducer.reduce(state: &state, action: .pageFailed(requestID: 1, message: "Stale"))
        #expect(state.pageError == nil)
    }

    @Test("hiding the navigator preserves its snapshot and transfers focus")
    func hidesNavigator() {
        // -- Arrange --
        var state = readingFirstPage()
        state.focus = .navigator
        let node = NavigatorNodeID(components: ["swift"])
        state.navigator = NavigatorSnapshot(expandedIDs: [node], selectedID: node, topRow: 4)

        // -- Act --
        _ = BrowserReducer.reduce(state: &state, action: .toggleNavigator)
        _ = BrowserReducer.reduce(state: &state, action: .tab)

        // -- Assert --
        #expect(!state.navigatorVisible)
        #expect(state.focus == .document)
        #expect(state.navigator.selectedID == node)
        #expect(state.navigator.topRow == 4)
        _ = BrowserReducer.reduce(state: &state, action: .toggleNavigator)
        _ = BrowserReducer.reduce(state: &state, action: .tab)
        #expect(state.focus == .navigator)
    }

    @Test("Escape closes focused logs before cancelling a page request, then restores navigator focus")
    func appliesEscapePriority() {
        // -- Arrange --
        var state = readingFirstPage()
        _ = BrowserReducer.reduce(state: &state, action: .open(second))
        _ = BrowserReducer.reduce(state: &state, action: .toggleLogs)

        // -- Act --
        let closeLogs = BrowserReducer.reduce(state: &state, action: .escape)
        let cancelPage = BrowserReducer.reduce(state: &state, action: .escape)
        _ = BrowserReducer.reduce(state: &state, action: .pageLoaded(requestID: 2, page: loaded(second)))
        let focusNavigator = BrowserReducer.reduce(state: &state, action: .escape)

        // -- Assert --
        #expect(closeLogs.isEmpty)
        #expect(cancelPage == [.cancelPage(requestID: 2)])
        #expect(focusNavigator.isEmpty)
        #expect(!state.logsVisible)
        #expect(state.focus == .navigator)
        #expect(state.currentPage?.destination == first)
        #expect(state.pageError == nil)
    }

    @Test("page completion does not steal focus from the log panel")
    func preservesLogFocusDuringNavigation() {
        // -- Arrange --
        var state = readingFirstPage()
        _ = BrowserReducer.reduce(state: &state, action: .open(second))
        _ = BrowserReducer.reduce(state: &state, action: .toggleLogs)

        // -- Act --
        _ = BrowserReducer.reduce(state: &state, action: .pageLoaded(requestID: 2, page: loaded(second)))

        // -- Assert --
        #expect(state.focus == .logs)
        #expect(state.logsVisible)
        #expect(state.currentPage?.destination == second)
        _ = BrowserReducer.reduce(state: &state, action: .toggleLogs)
        #expect(state.focus == .document)
    }

    @Test("returning to a catalog clears an unrelated navigation error")
    func restoresCatalog() {
        // -- Arrange --
        var state = BrowserState(entry: .technologies)
        state.currentLocation = .technologies
        state.history.visit(BrowserHistoryEntry(location: .technologies))
        _ = BrowserReducer.reduce(state: &state, action: .open(first))
        _ = BrowserReducer.reduce(state: &state, action: .pageLoaded(requestID: 1, page: loaded(first)))
        _ = BrowserReducer.reduce(state: &state, action: .open(second))
        _ = BrowserReducer.reduce(state: &state, action: .pageFailed(requestID: 2, message: "Unavailable"))

        // -- Act --
        let effects = BrowserReducer.reduce(state: &state, action: .back)

        // -- Assert --
        #expect(effects.isEmpty)
        #expect(state.currentLocation == .technologies)
        #expect(state.currentPage == nil)
        #expect(state.technology == nil)
        #expect(state.pageError == nil)
        #expect(state.failedNavigation == nil)
    }

    @Test("quitting cancels pending page work and rejects its late completion")
    func cancelsOnQuit() {
        // -- Arrange --
        var state = readingFirstPage()
        _ = BrowserReducer.reduce(state: &state, action: .open(second))

        // -- Act --
        let effects = BrowserReducer.reduce(state: &state, action: .quit)
        _ = BrowserReducer.reduce(state: &state, action: .pageLoaded(requestID: 2, page: loaded(second)))

        // -- Assert --
        #expect(effects == [.cancelPage(requestID: 2), .quit])
        #expect(state.currentPage?.destination == first)
    }

    private func readingFirstPage() -> BrowserState {
        var state = BrowserState(entry: .type(name: "String", technology: "Swift"))
        _ = BrowserReducer.reduce(state: &state, action: .open(first))
        _ = BrowserReducer.reduce(state: &state, action: .pageLoaded(requestID: 1, page: loaded(first)))
        return state
    }

    private func loaded(_ destination: DocumentationDestination) -> LoadedDocumentationPage {
        LoadedDocumentationPage(
            page: DocumentationPage(destination: destination, title: "Page", kind: "class"),
            responseByteCount: 100)
    }
}
