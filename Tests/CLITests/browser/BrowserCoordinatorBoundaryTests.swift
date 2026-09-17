import Foundation
import Logging
import Synchronization
import Testing

@testable import CLI

@Suite("Browser effect boundaries", .timeLimit(.minutes(1)))
@MainActor
struct BrowserCoordinatorBoundaryTests {
    @Test("session page reuse avoids another request through the real HTTP-backed repository")
    func reusesHTTPResponse() async throws {
        // -- Arrange --
        let destination = DocumentationDestination(technology: "swift", path: "/documentation/swift/string")
        let url = try #require(
            URL(string: "https://developer.apple.com/tutorials/data/documentation/swift/string.json"))
        let data = Data(#"{"metadata":{"title":"String","symbolKind":"struct"}}"#.utf8)
        let transport = HTTPTestTransport(responses: [url: .http(data: data)])
        let logger = Logger(label: "test") { _ in SwiftLogNoOpLogHandler() }
        let repository = DefaultDocumentationRepository(
            logger: logger,
            dependencies: DefaultAppleDocumentationClient(logger: logger, dependencies: transport))
        let coordinator = BrowserCoordinator(
            repository: repository, entry: .types(technology: "Swift"),
            openExternal: { _ in Issue.record("Unexpected external opening") })
        defer { coordinator.stop() }
        coordinator.send(.open(destination))
        try await waitForState(coordinator) { $0.currentPage != nil }

        // -- Act --
        coordinator.send(.open(destination))
        try await waitForState(coordinator) { $0.pendingNavigation == nil }

        // -- Assert --
        #expect(coordinator.state.currentPage?.title == "String")
        #expect(await transport.requestedURLs == [url])
    }

    @Test("search logs include operation and coverage metadata without query text")
    func logsSafeSearchMetadata() async throws {
        // -- Arrange --
        let recorder = ClientLogRecorder()
        let repository = ControlledDocumentationRepository()
        let coordinator = BrowserCoordinator(
            repository: repository, entry: .types(technology: "Swift"),
            openExternal: { _ in Issue.record("Unexpected external opening") }, logger: recorder.logger())
        defer { coordinator.stop() }
        coordinator.send(.showSearch)
        coordinator.send(.editQuery("Private lookup text"))
        coordinator.send(.submitSearch)
        let request = try await repository.waitForRequest(.search("Private lookup text", "swift"))

        // -- Act --
        await repository.complete(
            request, with: .search(DocumentationSearchResult(types: [], unavailableCollectionPaths: ["missing"])))
        try await waitForState(coordinator) { $0.search?.hasSearched == true }

        // -- Assert --
        let event = try #require(recorder.events.first { $0.message.description == "Completed browser search" })
        #expect(event.level == .debug)
        #expect(event.metadata?["results"]?.description == "0")
        #expect(event.metadata?["unavailable"]?.description == "1")
        #expect(event.metadata?["apple_docs.technology"]?.description == "swift")
        #expect(!recorder.events.contains { "\($0.message) \($0.metadata ?? [:])".contains("Private lookup text") })
    }

    @Test("external opening uses the injected action and failures remain local")
    func reportsExternalFailure() async throws {
        // -- Arrange --
        let repository = ControlledDocumentationRepository()
        let opened = Mutex<[URL]>([])
        let url = try #require(URL(string: "https://developer.apple.com/documentation/swift"))
        let coordinator = BrowserCoordinator(
            repository: repository, entry: .types(technology: "Swift"),
            openExternal: { url in
                opened.withLock { $0.append(url) }
                throw URLError(.cannotOpenFile)
            })
        defer { coordinator.stop() }

        // -- Act --
        coordinator.send(.openExternal(url))
        try await waitForState(coordinator) { $0.externalError != nil }

        // -- Assert --
        #expect(opened.withLock { $0 } == [url])
        #expect(!coordinator.isStopped)
        #expect(coordinator.state.pageError == nil)
        #expect(coordinator.state.pendingExternalRequestID == nil)
        #expect(await repository.requests.isEmpty)
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
