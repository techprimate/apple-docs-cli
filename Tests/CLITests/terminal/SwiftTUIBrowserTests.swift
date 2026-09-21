import Foundation
import Testing

@testable import CLI

@Suite("Browser composition", .serialized, .timeLimit(.minutes(1)))
@MainActor
struct SwiftTUIBrowserTests {
    @Test func runsTheRequestedEntryAndCancelsOnReturn() async throws {
        // -- Arrange --
        let repository = ControlledDocumentationRepository()
        let surface = RecordingTerminalSurface()
        let input = ControlledTerminalInput()
        let browser = DefaultDocumentationBrowser(
            repository: repository, logs: SessionLogBuffer(),
            opener: RejectingOpener(), session: .init(surface: surface, input: input))
        let running = Task { try await browser.run(entry: .types(technology: "swift")) }
        defer { running.cancel() }
        let request = try await repository.waitForRequest(.types("swift"))
        try await surface.waitForFrame(containing: "Symbols")

        // -- Act --
        input.send(.init(.character("q")))
        try await withTaskCancellationHandler(operation: { try await running.value }, onCancel: { running.cancel() })
        try await repository.waitForCancellation(request)

        // -- Assert --
        #expect(surface.rawModeEvents == [true, false])
        #expect(await repository.requests.contains(.root("swift")))
    }

    private struct RejectingOpener: ExternalURLOpener {
        func open(_ url: URL) async throws { Issue.record("Unexpected external browser activation") }
    }
}
