import ArgumentParser
import Logging

#if canImport(SentrySwift)
    @preconcurrency import SentrySwift
#endif

struct TypesListCommand: AsyncParsableCommand {
    private static let logger = Logger(
        label: "com.techprimate.apple-docs.types-list"
    )

    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List types in an Apple documentation technology."
    )

    @Option(help: "The framework or technology whose types to list.")
    var technology: String

    @Flag(help: "Output a JSON array of types.")
    var json = false

    mutating func run() async throws {
        let context = SentryCommandContext.typesList(
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

        let result = try await TypesListCommandRunner(
            client: Dependencies.documentationClient,
            renderer: Dependencies.documentationTypeListRenderer(json: json)
        ).run(technology: technology)
        #if canImport(SentrySwift)
            if SentrySDK.isEnabled {
                SentrySDK.metrics.gauge(
                    key: "apple_docs.type.catalog.count",
                    value: Double(result.typeCount),
                    attributes: context.metricAttributes
                )
            }
        #endif
        print(result.output)
    }
}
