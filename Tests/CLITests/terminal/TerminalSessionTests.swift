import Logging
import SwiftTUIRuntime
import Testing

@testable import CLI

@Suite("Embedded terminal lifetime", .serialized, .timeLimit(.minutes(1)))
@MainActor
struct TerminalSessionTests {
    @Test(arguments: [KeyPress(.character("q")), KeyPress(.character("c"), modifiers: .ctrl)])
    func quitReturnsControlAndCancelsRepositoryWork(_ key: KeyPress) async throws {
        // -- Arrange --
        let repository = ControlledDocumentationRepository()
        let coordinator = coordinator(repository)
        let surface = RecordingTerminalSurface()
        let input = ControlledTerminalInput()
        let session = TerminalSession(surface: surface, input: input)
        let running = Task { try await session.run(coordinator: coordinator, logs: SessionLogBuffer()) }
        defer { running.cancel() }
        let request = try await repository.waitForRequest(.technologies)
        try await surface.waitForFrame(containing: "Technologies")

        // -- Act --
        input.send(key)
        try await finish(running)
        try await repository.waitForCancellation(request)

        // -- Assert --
        #expect(coordinator.isStopped)
        #expect(surface.rawModeEvents == [true, false])
        #expect(surface.presentedFrames > 0)
    }

    @Test func cancellationRestoresSurfaceAndStopsCoordinator() async throws {
        // -- Arrange --
        let coordinator = coordinator(ControlledDocumentationRepository())
        let surface = RecordingTerminalSurface()
        let input = ControlledTerminalInput()
        let session = TerminalSession(surface: surface, input: input)
        let running = Task { try await session.run(coordinator: coordinator, logs: SessionLogBuffer()) }
        defer { running.cancel() }
        try await surface.waitForFrame(containing: "Technologies")

        // -- Act --
        running.cancel()
        do { try await finish(running) } catch is CancellationError {}

        // -- Assert --
        #expect(coordinator.isStopped)
        #expect(surface.rawModeEvents == [true, false])
    }

    @Test func presentationFailureRestoresSurfaceAndPropagates() async throws {
        // -- Arrange --
        let coordinator = coordinator(ControlledDocumentationRepository())
        let surface = RecordingTerminalSurface()
        surface.failsPresentation = true
        let session = TerminalSession(surface: surface, input: ControlledTerminalInput())

        // -- Act --
        await #expect(throws: RecordingTerminalSurface.Failure.presentation) {
            try await session.run(coordinator: coordinator, logs: SessionLogBuffer())
        }

        // -- Assert --
        #expect(coordinator.isStopped)
        #expect(surface.rawModeEvents == [true, false])
    }

    @Test func searchTypingAndPaneShortcutsUseTheRealFocusGraph() async throws {
        // -- Arrange --
        let coordinator = BrowserCoordinator(
            repository: ControlledDocumentationRepository(),
            entry: .types(technology: "swift"), openExternal: { _ in })
        let surface = RecordingTerminalSurface()
        let input = ControlledTerminalInput()
        let session = TerminalSession(surface: surface, input: input)
        let running = Task { try await session.run(coordinator: coordinator, logs: SessionLogBuffer()) }
        defer { running.cancel() }
        try await surface.waitForFrame(containing: "Symbols")

        // -- Act --
        input.send(.init(.character("/")))
        try await surface.waitForFrame(containing: "Enter submits")
        var query = ""
        for character in "q/`o[]" {
            query.append(character)
            input.send(.init(.character(character)))
            try await surface.waitForFrame(containing: query)
        }
        input.send(.init(.tab))
        try await surface.waitForFrame(containing: "Tab query")
        input.send(.init(.escape))
        try await surface.waitForFrame(containing: "Documentation")
        input.send(.init(.character("q")))
        try await finish(running)

        // -- Assert --
        #expect(coordinator.state.search?.query == "q/`o[]")
        #expect(coordinator.state.search?.isOpen == false)
        #expect(surface.rawModeEvents == [true, false])
    }

    @Test func backgroundCompletionAndLogsWakeRenderingWithoutKeys() async throws {
        // -- Arrange --
        let repository = ControlledDocumentationRepository()
        let coordinator = coordinator(repository)
        let surface = RecordingTerminalSurface()
        let input = ControlledTerminalInput()
        let logs = SessionLogBuffer()
        let session = TerminalSession(surface: surface, input: input)
        let running = Task { try await session.run(coordinator: coordinator, logs: logs) }
        defer { running.cancel() }
        let request = try await repository.waitForRequest(.technologies)
        try await surface.waitForFrame(containing: "Technologies")

        // -- Act --
        await repository.complete(
            request,
            with: .technologies([
                .init(name: "Loaded framework", identifier: "doc://com.apple.documentation/documentation/swift")
            ]))
        try await surface.waitForFrame(containing: "Loaded framework")
        input.send(.init(.character("`")))
        try await surface.waitForFrame(containing: "No session logs")
        logs.append(.init(level: .warning, label: "test", message: "Background diagnostic"))
        try await surface.waitForFrame(containing: "Background diagnostic")
        input.finish()
        try await finish(running)

        // -- Assert --
        #expect(coordinator.isStopped)
        #expect(coordinator.state.catalog.technologies.first?.name == "Loaded framework")
        #expect(surface.rawModeEvents == [true, false])
    }

    @Test func resizeRepaintsAndMovesFocusOutOfSuppressedNavigator() async throws {
        // -- Arrange --
        let coordinator = coordinator(ControlledDocumentationRepository())
        let surface = RecordingTerminalSurface()
        let input = ControlledTerminalInput()
        let signals = InProcessSignalReader()
        let session = TerminalSession(surface: surface, input: input, signals: signals)
        let running = Task { try await session.run(coordinator: coordinator, logs: SessionLogBuffer()) }
        defer { running.cancel() }
        try await surface.waitForFrame(containing: "Technologies")
        input.send(.init(.tab))
        try await surface.waitForFrame(containing: "Tab document")

        // -- Act --
        surface.surfaceSize = .init(width: 50, height: 15)
        signals.send("SIGWINCH")
        try await surface.waitForFrame(containing: "↑↓ scroll")
        let resizedFocus = coordinator.state.focus
        surface.surfaceSize = .init(width: 80, height: 24)
        signals.send("SIGWINCH")
        try await surface.waitForFrame(containing: "Navigator")
        input.send(.init(.character("q")))
        try await finish(running)

        // -- Assert --
        #expect(resizedFocus == .document)
        #expect(coordinator.state.navigatorVisible)
        #expect(surface.rawModeEvents == [true, false])
    }

    @Test func restoredNavigatorFocusIsNormalizedWhileAlreadyNarrow() async throws {
        // -- Arrange --
        let repository = ControlledDocumentationRepository()
        let coordinator = BrowserCoordinator(
            repository: repository, entry: .types(technology: "swift"), openExternal: { _ in })
        let surface = RecordingTerminalSurface()
        surface.surfaceSize = .init(width: 50, height: 15)
        let input = ControlledTerminalInput()
        let session = TerminalSession(surface: surface, input: input)
        let running = Task { try await session.run(coordinator: coordinator, logs: SessionLogBuffer()) }
        defer { running.cancel() }
        let request = try await repository.waitForRequest(.types("swift"))
        try await surface.waitForFrame(containing: "Symbols")

        // -- Act --
        coordinator.send(.setFocus(.navigator))
        await repository.complete(
            request,
            with: .types([
                .init(
                    name: "Loaded type", kind: "struct", path: "string",
                    url: "https://developer.apple.com/documentation/swift/string")
            ]))
        try await surface.waitForFrame(containing: "Loaded type")
        let restoredFocus = coordinator.state.focus
        input.finish()
        try await finish(running)

        // -- Assert --
        #expect(restoredFocus == .document)
        #expect(coordinator.state.navigatorVisible)
    }

    @Test(arguments: ["SIGINT", "SIGTERM"])
    func shutdownSignalsRestoreSurface(_ signal: String) async throws {
        // -- Arrange --
        let coordinator = coordinator(ControlledDocumentationRepository())
        let surface = RecordingTerminalSurface()
        let signals = InProcessSignalReader()
        let session = TerminalSession(surface: surface, input: ControlledTerminalInput(), signals: signals)
        let running = Task { try await session.run(coordinator: coordinator, logs: SessionLogBuffer()) }
        defer { running.cancel() }
        try await surface.waitForFrame(containing: "Technologies")

        // -- Act --
        signals.send(signal)
        try await finish(running)

        // -- Assert --
        #expect(coordinator.isStopped)
        #expect(surface.rawModeEvents == [true, false])
    }

    @Test func runtimeIssuesUseTheHostLogger() {
        // -- Arrange --
        let buffer = SessionLogBuffer()
        let logger = Logger(label: "runtime-test") { SessionLogHandler(buffer: buffer, label: $0) }
        let session = TerminalSession(
            surface: RecordingTerminalSurface(), input: ControlledTerminalInput(), logger: logger)

        // -- Act --
        session.issueSink.report(.init(severity: .error, code: "layout.failure", message: "Could not lay out a view"))

        // -- Assert --
        let entries = buffer.snapshot()
        #expect(entries.count == 1)
        #expect(entries.first?.level == .error)
        #expect(entries.first?.metadata["code"] == .string("layout.failure"))
        #expect(entries.first?.message == "Could not lay out a view")
    }

    private func coordinator(_ repository: ControlledDocumentationRepository) -> BrowserCoordinator {
        BrowserCoordinator(
            repository: repository, entry: .technologies,
            openExternal: { _ in
                Issue.record("This test must not launch an external browser")
            })
    }

    private func finish(_ task: Task<Void, any Error>) async throws {
        try await withTaskCancellationHandler(operation: { try await task.value }, onCancel: { task.cancel() })
    }
}

final class ControlledTerminalInput: TerminalInputReading {
    private let stream = AsyncStream<InputEvent>.makeStream()

    func inputEvents() -> AsyncStream<InputEvent> { stream.stream }
    func send(_ key: KeyPress) { stream.continuation.yield(.key(key)) }
    func finish() { stream.continuation.finish() }
}

final class RecordingTerminalSurface: PresentationSurface {
    enum Failure: Error { case presentation }
    var surfaceSize = CellSize(width: 80, height: 24)
    let capabilityProfile = TerminalCapabilityProfile.previewUnicode
    let appearance = TerminalAppearance.fallback
    var rawModeEvents: [Bool] = []
    var presentedFrames = 0
    var failsPresentation = false
    private var lastFrame = ""
    private let frames = AsyncStream<String>.makeStream(bufferingPolicy: .bufferingNewest(20))

    func enableRawMode() { rawModeEvents.append(true) }
    func disableRawMode() {
        rawModeEvents.append(false)
        frames.continuation.finish()
    }
    func write(_ output: String) {}
    func clearScreen() {}
    func moveCursor(to point: CellPoint) {}
    func present(_ surface: RasterSurface) throws -> TerminalPresentationMetrics {
        if failsPresentation { throw Failure.presentation }
        presentedFrames += 1
        lastFrame = surface.lines.joined(separator: "\n")
        frames.continuation.yield(lastFrame)
        return .init()
    }

    @MainActor func waitForFrame(containing text: String) async throws {
        let timeout = Task {
            try await Task.sleep(for: .seconds(5))
            frames.continuation.finish()
        }
        defer { timeout.cancel() }
        for await frame in frames.stream where frame.contains(text) { return }
        Issue.record("Did not render '\(text)'. Raw mode events: \(rawModeEvents). Last frame:\n\(lastFrame)")
        throw CancellationError()
    }
}
