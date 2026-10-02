import Testing

@testable import CLI

@Suite("Technologies list command execution")
struct TechnologiesListCommandTests {
    @Test("writes rendered technologies and records the catalog size")
    func writesTechnologies() async throws {
        // -- Arrange --
        let command = try TechnologiesListCommand.parse(["--json"])
        let deps = TechnologiesDependencies()

        // -- Act --
        try await command.run(deps: deps)

        // -- Assert --
        #expect(deps.output.lines == ["technologies"])
        #expect(deps.telemetry.commands == ["technologies.list"])
        guard case .technologyCatalog(count: 1) = deps.telemetry.metrics.first else {
            Issue.record("Expected the catalog-size metric")
            return
        }
    }
}

private typealias TechnologiesProviders = TelemetryProvider & TerminalCapabilitiesProvider
    & TechnologyCatalogClientProvider & TechnologyListRendererProvider & CommandOutputWriterProvider

private struct TechnologiesDependencies: TechnologiesProviders {
    let telemetry = RecordingCommandTelemetry()
    let terminalCapabilities = DefaultTerminalCapabilities()
    let documentationClient = TechnologiesTestClient()
    let output = RecordingCommandOutputWriter()
    var commandOutputWriter: RecordingCommandOutputWriter { output }

    func technologyListRenderer(output: OutputOptions) -> TechnologiesTestRenderer { TechnologiesTestRenderer() }
}

private struct TechnologiesTestClient: TechnologyCatalogClient {
    func fetchTechnologies() async throws -> [Technology] {
        [Technology(name: "Swift", identifier: "doc://com.apple.documentation/documentation/Swift")]
    }
}

private struct TechnologiesTestRenderer: TechnologyListRenderer {
    func render(_ technologies: [Technology]) -> String { "technologies" }
}
