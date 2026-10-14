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
    & DocumentationTypeSearchRepositoryProvider & DocumentationSearchRendererProvider & CommandOutputWriterProvider

private struct SearchDependencies: SearchProviders {
    let telemetry = RecordingCommandTelemetry()
    let terminalCapabilities = DefaultTerminalCapabilities()
    let documentationRepository = SearchTestClient()
    let output = RecordingCommandOutputWriter()
    var commandOutputWriter: RecordingCommandOutputWriter { output }

    func documentationSearchRenderer(output: OutputOptions) -> SearchTestRenderer {
        SearchTestRenderer()
    }
}

private struct SearchTestClient: DocumentationTypeSearchRepository {
    func searchTypes(query: String, technology: String) async throws -> DocumentationSearchResult {
        #expect(query == "Button")
        #expect(technology == "SwiftUI")
        return DocumentationSearchResult(
            technology: "swiftui", types: [],
            unavailableCollections: [
                DocumentationCollectionFailure(path: "/documentation/swiftui/controls", reason: .httpStatus(404))
            ])
    }
}

private struct SearchTestRenderer: DocumentationSearchRenderer {
    func render(_ result: DocumentationSearchResult) -> String { "[]" }
}
