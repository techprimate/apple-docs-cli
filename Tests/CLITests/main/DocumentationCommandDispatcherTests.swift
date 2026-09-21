import Foundation
import Logging
import Synchronization
import Testing

@testable import CLI

@Suite("Documentation command dispatch")
@MainActor
struct DocumentationCommandDispatcherTests {
    @Test(arguments: [OutputAudience.human, .agent], [OutputFormat.text, .json])
    func oneShotNeverCreatesBrowser(audience: OutputAudience, format: OutputFormat) async throws {
        // -- Arrange --
        let entries: [BrowserEntry] = [
            .type(name: "String", technology: "Swift"), .types(technology: "Swift"),
            .search(query: "String", technology: "Swift"), .technologies,
        ]
        var output: [String] = []
        let dispatcher = DocumentationCommandDispatcher(
            browser: { _ in throw UnexpectedRepositoryCall() },
            oneShot: OneShotDocumentationRunner(repository: DispatchRepository()),
            telemetry: NoOpTelemetry(logger: { Logger(label: "test") }, environment: [:]),
            writeOutput: { output.append($0) })

        // -- Act --
        for entry in entries {
            try await dispatcher.run(
                entry: entry, mode: .oneShot(audience: audience, format: format),
                context: .technologiesList(json: format == .json))
        }

        // -- Assert --
        #expect(output.count == 4)
        for text in output {
            #expect(text.contains("String") || text.contains("Swift"))
            if format == .json {
                #expect(
                    try JSONSerialization.jsonObject(with: Data(text.utf8)) is [String: Any]
                        || JSONSerialization.jsonObject(with: Data(text.utf8)) is [Any])
            } else if audience == .agent {
                #expect(text.hasPrefix("# "))
                #expect(text.contains("--agent"))
            }
            #expect(!text.contains("\u{1B}"))
        }
    }

    @Test(arguments: [OutputAudience.human, .agent], [OutputFormat.text, .json])
    func emptyPartialSearchKeepsWarningsSeparate(audience: OutputAudience, format: OutputFormat) async throws {
        // -- Arrange --
        let warnings = Mutex<[String]>([])
        let runner = OneShotDocumentationRunner(
            repository: PartialSearchRepository(),
            writeWarning: { message in
                warnings.withLock { $0.append(message) }
            })

        // -- Act --
        let result = try await runner.run(
            entry: .search(query: "private query", technology: "Swift"),
            audience: audience, format: format)

        // -- Assert --
        if format == .json {
            let values = try #require(JSONSerialization.jsonObject(with: Data(result.output.utf8)) as? [Any])
            #expect(values.isEmpty)
        } else {
            #expect(result.output.contains("No symbols found."))
        }
        #expect(!result.output.contains("Warning:"))
        #expect(warnings.withLock { $0.count } == 1)
        #expect(warnings.withLock { $0.first?.contains("1 collections") } == true)
        #expect(warnings.withLock { $0.first?.contains("private query") } == false)
        guard case .typeSearch(let matches) = result.metric else {
            Issue.record("Expected search count metric")
            return
        }
        #expect(matches == 0)
    }

    @Test func interactiveNeverRunsOneShot() async throws {
        // -- Arrange --
        var entries: [BrowserEntry] = []
        let dispatcher = DocumentationCommandDispatcher(
            browser: { entries.append($0) }, oneShot: RejectingOneShot(),
            telemetry: NoOpTelemetry(logger: { Logger(label: "test") }, environment: [:]),
            writeOutput: { _ in Issue.record("Interactive dispatch must not print") })

        // -- Act --
        try await dispatcher.run(entry: .technologies, mode: .interactive, context: .technologiesList(json: false))

        // -- Assert --
        #expect(entries == [.technologies])
    }
}

private struct RejectingOneShot: OneShotDocumentationRunning {
    func run(
        entry: BrowserEntry, audience: OutputAudience, format: OutputFormat
    ) async throws -> OneShotDocumentationResult {
        throw UnexpectedRepositoryCall()
    }
}

private struct PartialSearchRepository: DocumentationRepository {
    func search(query: String, technology: String) async throws -> DocumentationSearchResult {
        .init(types: [], unavailableCollectionPaths: ["/documentation/swift/unavailable"])
    }
}

private struct DispatchRepository: DocumentationRepository {
    func type(named name: String, technology: String) async throws -> LoadedDocumentationPage {
        let data = Data(#"{"metadata":{"title":"String","symbolKind":"struct"},"upstreamOnly":true}"#.utf8)
        return try LoadedDocumentationPage(
            page: DocumentationPageDecoder().decode(
                data,
                destination: .init(
                    technology: "swift", path: "/documentation/swift/string")), responseByteCount: data.count)
    }
    func types(technology: String) async throws -> [DocumentationType] {
        [
            .init(
                name: "String", kind: "struct", path: "string",
                url: "https://developer.apple.com/documentation/swift/string")
        ]
    }
    func search(query: String, technology: String) async throws -> DocumentationSearchResult {
        try await .init(types: types(technology: technology), unavailableCollectionPaths: [])
    }
    func technologies() async throws -> [Technology] {
        [.init(name: "Swift", identifier: "doc://swift/documentation/Swift")]
    }
}
