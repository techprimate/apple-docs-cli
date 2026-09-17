import SwiftTUIRuntime
import Testing

@testable import CLI

@Suite("Terminal browser frames")
struct BrowserViewTests {
    @Test @MainActor
    func resizingTemporarilySuppressesNavigatorWithoutChangingDocument() {
        // -- Arrange --
        let state = loadedState()

        // -- Act --
        let wide = frame(state, width: 110, height: 35)
        let normal = frame(state, width: 80, height: 24)
        let narrow = frame(state, width: 50, height: 15)
        let restored = frame(state, width: 110, height: 35)

        // -- Assert --
        #expect(wide.contains("Navigator"))
        #expect(normal.contains("Navigator"))
        #expect(!narrow.contains("Navigator"))
        #expect(restored.contains("Navigator"))
        for text in [wide, normal, narrow, restored] {
            #expect(text.contains("Documentation"))
            #expect(text.contains("Example body"))
        }
        #expect(state.navigatorVisible)
    }

    @Test @MainActor
    func hiddenNavigatorAndLogsDoNotLeakIntoDocument() {
        // -- Arrange --
        var state = loadedState()
        state.navigatorVisible = false
        let logs = [SessionLogEntry(id: 1, level: .warning, label: "test", message: "Only inside logs")]

        // -- Act --
        let hidden = frame(state, logs: logs, width: 80, height: 24)
        _ = BrowserReducer.reduce(state: &state, action: .toggleLogs)
        let shown = frame(state, logs: logs, width: 80, height: 24)

        // -- Assert --
        #expect(!hidden.contains("Navigator"))
        #expect(!hidden.contains("Only inside logs"))
        #expect(shown.contains("Only inside logs"))
        #expect(shown.contains("Example body"))
        #expect(state.focus == .logs)
    }

    @Test @MainActor
    func searchShowsPartialCoverageAndRetainedResults() {
        // -- Arrange --
        var state = loadedState()
        var search = SearchState(technology: "swift")
        search.isOpen = true
        search.hasSearched = true
        search.query = "String"
        search.unavailableCollectionPaths = ["/documentation/swift/missing"]
        search.results = [
            .init(
                name: "String", kind: "struct", path: "string",
                url: "https://developer.apple.com/documentation/swift/string")
        ]
        state.technologySearches["swift"] = search
        state.focus = .searchInput

        // -- Act --
        let text = frame(state, width: 80, height: 24)

        // -- Assert --
        #expect(text.contains("Search"))
        #expect(text.contains("Incomplete"))
        #expect(text.contains("String"))
        #expect(text.contains("string"))
    }

    @Test @MainActor
    func pageFailureKeepsDocumentAndOffersRetry() {
        // -- Arrange --
        var state = loadedState()
        state.pageError = "Request failed"

        // -- Act --
        let text = frame(state, width: 80, height: 24)

        // -- Assert --
        #expect(text.contains("Example body"))
        #expect(text.contains("Request failed"))
        #expect(text.contains("retry"))
    }

    @Test @MainActor
    func catalogsExposeSelectableDocumentationDestinations() {
        // -- Arrange --
        var technologies = BrowserState(entry: .technologies)
        technologies.catalog.technologies = [
            .init(name: "Swift", identifier: "doc://com.apple.documentation/documentation/swift")
        ]
        var types = BrowserState(entry: .types(technology: "swift"))
        types.catalog.types["swift"] = [
            .init(
                name: "String", kind: "struct", path: "string",
                url: "https://developer.apple.com/documentation/swift/string")
        ]

        // -- Act --
        let catalog = DocumentationViewportModel(content: DocumentationViewContent(state: technologies), width: 40)
        let symbols = DocumentationViewportModel(content: DocumentationViewContent(state: types), width: 40)

        // -- Assert --
        #expect(catalog.links.first?.target == .documentation(.init(technology: "swift", path: "/documentation/swift")))
        #expect(
            symbols.links.first?.target
                == .documentation(.init(technology: "swift", path: "/documentation/swift/string")))
        #expect(frame(technologies, width: 80, height: 24).contains("Swift"))
        #expect(frame(types, width: 80, height: 24).contains("String"))
    }

    private func loadedState() -> BrowserState {
        let destination = DocumentationDestination(technology: "swift", path: "/documentation/swift/example")
        var page = DocumentationPage(destination: destination, title: "Example", kind: "structure")
        page.abstract = [.text("Example body")]
        var state = BrowserState(entry: .type(name: "Example", technology: "Swift"))
        state.currentLocation = .page(destination)
        state.currentPage = page
        state.navigatorTree = NavigatorState(page: page)
        return state
    }

    @MainActor private func frame(
        _ state: BrowserState, logs: [SessionLogEntry] = [], width: Int, height: Int
    ) -> String {
        DefaultRenderer().render(
            BrowserView(state: state, logs: logs, send: { _ in }),
            proposal: .init(width: width, height: height)
        ).rasterSurface.lines.joined(separator: "\n")
    }
}
