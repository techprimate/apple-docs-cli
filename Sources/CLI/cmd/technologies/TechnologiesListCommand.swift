import ArgumentParser
import Logging
@preconcurrency import SentrySwift

struct TechnologiesListCommand: AsyncParsableCommand {
    private static let logger = Logger(
        label: "com.techprimate.apple-docs.technologies-list"
    )

    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List Apple documentation technologies."
    )

    @Flag(help: "Output a JSON array of technologies.")
    var json = false

    mutating func run() async throws {
        let context = SentryCommandContext.technologiesList(json: json)
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

        let result = try await TechnologiesListCommandRunner(
            client: Dependencies.documentationClient,
            renderer: Dependencies.technologyListRenderer(json: json)
        ).run()
        if SentrySDK.isEnabled {
            SentrySDK.metrics.gauge(
                key: "apple_docs.technology.catalog.count",
                value: Double(result.technologyCount),
                attributes: context.metricAttributes
            )
        }
        print(result.output)
    }
}
