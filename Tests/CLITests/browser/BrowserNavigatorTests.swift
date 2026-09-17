import Testing

@testable import CLI

@Suite("Browser navigator integration")
struct BrowserNavigatorTests {
    private let member = DocumentationDestination(
        technology: "metrickit", path: "/documentation/metrickit/mxhangdiagnostic/member(_:)"
    )
    private let string = DocumentationDestination(technology: "swift", path: "/documentation/swift/string")

    @Test("page navigation exposes an out-of-tree page without waiting for a root")
    func showsRequestedPageIndependently() throws {
        // -- Arrange --
        var state = BrowserState(entry: .type(name: "member(_:)", technology: "MetricKit"))
        let page = try DocumentationPageDecoder().decode(DocumentationFixtures.member, destination: member)
        _ = BrowserReducer.reduce(state: &state, action: .open(member))

        // -- Act --
        _ = BrowserReducer.reduce(
            state: &state,
            action: .pageLoaded(
                requestID: 1, page: LoadedDocumentationPage(page: page, responseByteCount: 100)))

        // -- Assert --
        let shortcut = try #require(state.navigatorTree.currentPageShortcut)
        #expect(state.currentPage == page)
        #expect(state.navigatorTree.roots.isEmpty)
        #expect(state.navigatorTree.nodes[shortcut]?.destination == member)
        #expect(state.navigatorTree.nodes[shortcut]?.children.count == 1)
        #expect(state.navigatorTree.visibleRows().map(\.id) == [shortcut])
    }

    @Test("branch effects share the page request counter and errors never blank the document")
    func isolatesBranchFailures() throws {
        // -- Arrange --
        var state = try readingMember()
        let root = try #require(state.navigatorTree.roots.first)
        let group = try #require(state.navigatorTree.nodes[root]?.children.first)
        let type = try #require(state.navigatorTree.nodes[group]?.children.first)
        let page = state.currentPage
        let groupEffects = BrowserReducer.reduce(state: &state, action: .expand(group))
        let effects = BrowserReducer.reduce(state: &state, action: .expand(type))

        // -- Act --
        _ = BrowserReducer.reduce(
            state: &state,
            action: .childrenFailed(
                nodeID: type, requestID: 2, message: "Unavailable"))
        let retry = BrowserReducer.reduce(state: &state, action: .expand(type))
        _ = BrowserReducer.reduce(
            state: &state,
            action: .childrenFailed(
                nodeID: type, requestID: 2, message: "Stale"))

        // -- Assert --
        #expect(groupEffects.isEmpty)
        #expect(effects == [.loadChildren(nodeID: type, requestID: 2, destination: string)])
        #expect(retry == [.loadChildren(nodeID: type, requestID: 3, destination: string)])
        #expect(state.currentPage == page)
        #expect(state.pageError == nil)
        #expect(state.navigatorTree.nodes[type]?.error == nil)
        #expect(state.navigatorTree.nodes[type]?.isLoading == true)
    }

    @Test("background completions stay in their technology and history restores a populated tree")
    func restoresTreeAcrossTechnologies() throws {
        // -- Arrange --
        var state = try readingMember()
        let originalPage = try #require(state.currentPage)
        let root = try #require(state.navigatorTree.roots.first)
        let group = try #require(state.navigatorTree.nodes[root]?.children.first)
        let type = try #require(state.navigatorTree.nodes[group]?.children.first)
        _ = BrowserReducer.reduce(state: &state, action: .expand(group))
        _ = BrowserReducer.reduce(state: &state, action: .expand(type))
        _ = BrowserReducer.reduce(state: &state, action: .collapse(type))
        state.navigatorTree.selectedID = type
        state.navigatorTree.topRow = 5
        state.focus = .navigator
        _ = BrowserReducer.reduce(state: &state, action: .open(string))
        let otherPage = DocumentationPage(destination: string, title: "String", kind: "struct")
        _ = BrowserReducer.reduce(
            state: &state,
            action: .pageLoaded(
                requestID: 3, page: LoadedDocumentationPage(page: otherPage, responseByteCount: 80)))
        let otherTree = state.navigatorTree

        // -- Act --
        _ = BrowserReducer.reduce(state: &state, action: .childrenLoaded(nodeID: type, requestID: 2, page: otherPage))
        #expect(state.navigatorTree == otherTree)
        _ = BrowserReducer.reduce(state: &state, action: .back)
        _ = BrowserReducer.reduce(
            state: &state,
            action: .pageLoaded(
                requestID: 4, page: LoadedDocumentationPage(page: originalPage, responseByteCount: 100)))

        // -- Assert --
        #expect(state.technology == "metrickit")
        #expect(state.focus == .navigator)
        #expect(state.navigatorTree.selectedID == type)
        #expect(state.navigatorTree.topRow == 5)
        #expect(state.navigatorTree.nodes[group]?.isExpanded == true)
        #expect(state.navigatorTree.nodes[type]?.isExpanded == false)
        #expect(state.navigatorTree.nodes[type]?.loadState == .loaded)
        #expect(state.navigatorTree.visibleRows().map(\.id) == [root, group, type])
        #expect(BrowserReducer.reduce(state: &state, action: .expand(type)).isEmpty)
    }

    private func readingMember() throws -> BrowserState {
        let page = try DocumentationPageDecoder().decode(DocumentationFixtures.member, destination: member)
        var state = BrowserState(entry: .type(name: "member(_:)", technology: "MetricKit"))
        state.navigatorTree = NavigatorState(page: page)
        _ = BrowserReducer.reduce(state: &state, action: .open(member))
        _ = BrowserReducer.reduce(
            state: &state,
            action: .pageLoaded(
                requestID: 1, page: LoadedDocumentationPage(page: page, responseByteCount: 100)))
        return state
    }
}
