import Logging
import Testing

@testable import CLI

@Suite("Types list command dependencies")
struct TypesListCommandTests {
    @Test("runs with a complete injected dependency provider")
    func usesInjectedDependencies() async throws {
        // -- Arrange --
        let command = try TypesListCommand.parse(["--technology", "SwiftData", "--json"])
        let deps = TestDeps()
        let telemetry = deps.telemetry

        // -- Act --
        try await command.run(deps: deps)

        // -- Assert --
        #expect(telemetry.commands == ["types.list"])
        #expect(telemetry.typeCounts == [1])
    }
}

private typealias TestProviders = TelemetryProvider & TerminalCapabilitiesProvider
    & DocumentationTypeCatalogClientProvider & DocumentationTypeListRendererProvider

private struct TestDeps: TestProviders {
    let telemetry = TypesListTelemetryRecorder()
    let terminalCapabilities = TypesListTestTerminal()
    let documentationClient = TypesListTestClient()

    typealias Renderer = DefaultDocumentationTypeListRenderer

    func documentationTypeListRenderer(output: OutputOptions, technology: String) -> Renderer {
        DefaultDocumentationTypeListRenderer(output: .json, technology: technology)
    }
}

private struct TypesListTestTerminal: TerminalCapabilities {
    var stdinIsTTY: Bool { false }
}

private struct TypesListTestClient: DocumentationTypeCatalogClient {
    func fetchTypes(technology: String) async throws -> [DocumentationType] {
        #expect(technology == "SwiftData")
        return [
            DocumentationType(
                name: "Model", kind: "macro", path: "model",
                url: "https://developer.apple.com/documentation/swiftdata/model")
        ]
    }
}

private final class TypesListTelemetryRecorder: Telemetry, @unchecked Sendable {
    private(set) var commands: [String] = []
    private(set) var typeCounts: [Int] = []

    func start() {}
    func startCommand(_ context: TelemetryCommandContext) { commands.append(context.command) }
    func record(_ metric: TelemetryMetric, context: TelemetryCommandContext) {
        if case .typeCatalog(let count) = metric { typeCounts.append(count) }
    }
    func finishCommand(error: (any Error)?) {}
    func makeLogHandler() -> (any LogHandler)? { nil }
}
