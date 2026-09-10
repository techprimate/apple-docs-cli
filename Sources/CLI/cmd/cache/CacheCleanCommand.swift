import ArgumentParser
import Logging

#if canImport(SentrySwift)
    @preconcurrency import SentrySwift
#endif

struct CacheCleanCommand: ParsableCommand {
    private static let logger = Logger(
        label: "com.techprimate.apple-docs.cache-clean"
    )

    static let configuration = CommandConfiguration(
        commandName: "clean",
        abstract: "Clear cached Apple documentation."
    )

    mutating func run() throws {
        #if canImport(SentrySwift)
            if SentrySDK.isEnabled {
                let context = SentryCommandContext.cacheClean
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

        let result = CacheCleanCommandRunner(
            cache: Dependencies.documentationCache
        ).run()
        print(result.output)
    }
}
