import Foundation
import Testing

@testable import CLI

@Suite("Browser entry loading", .timeLimit(.minutes(1)))
@MainActor
struct BrowserStartupTests {
    private let root = DocumentationDestination(technology: "swift", path: "/documentation/swift")
    private let string = DocumentationDestination(technology: "swift", path: "/documentation/swift/string")

    @Test("named entry renders before its independently loaded root and preserves named lookup spelling")
    func opensNamedPageIndependently() async throws {
        // -- Arrange --
        let repository = ControlledDocumentationRepository()
        let coordinator = makeCoordinator(repository, entry: .type(name: "String.Index", technology: "Swift"))
        defer { coordinator.stop() }
        coordinator.start()
        let named = try await repository.waitForRequest(.named("String.Index", "Swift"))
        let rootRequest = try await repository.waitForRequest(.root("Swift"))
        let nested = DocumentationDestination(technology: "swift", path: "/documentation/swift/string/index")

        // -- Act --
        await repository.complete(named, with: .page(loaded(nested, title: "Index")))
        try await waitForState(coordinator) { $0.currentPage?.destination == nested }
        #expect(coordinator.state.navigatorTree.roots.isEmpty)
        #expect(coordinator.state.navigatorTree.currentPageShortcut != nil)
        await repository.complete(rootRequest, with: .page(loaded(root, title: "Swift")))
        try await waitForState(coordinator) { !$0.navigatorTree.roots.isEmpty }

        // -- Assert --
        #expect(coordinator.state.currentPage?.destination == nested)
        #expect(coordinator.state.history.current?.location == .page(nested))
        #expect(await repository.requests.count == 2)
    }

    @Test("list entry loads catalog results and root context without searching or crawling symbols")
    func opensTypeCatalog() async throws {
        // -- Arrange --
        let repository = ControlledDocumentationRepository()
        let coordinator = makeCoordinator(repository, entry: .types(technology: "Swift"))
        defer { coordinator.stop() }
        coordinator.start()
        let list = try await repository.waitForRequest(.types("Swift"))
        let rootRequest = try await repository.waitForRequest(.root("Swift"))
        let type = DocumentationType(name: "String", kind: "struct", path: "string", url: string.url.absoluteString)

        // -- Act --
        await repository.complete(list, with: .types([type]))
        await repository.complete(rootRequest, with: .page(loaded(root, title: "Swift")))
        try await waitForState(coordinator) { $0.catalog.types["swift"] == [type] && !$0.navigatorTree.roots.isEmpty }

        // -- Assert --
        #expect(coordinator.state.currentLocation == .types(technology: "swift"))
        #expect(coordinator.state.currentPage == nil)
        #expect(coordinator.state.history.current?.location == .types(technology: "swift"))
        #expect(await repository.requests.count == 2)
    }

    @Test("global catalog has no implied technology and start is idempotent")
    func opensGlobalCatalog() async throws {
        // -- Arrange --
        let repository = ControlledDocumentationRepository()
        let coordinator = makeCoordinator(repository, entry: .technologies)
        defer { coordinator.stop() }
        coordinator.start()
        coordinator.start()
        let request = try await repository.waitForRequest(.technologies)

        // -- Act --
        await repository.complete(request, with: .technologies([]))
        try await waitForState(coordinator) { $0.catalog.pendingTechnologiesID == nil }
        coordinator.send(.showSearch)

        // -- Assert --
        #expect(coordinator.state.currentLocation == .technologies)
        #expect(coordinator.state.technology == nil)
        #expect(coordinator.state.search == nil)
        #expect(await repository.requests == [.technologies])
    }

    @Test("initial search keeps a useful underlying catalog and canonicalizes retained state")
    func opensInitialSearch() async throws {
        // -- Arrange --
        let repository = ControlledDocumentationRepository()
        let coordinator = makeCoordinator(repository, entry: .search(query: "String", technology: "Swift Language"))
        defer { coordinator.stop() }
        coordinator.start()
        let rootRequest = try await repository.waitForRequest(.root("Swift Language"))
        let list = try await repository.waitForRequest(.types("Swift Language"))
        let search = try await repository.waitForRequest(.search("String", "swift language"))

        // -- Act --
        await repository.complete(rootRequest, with: .page(loaded(root, title: "Swift")))
        await repository.complete(list, with: .types([]))
        await repository.complete(
            search, with: .search(DocumentationSearchResult(types: [], unavailableCollectionPaths: [])))
        try await waitForState(coordinator) { $0.technology == "swift" && $0.search?.hasSearched == true }
        coordinator.send(.dismissSearch)

        // -- Assert --
        #expect(coordinator.state.currentLocation?.technology == "swift")
        #expect(coordinator.state.search?.technology == "swift")
        #expect(coordinator.state.search?.query == "String")
        #expect(coordinator.state.search?.isOpen == false)
        #expect(coordinator.state.technologySearches["swift language"] == nil)
        #expect(!coordinator.state.navigatorTree.roots.isEmpty)
    }

    @Test("initial named failure retries named lookup and keeps the root visible")
    func retriesNamedFailure() async throws {
        // -- Arrange --
        let repository = ControlledDocumentationRepository()
        let coordinator = makeCoordinator(repository, entry: .type(name: "String.Index", technology: "Swift"))
        defer { coordinator.stop() }
        coordinator.start()
        let named = try await repository.waitForRequest(.named("String.Index", "Swift"))
        let rootRequest = try await repository.waitForRequest(.root("Swift"))
        await repository.complete(rootRequest, with: .page(loaded(root, title: "Swift")))
        await repository.fail(named, with: URLError(.notConnectedToInternet))
        try await waitForState(coordinator) { $0.pageError != nil }

        // -- Act --
        coordinator.send(.retry)
        let retry = try await repository.waitForRequest(.named("String.Index", "Swift"), occurrence: 2)
        await repository.complete(retry, with: .page(loaded(string, title: "String")))
        try await waitForState(coordinator) { $0.currentPage != nil }

        // -- Assert --
        #expect(coordinator.state.pageError == nil)
        #expect(!coordinator.state.navigatorTree.roots.isEmpty)
        #expect(await repository.requests.count == 3)
    }

    @Test("opening an in-flight technology root shares its existing request")
    func sharesRootRequest() async throws {
        // -- Arrange --
        let repository = ControlledDocumentationRepository()
        let coordinator = makeCoordinator(repository, entry: .type(name: "String", technology: "Swift"))
        defer { coordinator.stop() }
        coordinator.start()
        _ = try await repository.waitForRequest(.named("String", "Swift"))
        let rootRequest = try await repository.waitForRequest(.root("Swift"))

        // -- Act --
        coordinator.send(.open(root))
        await repository.complete(rootRequest, with: .page(loaded(root, title: "Swift")))
        try await waitForState(coordinator) { $0.catalog.pendingRoots.isEmpty }

        // -- Assert --
        #expect(coordinator.state.currentPage?.destination == root)
        #expect(coordinator.state.pendingNavigation == nil)
        #expect(await repository.requests.count == 2)
    }

    private func makeCoordinator(
        _ repository: ControlledDocumentationRepository, entry: BrowserEntry
    ) -> BrowserCoordinator {
        BrowserCoordinator(
            repository: repository, entry: entry, openExternal: { _ in Issue.record("Unexpected browser opening") })
    }

    private func loaded(_ destination: DocumentationDestination, title: String) -> LoadedDocumentationPage {
        LoadedDocumentationPage(
            page: DocumentationPage(destination: destination, title: title, kind: "collection"), responseByteCount: 100)
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
