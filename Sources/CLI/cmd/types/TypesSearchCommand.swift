import ArgumentParser
import Logging

#if canImport(SentrySwift)
    @preconcurrency import SentrySwift
#endif

struct TypesSearchCommand: AsyncParsableCommand {
    private static let logger = Logger(
        label: "com.techprimate.apple-docs.types-search"
    )

    static let configuration = CommandConfiguration(
        commandName: "search",
        abstract: "Search types in an Apple documentation technology."
    )

    @Argument(help: "The type name or path to search for.")
    var query: String

    @Option(help: "The framework or technology whose types to search.")
    var technology: String

    @Flag(help: "Output a JSON array of matching types.")
    var json = false

    mutating func run() async throws {
        // Search text can be user-authored, so it is deliberately excluded from telemetry context.
        let context = SentryCommandContext.typesSearch(
            technology: technology,
            json: json
        )
        #if canImport(SentrySwift)
            if SentrySDK.isEnabled {
                let transaction = SentrySDK.startTransaction(
                    name: context.transactionName,
                    operation: "console.command",
                    bindToScope: true
                )
                for (key, value) in context.attributes {
                    transaction.setData(value: value, key: key)
                }
                SentrySDK.configureScope { scope in
                    scope.setContext(value: context.attributes, key: "cli")
                }
                let breadcrumb = Breadcrumb(
                    level: .info,
                    category: SentryConfiguration.breadcrumbCategory
                )
                breadcrumb.type = "user"
                breadcrumb.message = "CLI command invoked"
                for (key, value) in context.attributes {
                    breadcrumb.setData(value: value, key: key)
                }
                SentrySDK.addBreadcrumb(breadcrumb)
                Self.logger.info(
                    "CLI command started",
                    metadata: context.logMetadata
                )
            }
        #endif

        let result = try await TypesSearchCommandRunner(
            client: Dependencies.documentationClient,
            renderer: Dependencies.documentationTypeListRenderer(json: json)
        ).run(query: query, technology: technology)
        #if canImport(SentrySwift)
            if SentrySDK.isEnabled {
                SentrySDK.metrics.distribution(
                    key: "apple_docs.type.search.result.count",
                    value: Double(result.matchCount),
                    attributes: context.metricAttributes
                )
            }
        #endif
        print(result.output)
    }
}
