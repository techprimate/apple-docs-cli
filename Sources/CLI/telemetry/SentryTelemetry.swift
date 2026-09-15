#if canImport(SentrySwift)
    import ArgumentParser
    import Logging
    @preconcurrency import SentrySwift
    import SentrySwiftLog

    struct SentryTelemetry: Sendable {
        private let enabled: Bool
        private let makeLogger: @Sendable () -> Logger

        init(logger: @escaping @Sendable () -> Logger, environment: [String: String]) {
            makeLogger = logger
            enabled = SentryConfiguration.isEnabled(environment: environment)
        }

        func start() {
            guard enabled else { return }
            SentrySDK.start { options in
                SentryConfiguration.configure(options)
            }
        }

        func makeLogHandler() -> (any LogHandler)? {
            guard enabled, SentrySDK.isEnabled else { return nil }
            return SentryLogHandler(logLevel: .info)
        }

        func startCommand(_ context: TelemetryCommandContext) {
            guard enabled, SentrySDK.isEnabled else { return }
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
            let breadcrumb = Breadcrumb(level: .info, category: SentryConfiguration.breadcrumbCategory)
            breadcrumb.type = "user"
            breadcrumb.message = "CLI command invoked"
            for (key, value) in context.attributes {
                breadcrumb.setData(value: value, key: key)
            }
            SentrySDK.addBreadcrumb(breadcrumb)
            makeLogger().info("CLI command started", metadata: context.logMetadata)
        }

        func record(_ metric: TelemetryMetric, context: TelemetryCommandContext) {
            guard enabled, SentrySDK.isEnabled else { return }
            let attributes = context.metricAttributes.mapValues { $0 as any SentryAttributeValue }
            switch metric {
            case .technologyCatalog(let count):
                SentrySDK.metrics.gauge(
                    key: "apple_docs.technology.catalog.count", value: Double(count), attributes: attributes
                )
            case .typeCatalog(let count):
                SentrySDK.metrics.gauge(
                    key: "apple_docs.type.catalog.count", value: Double(count), attributes: attributes
                )
            case .typeSearch(let matches):
                SentrySDK.metrics.distribution(
                    key: "apple_docs.type.search.result.count", value: Double(matches), attributes: attributes
                )
            case .typeView(let responseBytes):
                recordPopularity(context)
                SentrySDK.metrics.distribution(
                    key: "apple_docs.response.size", value: Double(responseBytes), unit: .byte, attributes: attributes
                )
            }
        }

        func finishCommand(error: (any Error)?) {
            guard enabled, SentrySDK.isEnabled else { return }
            let logger = makeLogger()
            if let error {
                if let span = SentrySDK.span {
                    // Lookup misses are actionable CLI outcomes, not application reliability failures.
                    let expected = error is ValidationError || SentryConfiguration.isExpected(error: error)
                    span.status = expected ? .invalidArgument : .internalError
                    if expected {
                        logger.info("CLI command rejected")
                    } else {
                        logger.error("CLI command failed")
                        SentrySDK.capture(error: error)
                    }
                    span.finish()
                }
            } else {
                SentrySDK.span?.status = .ok
                logger.info("CLI command completed")
                SentrySDK.span?.finish()
            }
            SentrySDK.flush(timeout: 2)
        }

        private func recordPopularity(_ context: TelemetryCommandContext) {
            if let technology = context.technology {
                SentrySDK.metrics.count(
                    key: "apple_docs.technology.requested",
                    attributes: ["apple_docs.technology": technology]
                )
                if let name = context.typeName {
                    SentrySDK.metrics.count(
                        key: "apple_docs.type.requested",
                        attributes: ["apple_docs.technology": technology, "apple_docs.type": name]
                    )
                }
            }
        }
    }
#endif
