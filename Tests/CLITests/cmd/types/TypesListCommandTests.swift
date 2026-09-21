import Logging
import Testing

@testable import CLI

@Suite("Types list command dependencies")
@MainActor
struct TypesListCommandTests {
    @Test("runs with injected documentation dispatch dependencies")
    func usesInjectedDependencies() async throws {
        // -- Arrange --
        let command = try TypesListCommand.parse(["--technology", "SwiftData", "--json"])
        let telemetry = TypesListTelemetryRecorder()
        var output: [String] = []
        let dispatcher = DocumentationCommandDispatcher(
            browser: { _ in throw UnexpectedRepositoryCall() },
            oneShot: OneShotDocumentationRunner(repository: TypesListTestRepository()),
            telemetry: telemetry,
            writeOutput: { output.append($0) })

        // -- Act --
        try await command.run(
            mode: .oneShot(audience: .human, format: .json), telemetry: telemetry, dispatcher: dispatcher)

        // -- Assert --
        #expect(telemetry.commands == ["types.list"])
        #expect(telemetry.typeCounts == [1])
        #expect(output.count == 1)
        #expect(output[0].contains("Model"))
    }
}

private struct TypesListTestRepository: DocumentationRepository {
    func types(technology: String) async throws -> [DocumentationType] {
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
