import Foundation
import Testing

@testable import CLI

@Suite("Types view command execution")
struct TypesViewCommandExecutionTests {
    @Test("writes rendered documentation and records the response size")
    func writesDocumentation() async throws {
        // -- Arrange --
        let command = try TypesViewCommand.parse(["String", "--technology", "Swift", "--json"])
        let deps = ViewDependencies()

        // -- Act --
        try await command.run(deps: deps)

        // -- Assert --
        #expect(deps.output.lines == ["rendered page"])
        #expect(deps.telemetry.commands == ["types.view"])
        guard case .typeView(responseBytes: 4) = deps.telemetry.metrics.first else {
            Issue.record("Expected the response size metric")
            return
        }
    }
}

private typealias ViewProviders = TelemetryProvider & TerminalCapabilitiesProvider
    & AppleDocumentationClientProvider & TypeDocumentationRendererProvider & CommandOutputWriterProvider

private struct ViewDependencies: ViewProviders {
    let telemetry = RecordingCommandTelemetry()
    let terminalCapabilities = DefaultTerminalCapabilities()
    let documentationClient = ViewTestClient()
    let output = RecordingCommandOutputWriter()
    var commandOutputWriter: RecordingCommandOutputWriter { output }

    func documentationRenderer(output: OutputOptions) -> ViewTestRenderer { ViewTestRenderer() }
}

private struct ViewTestClient: AppleDocumentationClient {
    func fetchType(named name: String, technology: String) async throws -> TypeDocumentationDocument {
        #expect(name == "String")
        #expect(technology == "Swift")
        return TypeDocumentationDocument(
            data: Data("page".utf8),
            destination: DocumentationDestination(technology: "swift", path: "/documentation/swift/string")
        )
    }
}

private struct ViewTestRenderer: TypeDocumentationRenderer {
    func render(_ document: TypeDocumentationDocument) -> String { "rendered page" }
}
