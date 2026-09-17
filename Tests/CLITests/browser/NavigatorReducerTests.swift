import Testing

@testable import CLI

@Suite("Lazy documentation navigator")
struct NavigatorReducerTests {
    private let destination = DocumentationDestination(
        technology: "metrickit", path: "/documentation/metrickit/mxhangdiagnostic/member(_:)"
    )
    private let stringDestination = DocumentationDestination(technology: "swift", path: "/documentation/swift/string")

    @Test("topic groups expand locally and unloaded documents produce one request")
    func expandsLazily() throws {
        // -- Arrange --
        let page = try DocumentationPageDecoder().decode(DocumentationFixtures.member, destination: destination)
        var navigator = NavigatorState(page: page)
        let root = try #require(navigator.roots.first)
        let group = try #require(navigator.nodes[root]?.children.first)
        let type = try #require(navigator.nodes[group]?.children.first)

        // -- Act --
        let groupEffects = NavigatorReducer.expand(nodeID: group, state: &navigator)
        let typeEffects = NavigatorReducer.expand(nodeID: type, state: &navigator)
        let repeatEffects = NavigatorReducer.expand(nodeID: type, state: &navigator)

        // -- Assert --
        #expect(groupEffects.isEmpty)
        #expect(typeEffects == [.loadChildren(nodeID: type, requestID: 1, destination: stringDestination)])
        #expect(repeatEffects.isEmpty)
        #expect(navigator.nodes[type]?.isExpanded == true)
        #expect(navigator.nodes[type]?.isLoading == true)
        #expect(navigator.visibleRows().map(\.title) == ["member(_:)", "Children", "String"])
        #expect(navigator.visibleRows().map(\.depth) == [0, 1, 2])
    }

    @Test("collapsed branch completions cache children without reopening or moving selection")
    func completesCollapsedBranch() throws {
        // -- Arrange --
        let page = try DocumentationPageDecoder().decode(DocumentationFixtures.member, destination: destination)
        var navigator = NavigatorState(page: page)
        let root = try #require(navigator.roots.first)
        let group = try #require(navigator.nodes[root]?.children.first)
        let type = try #require(navigator.nodes[group]?.children.first)
        _ = NavigatorReducer.expand(nodeID: type, state: &navigator)
        navigator.selectedID = group
        NavigatorReducer.collapse(nodeID: type, state: &navigator)
        let leaf = DocumentationPage(destination: stringDestination, title: "String", kind: "struct")

        // -- Act --
        NavigatorReducer.childrenLoaded(nodeID: type, requestID: 1, page: leaf, state: &navigator)
        let effects = NavigatorReducer.expand(nodeID: type, state: &navigator)

        // -- Assert --
        #expect(navigator.nodes[type]?.isExpanded == false)
        #expect(navigator.nodes[type]?.isLoading == false)
        #expect(navigator.nodes[type]?.children == [])
        #expect(navigator.selectedID == group)
        #expect(effects.isEmpty)
    }

    @Test("failures stay on the branch, retry gets a fresh identity, and stale failures are ignored")
    func retriesBranchFailure() throws {
        // -- Arrange --
        let page = try DocumentationPageDecoder().decode(DocumentationFixtures.member, destination: destination)
        var navigator = NavigatorState(page: page)
        let root = try #require(navigator.roots.first)
        let group = try #require(navigator.nodes[root]?.children.first)
        let type = try #require(navigator.nodes[group]?.children.first)
        _ = NavigatorReducer.expand(nodeID: type, state: &navigator)
        NavigatorReducer.childrenFailed(nodeID: type, requestID: 1, message: "Unavailable", state: &navigator)
        #expect(navigator.nodes[type]?.error == "Unavailable")

        // -- Act --
        let effects = NavigatorReducer.expand(nodeID: type, state: &navigator)
        NavigatorReducer.childrenFailed(nodeID: type, requestID: 1, message: "Stale", state: &navigator)

        // -- Assert --
        #expect(effects == [.loadChildren(nodeID: type, requestID: 2, destination: stringDestination)])
        #expect(navigator.nodes[type]?.error == nil)
        #expect(navigator.nodes[type]?.isLoading == true)
        #expect(navigator.nodes[root]?.error == nil)
    }

    @Test("repeated references have distinct occurrences and ancestor cycles never fetch")
    func keepsOccurrencesAndStopsCycles() throws {
        // -- Arrange --
        let reference = DocumentationReference(
            id: "same", title: "String", kind: "symbol",
            target: .documentation(stringDestination))
        let cycle = DocumentationReference(
            id: "cycle", title: "Parent", kind: "symbol",
            target: .documentation(destination))
        let page = DocumentationPage(
            destination: destination, title: "Parent", kind: "class",
            topics: [
                DocumentationGroup(id: "first", title: "First", references: [reference, cycle]),
                DocumentationGroup(id: "second", title: "Second", references: [reference]),
            ])
        var navigator = NavigatorState(page: page)
        let root = try #require(navigator.roots.first)
        let groups = try #require(navigator.nodes[root]?.children)
        let first = try #require(navigator.nodes[groups[0]]?.children.first)
        let second = try #require(navigator.nodes[groups[1]]?.children.first)
        let cycleID = try #require(navigator.nodes[groups[0]]?.children.last)

        // -- Act --
        let cycleEffects = NavigatorReducer.expand(nodeID: cycleID, state: &navigator)

        // -- Assert --
        #expect(first != second)
        #expect(navigator.nodes[first]?.destination == stringDestination)
        #expect(navigator.nodes[second]?.destination == stringDestination)
        #expect(cycleEffects.isEmpty)
        #expect(navigator.nodes[cycleID]?.destination == destination)
        #expect(navigator.nodes[cycleID]?.isExpanded == false)
    }

    @Test("the current page stays accessible without crawling and reuses its loaded content when discovered")
    func replacesCurrentPageShortcut() throws {
        // -- Arrange --
        let current = try DocumentationPageDecoder().decode(DocumentationFixtures.member, destination: destination)
        var navigator = NavigatorState()
        NavigatorReducer.showCurrentPage(current, state: &navigator)
        let shortcut = try #require(navigator.currentPageShortcut)
        navigator.selectedID = shortcut
        let root = DocumentationPage(
            destination: DocumentationDestination(technology: "metrickit", path: "/documentation/metrickit"),
            title: "MetricKit", kind: "collection",
            topics: [
                DocumentationGroup(
                    id: "types", title: "Types",
                    references: [
                        DocumentationReference(
                            id: "member", title: "member(_:)", kind: "symbol",
                            target: .documentation(destination))
                    ])
            ]
        )

        // -- Act --
        NavigatorReducer.installRoot(root, state: &navigator)
        let selected = try #require(navigator.selectedID)
        let effects = NavigatorReducer.expand(nodeID: selected, state: &navigator)

        // -- Assert --
        #expect(navigator.currentPageShortcut == nil)
        #expect(selected != shortcut)
        #expect(navigator.nodes[selected]?.destination == destination)
        #expect(navigator.nodes[shortcut] == nil)
        #expect(effects.isEmpty)
        #expect(navigator.visibleRows().contains { $0.id == selected })
        #expect(navigator.nodes[selected]?.children.count == 1)
    }

    @Test("collapsed branches retain loaded groups for reopening without another request")
    func reusesCollapsedChildren() throws {
        // -- Arrange --
        let page = try DocumentationPageDecoder().decode(DocumentationFixtures.member, destination: destination)
        var navigator = NavigatorState(page: page)
        let root = try #require(navigator.roots.first)
        let group = try #require(navigator.nodes[root]?.children.first)
        let type = try #require(navigator.nodes[group]?.children.first)
        _ = NavigatorReducer.expand(nodeID: group, state: &navigator)
        _ = NavigatorReducer.expand(nodeID: type, state: &navigator)
        NavigatorReducer.collapse(nodeID: type, state: &navigator)
        navigator.selectedID = group
        let childPage = DocumentationPage(
            destination: stringDestination, title: "String", kind: "struct",
            topics: [
                DocumentationGroup(id: "members", title: "Members", references: [])
            ])

        // -- Act --
        NavigatorReducer.childrenLoaded(nodeID: type, requestID: 1, page: childPage, state: &navigator)
        #expect(navigator.nodes[type]?.isExpanded == false)
        #expect(navigator.selectedID == group)
        let effects = NavigatorReducer.expand(nodeID: type, state: &navigator)

        // -- Assert --
        #expect(effects.isEmpty)
        #expect(navigator.nodes[type]?.children.count == 1)
        #expect(navigator.visibleRows().map(\.title) == ["member(_:)", "Children", "String", "Members"])
    }

    @Test("history snapshots of a replaced shortcut restore the real occurrence")
    func restoresDiscoveredShortcut() throws {
        // -- Arrange --
        let current = DocumentationPage(destination: stringDestination, title: "String", kind: "struct")
        var navigator = NavigatorState()
        NavigatorReducer.showCurrentPage(current, state: &navigator)
        let shortcutSnapshot = navigator.snapshot
        let root = DocumentationPage(
            destination: DocumentationDestination(technology: "swift", path: "/documentation/swift"),
            title: "Swift", kind: "collection",
            topics: [
                DocumentationGroup(
                    id: "types", title: "Types",
                    references: [
                        DocumentationReference(
                            id: "string", title: "String", kind: "symbol",
                            target: .documentation(stringDestination))
                    ])
            ])
        NavigatorReducer.installRoot(root, state: &navigator)
        let realOccurrence = try #require(navigator.selectedID)

        // -- Act --
        navigator.snapshot = shortcutSnapshot

        // -- Assert --
        #expect(navigator.currentPageShortcut == nil)
        #expect(navigator.selectedID == realOccurrence)
        #expect(navigator.visibleRows().contains { $0.id == realOccurrence })
    }

    @Test("snapshot restoration keeps expansion, selection, and scroll across unloaded and loaded trees")
    func restoresSnapshot() throws {
        // -- Arrange --
        let page = try DocumentationPageDecoder().decode(DocumentationFixtures.member, destination: destination)
        var navigator = NavigatorState(page: page)
        let root = try #require(navigator.roots.first)
        let group = try #require(navigator.nodes[root]?.children.first)
        _ = NavigatorReducer.expand(nodeID: group, state: &navigator)
        navigator.selectedID = group
        navigator.topRow = 9
        let snapshot = navigator.snapshot
        var restored = NavigatorState()
        restored.snapshot = snapshot

        // -- Act --
        NavigatorReducer.installRoot(page, state: &restored)

        // -- Assert --
        #expect(restored.snapshot == snapshot)
        #expect(restored.visibleRows().map(\.title) == ["member(_:)", "Children", "String"])
    }
}
