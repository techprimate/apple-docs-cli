import SwiftTUIRuntime
import Testing

@testable import CLI

@Suite("Terminal keyboard mapping")
struct TerminalKeyMapperTests {
    @Test @MainActor
    func printableShortcutsRemainSearchText() {
        // -- Arrange --
        var state = BrowserState(entry: .types(technology: "swift"))
        _ = BrowserReducer.reduce(state: &state, action: .showSearch)
        let mapper = TerminalKeyMapper()

        // -- Act --
        let actions = ["q", "/", "`", "o", "[", "]", "r"].map {
            mapper.action(for: KeyPress(.character(Character($0))), focus: .searchInput, state: state)
        }

        // -- Assert --
        #expect(actions.allSatisfy { $0 == nil })
        #expect(mapper.action(for: .init(.return), focus: .searchInput, state: state) == .submitSearch)
        #expect(mapper.action(for: .init(.tab), focus: .searchInput, state: state) == .tab)
        #expect(mapper.action(for: .init(.escape), focus: .searchInput, state: state) == .escape)
    }

    @Test @MainActor
    func mapsGlobalShortcutsWithoutSwallowingModifiedText() {
        // -- Arrange --
        let state = BrowserState(entry: .types(technology: "swift"))
        let mapper = TerminalKeyMapper()
        let keys: [(KeyPress, BrowserAction)] = [
            (.init(.character("q")), .quit), (.init(.character("c"), modifiers: .ctrl), .quit),
            (.init(.character("b"), modifiers: .ctrl), .toggleNavigator),
            (.init(.character("/")), .showSearch), (.init(.character("`")), .toggleLogs),
            (.init(.arrowLeft, modifiers: .alt), .back), (.init(.arrowRight, modifiers: .alt), .forward),
            (.init(.escape), .escape), (.init(.tab), .tab), (.init(.character("r")), .retry),
        ]

        // -- Act --
        let actions = keys.map { mapper.action(for: $0.0, focus: .document, state: state) }
        let modified = mapper.action(for: .init(.character("q"), modifiers: .alt), focus: .document, state: state)

        // -- Assert --
        #expect(actions == keys.map { Optional($0.1) })
        #expect(modified == nil)
    }

    @Test @MainActor
    func narrowLayoutDoesNotFocusSuppressedNavigator() {
        // -- Arrange --
        var state = BrowserState(entry: .types(technology: "swift"))
        let mapper = TerminalKeyMapper(showsNavigator: false)

        // -- Act --
        let action = mapper.action(for: .init(.tab), focus: .document, state: state)
        if let action { _ = BrowserReducer.reduce(state: &state, action: action) }

        // -- Assert --
        #expect(state.focus == .document)
        #expect(state.navigatorVisible)
    }

    @Test @MainActor
    func escapeDoesNotTransferFocusToWidthSuppressedNavigator() {
        // -- Arrange --
        var state = BrowserState(entry: .types(technology: "swift"))
        let mapper = TerminalKeyMapper(showsNavigator: false)

        // -- Act --
        if let action = mapper.action(for: .init(.escape), focus: .document, state: state) {
            _ = BrowserReducer.reduce(state: &state, action: action)
        }

        // -- Assert --
        #expect(state.focus == .document)
        #expect(state.navigatorVisible)
    }

    @Test @MainActor
    func documentScrollingClampsAndKeepsSelectedLink() throws {
        // -- Arrange --
        let destination = DocumentationDestination(technology: "swift", path: "/documentation/swift/string")
        var page = DocumentationPage(destination: destination, title: "String", kind: "structure")
        page.abstract = [
            .link(label: [.text("First")], target: .documentation(destination)),
            .text(" "), .link(label: [.text("Second")], target: .documentation(destination)),
        ]
        page.content = (0..<20).map { .paragraph([.text("Row \($0)")]) }
        var state = BrowserState(entry: .type(name: "String", technology: "swift"))
        let model = DocumentationViewportModel(page: page, width: 40)
        let mapper = TerminalKeyMapper(document: model, viewportHeight: 5)
        state.viewport.selectedLinkID = model.links.last?.id

        // -- Act --
        for key: KeyEvent in [.arrowDown, .pageDown, .arrowUp, .pageUp, .arrowUp] {
            let action = try #require(mapper.action(for: .init(key), focus: .document, state: state))
            _ = BrowserReducer.reduce(state: &state, action: action)
        }
        let scrolled = state.viewport
        let previous = try #require(mapper.action(for: .init(.character("[")), focus: .document, state: state))
        _ = BrowserReducer.reduce(state: &state, action: previous)

        // -- Assert --
        #expect(scrolled.topRow == 0)
        #expect(scrolled.selectedLinkID == model.links.last?.id)
        #expect(state.viewport.selectedLinkID == model.links.first?.id)
    }

    @Test @MainActor
    func selectsAndActivatesDocumentLinksWithoutParsingLabels() throws {
        // -- Arrange --
        let destination = DocumentationDestination(technology: "swift", path: "/documentation/swift/string")
        var page = DocumentationPage(destination: destination, title: "String", kind: "structure")
        page.abstract = [.link(label: [.text("[not a shortcut]")], target: .documentation(destination))]
        var state = BrowserState(entry: .type(name: "String", technology: "Swift"))
        state.currentPage = page
        let mapper = TerminalKeyMapper(document: DocumentationViewportModel(page: page, width: 40), viewportHeight: 10)

        // -- Act --
        let selection = try #require(mapper.action(for: .init(.character("]")), focus: .document, state: state))
        _ = BrowserReducer.reduce(state: &state, action: selection)
        let activation = mapper.action(for: .init(.return), focus: .document, state: state)
        let external = mapper.action(for: .init(.character("o")), focus: .document, state: state)

        // -- Assert --
        #expect(state.viewport.selectedLinkID != nil)
        #expect(activation == .open(destination))
        #expect(external == .openExternal(destination.url))
    }

    @Test @MainActor
    func navigatorMovesSelectionAndGroupActivationOnlyExpands() throws {
        // -- Arrange --
        let destination = DocumentationDestination(technology: "swift", path: "/documentation/swift")
        var page = DocumentationPage(destination: destination, title: "Swift", kind: "module")
        page.topics = [.init(id: "group", title: "Types", references: [])]
        var state = BrowserState(entry: .types(technology: "swift"))
        state.navigatorTree = NavigatorState(page: page)
        let group = try #require(state.navigatorTree.visibleRows().first { $0.node.target == nil })
        state.navigatorTree.selectedID = group.id
        let mapper = TerminalKeyMapper()

        // -- Act --
        let enter = mapper.action(for: .init(.return), focus: .navigator, state: state)
        let right = mapper.action(for: .init(.arrowRight), focus: .navigator, state: state)
        let left = mapper.action(for: .init(.arrowLeft), focus: .navigator, state: state)
        let moveUp = try #require(mapper.action(for: .init(.arrowUp), focus: .navigator, state: state))
        _ = BrowserReducer.reduce(state: &state, action: moveUp)

        // -- Assert --
        #expect(enter == .expand(group.id))
        #expect(right == .expand(group.id))
        #expect(left == .collapse(group.id))
        #expect(state.navigatorTree.selectedID != group.id)
    }

    @Test @MainActor
    func searchSelectionMovesWithoutSubmitting() throws {
        // -- Arrange --
        var state = BrowserState(entry: .types(technology: "swift"))
        var search = SearchState(technology: "swift")
        search.isOpen = true
        search.results = [
            .init(name: "One", kind: "struct", path: "one", url: "https://developer.apple.com/documentation/swift/one"),
            .init(name: "Two", kind: "struct", path: "two", url: "https://developer.apple.com/documentation/swift/two"),
        ]
        search.selectedResultIndex = 0
        state.technologySearches["swift"] = search
        let mapper = TerminalKeyMapper()

        // -- Act --
        let action = try #require(mapper.action(for: .init(.arrowDown), focus: .searchResults, state: state))
        let effects = BrowserReducer.reduce(state: &state, action: action)
        let activation = mapper.action(for: .init(.return), focus: .searchResults, state: state)

        // -- Assert --
        #expect(effects.isEmpty)
        #expect(state.search?.selectedResultIndex == 1)
        #expect(activation == .activateSearchResult(1))
    }
}
