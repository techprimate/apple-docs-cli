import ArgumentParser
import Logging
@preconcurrency import SentrySwift

struct TypesViewCommand: AsyncParsableCommand {
    private static let logger = Logger(
        label: "com.techprimate.apple-docs.types-view"
    )

    static let configuration = CommandConfiguration(
        commandName: "view",
        abstract: "Show documentation for a type."
    )

    @Argument(help: "The type name.")
    var name: String

    @Option(help: "The framework or technology containing the type.")
    var technology: String

    @Flag(help: "Output the raw Apple DocC JSON document.")
    var json = false

    mutating func run() async throws {
        let context = SentryCommandContext.typesView(
            name: name,
            technology: technology,
            json: json
        )
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

        let result = try await TypesViewCommandRunner(
            client: Dependencies.documentationClient,
            renderer: Dependencies.documentationRenderer(json: json)
        ).run(name: name, technology: technology)
        if SentrySDK.isEnabled {
            recordPopularityMetrics()
            SentrySDK.metrics.distribution(
                key: "apple_docs.response.size",
                value: Double(result.responseByteCount),
                unit: .byte,
                attributes: context.metricAttributes
            )
        }
        print(result.output)
    }

    private func recordPopularityMetrics() {
        SentrySDK.metrics.count(
            key: "apple_docs.technology.requested",
            attributes: ["apple_docs.technology": technology]
        )
        SentrySDK.metrics.count(
            key: "apple_docs.type.requested",
            attributes: [
                "apple_docs.technology": technology,
                "apple_docs.type": name,
            ]
        )
    }
}
