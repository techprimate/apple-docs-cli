import Foundation

#if DEBUG
    protocol OneShotDocumentationRunning: Sendable {
        func run(entry: BrowserEntry, audience: OutputAudience, format: OutputFormat) async throws
            -> OneShotDocumentationResult
    }
    extension OneShotDocumentationRunner: OneShotDocumentationRunning {}
#else
    typealias OneShotDocumentationRunning = OneShotDocumentationRunner
#endif

struct OneShotDocumentationResult: Sendable {
    let output: String
    let metric: TelemetryMetric
}

@MainActor
struct DocumentationCommandDispatcher {
    let browser: @MainActor (BrowserEntry) async throws -> Void
    let oneShot: OneShotDocumentationRunning
    let telemetry: Telemetry
    var writeOutput: (String) -> Void = { print($0) }

    func run(entry: BrowserEntry, mode: OutputMode, context: TelemetryCommandContext) async throws {
        switch mode {
        case .interactive:
            try await browser(entry)
        case .oneShot(let audience, let format):
            let result = try await oneShot.run(entry: entry, audience: audience, format: format)
            telemetry.record(result.metric, context: context)
            writeOutput(result.output)
        }
    }
}

struct OneShotDocumentationRunner: Sendable {
    let repository: DocumentationRepository
    var writeWarning: @Sendable (String) -> Void = {
        FileHandle.standardError.write(Data(($0 + "\n").utf8))
    }

    func run(
        entry: BrowserEntry, audience: OutputAudience, format: OutputFormat
    ) async throws -> OneShotDocumentationResult {
        switch entry {
        case .type(let name, let technology):
            let result = try await TypesViewCommandRunner(
                client: repository,
                renderer: DefaultTypeDocumentationRenderer(output: format == .json ? .json : .text, audience: audience)
            ).run(name: name, technology: technology)
            return .init(output: result.output, metric: .typeView(responseBytes: result.responseByteCount))
        case .types(let technology):
            let result = try await TypesListCommandRunner(
                client: repository,
                renderer: symbolsRenderer(audience: audience, format: format, technology: technology)
            ).run(technology: technology)
            return .init(output: result.output, metric: .typeCatalog(count: result.typeCount))
        case .search(let query, let technology):
            let result = try await TypesSearchCommandRunner(
                client: repository,
                renderer: symbolsRenderer(audience: audience, format: format, technology: technology)
            ).run(query: query, technology: technology)
            if result.unavailableCollectionCount > 0 {
                writeWarning(
                    "Warning: search results are incomplete. "
                        + "\(result.unavailableCollectionCount) collections were unavailable."
                )
            }
            return .init(output: result.output, metric: .typeSearch(matches: result.matchCount))
        case .technologies:
            let result = try await TechnologiesListCommandRunner(
                client: repository,
                renderer: DefaultTechnologyListRenderer(output: format == .json ? .json : .table, audience: audience)
            ).run()
            return .init(output: result.output, metric: .technologyCatalog(count: result.technologyCount))
        }
    }

    private func symbolsRenderer(
        audience: OutputAudience, format: OutputFormat, technology: String
    ) -> DefaultDocumentationTypeListRenderer {
        .init(output: format == .json ? .json : .table, audience: audience, technology: technology)
    }
}
