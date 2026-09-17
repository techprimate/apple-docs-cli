import Foundation
import Testing

@testable import CLI

@Suite("Browser repository effects", .timeLimit(.minutes(1)))
@MainActor
struct BrowserCoordinatorTests {
    private let first = DocumentationDestination(technology: "swift", path: "/documentation/swift/string")
    private let second = DocumentationDestination(technology: "swift", path: "/documentation/swift/array")

    @Test("out-of-order completions cannot replace the newest page and stopping rejects further actions")
    func rejectsStalePages() async throws {
        // -- Arrange --
        let repository = ControlledDocumentationRepository(respondsToCancellation: false)
        let coordinator = makeCoordinator(repository)
        defer { coordinator.stop() }
        coordinator.send(.open(first))
        let firstRequest = try await repository.waitForRequest(.page(first))
        coordinator.send(.open(second))
        let secondRequest = try await repository.waitForRequest(.page(second))

        // -- Act --
        await repository.complete(secondRequest, with: .page(loaded(second)))
        try await waitForState(coordinator) { $0.currentPage?.destination == second }
        await repository.complete(firstRequest, with: .page(loaded(first)))
        try await repository.waitForCancellation(firstRequest)
        coordinator.stop()
        coordinator.send(.open(first))

        // -- Assert --
        #expect(coordinator.state.currentPage?.destination == second)
        #expect(coordinator.state.pendingNavigation == nil)
        #expect(coordinator.isStopped)
        #expect(await repository.requests == [.page(first), .page(second)])
    }

    @Test("cached pages share fetch identity across fragments while navigation retains the requested anchor")
    func reusesCachedPages() async throws {
        // -- Arrange --
        let repository = ControlledDocumentationRepository()
        let coordinator = makeCoordinator(repository)
        defer { coordinator.stop() }
        coordinator.send(.open(first))
        let request = try await repository.waitForRequest(.page(first))
        await repository.complete(request, with: .page(loaded(first)))
        try await waitForState(coordinator) { $0.currentPage != nil }
        var anchored = first
        anchored.fragment = "Overview"

        // -- Act --
        coordinator.send(.open(anchored))
        try await waitForState(coordinator) { $0.currentLocation == .page(anchored) }

        // -- Assert --
        #expect(coordinator.state.history.current?.location == .page(anchored))
        #expect(coordinator.state.pendingNavigation == nil)
        #expect(await repository.requests == [.page(first)])
    }

    @Test("cancelling page navigation keeps a shared branch request alive")
    func retainsActiveConsumers() async throws {
        // -- Arrange --
        let repository = ControlledDocumentationRepository()
        let coordinator = makeCoordinator(repository)
        defer { coordinator.stop() }
        let page = loaded(
            first,
            topics: [
                DocumentationGroup(
                    id: "types", title: "Types",
                    references: [
                        DocumentationReference(
                            id: "array", title: "Array", kind: "symbol", target: .documentation(second))
                    ])
            ])
        coordinator.send(.open(first))
        let initial = try await repository.waitForRequest(.page(first))
        await repository.complete(initial, with: .page(page))
        try await waitForState(coordinator) { $0.currentPage != nil }
        let shortcut = try #require(coordinator.state.navigatorTree.currentPageShortcut)
        let group = try #require(coordinator.state.navigatorTree.nodes[shortcut]?.children.first)
        let branch = try #require(coordinator.state.navigatorTree.nodes[group]?.children.first)
        coordinator.send(.expand(branch))
        let shared = try await repository.waitForRequest(.page(second))
        coordinator.send(.open(second))

        // -- Act --
        coordinator.send(.escape)
        await repository.complete(shared, with: .page(loaded(second)))
        try await waitForState(coordinator) { $0.navigatorTree.nodes[branch]?.loadState == .loaded }

        // -- Assert --
        #expect(coordinator.state.currentPage == page.page)
        #expect(coordinator.state.pendingNavigation == nil)
        #expect(await repository.requests == [.page(first), .page(second)])
        #expect(await repository.cancelled.isEmpty)
    }

    @Test("dismissing search cancels repository work without presenting cancellation as failure")
    func cancelsSearch() async throws {
        // -- Arrange --
        let repository = ControlledDocumentationRepository()
        let coordinator = makeCoordinator(repository)
        defer { coordinator.stop() }
        coordinator.send(.showSearch)
        coordinator.send(.editQuery("String"))
        coordinator.send(.submitSearch)
        let request = try await repository.waitForRequest(.search("String", "swift"))

        // -- Act --
        coordinator.send(.dismissSearch)
        try await repository.waitForCancellation(request)

        // -- Assert --
        #expect(coordinator.state.search?.isOpen == false)
        #expect(coordinator.state.search?.pendingRequestID == nil)
        #expect(coordinator.state.search?.error == nil)
        #expect(coordinator.state.search?.query == "String")
    }

    @Test("repository cancellation clears loading without an ordinary page error")
    func handlesTransportCancellation() async throws {
        // -- Arrange --
        let repository = ControlledDocumentationRepository()
        let coordinator = makeCoordinator(repository)
        defer { coordinator.stop() }
        coordinator.send(.open(first))
        let request = try await repository.waitForRequest(.page(first))

        // -- Act --
        await repository.fail(request, with: CancellationError())
        try await waitForState(coordinator) { $0.pendingNavigation == nil }

        // -- Assert --
        #expect(coordinator.state.pageError == nil)
        #expect(coordinator.state.failedNavigation == nil)
        #expect(coordinator.state.currentPage == nil)
    }

    @Test("a failing branch leaves the current page intact")
    func isolatesBranchFailure() async throws {
        // -- Arrange --
        let repository = ControlledDocumentationRepository()
        let coordinator = makeCoordinator(repository)
        defer { coordinator.stop() }
        let page = loaded(
            first,
            topics: [
                DocumentationGroup(
                    id: "types", title: "Types",
                    references: [
                        DocumentationReference(
                            id: "array", title: "Array", kind: "symbol", target: .documentation(second))
                    ])
            ])
        coordinator.send(.open(first))
        let initial = try await repository.waitForRequest(.page(first))
        await repository.complete(initial, with: .page(page))
        try await waitForState(coordinator) { $0.currentPage != nil }
        let shortcut = try #require(coordinator.state.navigatorTree.currentPageShortcut)
        let group = try #require(coordinator.state.navigatorTree.nodes[shortcut]?.children.first)
        let branch = try #require(coordinator.state.navigatorTree.nodes[group]?.children.first)
        coordinator.send(.expand(branch))
        let request = try await repository.waitForRequest(.page(second))

        // -- Act --
        await repository.fail(request, with: URLError(.notConnectedToInternet))
        try await waitForState(coordinator) { $0.navigatorTree.nodes[branch]?.error != nil }

        // -- Assert --
        #expect(coordinator.state.currentPage == page.page)
        #expect(coordinator.state.pageError == nil)
        #expect(coordinator.state.navigatorTree.nodes[branch]?.isLoading == false)
    }

    @Test("host stop cancels all independently owned entry and search operations")
    func stopsAllWork() async throws {
        // -- Arrange --
        let repository = ControlledDocumentationRepository()
        let coordinator = BrowserCoordinator(
            repository: repository, entry: .type(name: "String", technology: "Swift"),
            openExternal: { _ in Issue.record("Unexpected external opening") })
        defer { coordinator.stop() }
        coordinator.start()
        let named = try await repository.waitForRequest(.named("String", "Swift"))
        let root = try await repository.waitForRequest(.root("Swift"))
        coordinator.send(.showSearch)
        coordinator.send(.editQuery("String"))
        coordinator.send(.submitSearch)
        let search = try await repository.waitForRequest(.search("String", "swift"))

        // -- Act --
        coordinator.stop()
        for id in [named, root, search] { try await repository.waitForCancellation(id) }

        // -- Assert --
        #expect(coordinator.isStopped)
        #expect(coordinator.state.pendingNavigation == nil)
        #expect(coordinator.state.catalog.pendingRoots.isEmpty)
        #expect(coordinator.state.search?.pendingRequestID == nil)
        #expect(coordinator.state.search?.isOpen == false)
        #expect(coordinator.state.pageError == nil)
    }

    @Test("state publication precedes effects and a host stop during publication prevents new work")
    func publishesBeforeEffects() async {
        // -- Arrange --
        let repository = ControlledDocumentationRepository()
        let coordinator = makeCoordinator(repository)
        var observedPending = false
        coordinator.onChange = { state in
            if state.pendingNavigation != nil {
                observedPending = true
                coordinator.stop()
            }
        }
        defer {
            coordinator.onChange = nil
            coordinator.stop()
        }

        // -- Act --
        coordinator.send(.open(first))

        // -- Assert --
        #expect(observedPending)
        #expect(coordinator.isStopped)
        #expect(await repository.requests.isEmpty)
    }

    private func makeCoordinator(_ repository: ControlledDocumentationRepository) -> BrowserCoordinator {
        BrowserCoordinator(
            repository: repository, entry: .types(technology: "Swift"),
            openExternal: { _ in
                Issue.record("Unexpected external URL opening")
            })
    }

    private func loaded(
        _ destination: DocumentationDestination, topics: [DocumentationGroup] = []
    ) -> LoadedDocumentationPage {
        LoadedDocumentationPage(
            page: DocumentationPage(destination: destination, title: "Page", kind: "struct", topics: topics),
            responseByteCount: 100)
    }

    private func waitForState(
        _ coordinator: BrowserCoordinator, matching predicate: (BrowserState) -> Bool
    ) async throws {
        let changes = AsyncStream<BrowserState> { continuation in
            coordinator.onChange = { continuation.yield($0) }
            continuation.yield(coordinator.state)
        }
        defer { coordinator.onChange = nil }
        for await state in changes where predicate(state) { return }
        throw CancellationError()
    }
}
