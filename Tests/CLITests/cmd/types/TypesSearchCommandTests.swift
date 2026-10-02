import Testing

@testable import CLI

@Suite("Types search command execution")
struct TypesSearchCommandTests {
    @Test("writes results and an incomplete-search warning to separate streams")
    func writesPartialSearch() async throws {
        // -- Arrange --
        let command = try TypesSearchCommand.parse(["Button", "--technology", "SwiftUI", "--json"])
        let deps = SearchDependencies()

        // -- Act --
        try await command.run(deps: deps)

        // -- Assert --
        #expect(deps.output.lines == ["[]"])
        #expect(deps.output.warnings == ["Warning: search results are incomplete. 1 collections were unavailable.\n"])
        #expect(deps.telemetry.commands == ["types.search"])
        guard case .typeSearch(matches: 0) = deps.telemetry.metrics.first else {
            Issue.record("Expected the match-count metric")
            return
        }
    }
}

private typealias SearchProviders = TelemetryProvider & TerminalCapabilitiesProvider
    & DocumentationTypeSearchClientProvider & DocumentationTypeListRendererProvider & CommandOutputWriterProvider

private struct SearchDependencies: SearchProviders {
    let telemetry = RecordingCommandTelemetry()
    let terminalCapabilities = DefaultTerminalCapabilities()
    let documentationClient = SearchTestClient()
    let output = RecordingCommandOutputWriter()
    var commandOutputWriter: RecordingCommandOutputWriter { output }

    func documentationTypeListRenderer(output: OutputOptions, technology: String) -> SearchTestRenderer {
        SearchTestRenderer()
    }
}

private struct SearchTestClient: DocumentationTypeSearchClient {
    func searchTypes(query: String, technology: String) async throws -> DocumentationSearchResult {
        #expect(query == "Button")
        #expect(technology == "SwiftUI")
        return DocumentationSearchResult(types: [], unavailableCollectionPaths: ["/documentation/swiftui/controls"])
    }
}

private struct SearchTestRenderer: DocumentationTypeListRenderer {
    func render(_ types: [DocumentationType]) -> String { "[]" }
}
