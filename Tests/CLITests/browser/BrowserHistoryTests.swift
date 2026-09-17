import Testing

@testable import CLI

@Suite("Browser history")
struct BrowserHistoryTests {
    @Test("visiting after Back replaces the forward branch")
    func replacesForwardHistory() {
        // -- Arrange --
        var history = BrowserHistory()
        history.visit(BrowserHistoryEntry(location: .types(technology: "MetricKit")))
        history.visit(BrowserHistoryEntry(location: .types(technology: "Foundation")))
        _ = history.back()

        // -- Act --
        history.visit(BrowserHistoryEntry(location: .types(technology: "Swift")))

        // -- Assert --
        #expect(history.current?.location == .types(technology: "Swift"))
        #expect(history.forward() == nil)
        #expect(history.back()?.location == .types(technology: "MetricKit"))
        #expect(history.back() == nil)
    }

    @Test("captures independent document, navigator, and focus state")
    func restoresSnapshot() {
        // -- Arrange --
        let node = NavigatorNodeID(components: ["swift", "types", "string"])
        let snapshot = BrowserHistoryEntry(
            location: .types(technology: "Swift"),
            viewport: BrowserViewport(topRow: 42, selectedLinkID: "link-7"),
            navigator: NavigatorSnapshot(expandedIDs: [node], selectedID: node, topRow: 9), focus: .navigator
        )
        var history = BrowserHistory()
        history.visit(BrowserHistoryEntry(location: .types(technology: "Swift")))
        history.updateCurrent(snapshot)
        history.visit(BrowserHistoryEntry(location: .technologies))

        // -- Act --
        let previous = history.back()
        let next = history.forward()

        // -- Assert --
        #expect(previous == snapshot)
        #expect(next?.location == .technologies)
        #expect(history.forward() == nil)
    }
}
