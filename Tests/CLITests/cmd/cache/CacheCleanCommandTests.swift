import Foundation
import Testing

@testable import CLI

@Suite("Cache clean command")
struct CacheCleanCommandTests {
    @Test("writes the unavailable-cache result through the injected output")
    func writesUnavailableCache() throws {
        // -- Arrange --
        let command = try CacheCleanCommand.parse([])
        let deps = CacheCleanTestDependencies()

        // -- Act --
        command.run(deps: deps)

        // -- Assert --
        #expect(deps.output.lines == ["Apple documentation cache is unavailable."])
        #expect(deps.telemetry.commands == ["cache.clean"])
    }

    @Test("registers the cache clean command hierarchy")
    func parsesCacheCleanCommand() throws {
        // -- Arrange --
        let arguments = ["cache", "clean"]

        // -- Act --
        let command = try CLI.parseAsRoot(arguments)

        // -- Assert --
        #expect(command is CacheCleanCommand)
    }
}

private struct CacheCleanTestDependencies: TelemetryProvider, DocumentationCacheProvider, CommandOutputWriterProvider {
    let telemetry = RecordingCommandTelemetry()
    let output = RecordingCommandOutputWriter()
    var documentationCache: URLCache? { nil }
    var commandOutputWriter: RecordingCommandOutputWriter { output }
}
