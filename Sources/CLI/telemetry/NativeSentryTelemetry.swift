#if os(Linux)
    import ArgumentParser
    import Logging
    import SentryNative
    import Synchronization

    final class NativeSentryTelemetry: Sendable {
        // Native transaction ownership is transferred only while holding the mutex.
        private struct CommandState: @unchecked Sendable {
            var transaction: OpaquePointer?
        }

        private let command = Mutex(CommandState())
        private let enabled: Bool
        private let environment: [String: String]
        private let makeLogger: @Sendable () -> Logger

        init(logger: @escaping @Sendable () -> Logger, environment: [String: String]) {
            makeLogger = logger
            self.environment = environment
            enabled = SentryConfiguration.isEnabled(environment: environment)
        }

        func start() {
            guard enabled, let options = NativeSentryConfiguration.makeOptions(environment: environment) else { return }
            _ = sentry_init(options)
        }

        func makeLogHandler() -> (any LogHandler)? {
            guard enabled, sentry_is_enabled() != 0 else { return nil }
            return NativeSentryLogHandler()
        }

        func startCommand(_ context: TelemetryCommandContext) {
            guard enabled, sentry_is_enabled() != 0 else { return }
            command.withLock { state in
                let transaction = sentry_transaction_start(
                    sentry_transaction_context_new(context.transactionName, "console.command"),
                    sentry_value_new_null()
                )
                for (key, value) in context.attributes {
                    sentry_transaction_set_data(transaction, key, NativeSentryValue.scalar(value))
                }
                sentry_set_transaction_object(transaction)
                state.transaction = transaction
            }
            sentry_set_context("cli", NativeSentryValue.object(context.attributes))
            let breadcrumb = sentry_value_new_breadcrumb("user", "CLI command invoked")
            sentry_value_set_by_key(
                breadcrumb, "category", sentry_value_new_string(SentryConfiguration.breadcrumbCategory))
            sentry_value_set_by_key(breadcrumb, "data", NativeSentryValue.object(context.attributes))
            sentry_add_breadcrumb(breadcrumb)
            makeLogger().info("CLI command started", metadata: context.logMetadata)
        }

        func record(_ metric: TelemetryMetric, context: TelemetryCommandContext) {
            guard enabled, sentry_is_enabled() != 0 else { return }
            let attributes = NativeSentryValue.attributes(context.metricAttributes)
            switch metric {
            case .technologyCatalog(let count):
                _ = sentry_metrics_gauge("apple_docs.technology.catalog.count", Double(count), nil, attributes)
            case .typeCatalog(let count):
                _ = sentry_metrics_gauge("apple_docs.type.catalog.count", Double(count), nil, attributes)
            case .typeSearch(let matches):
                _ = sentry_metrics_distribution("apple_docs.type.search.result.count", Double(matches), nil, attributes)
            case .typeView(let responseBytes):
                recordPopularity(context)
                _ = sentry_metrics_distribution("apple_docs.response.size", Double(responseBytes), "byte", attributes)
            }
        }

        func finishCommand(error: (any Error)?) {
            guard enabled, sentry_is_enabled() != 0 else { return }
            let expected = error is ValidationError || error.map(SentryConfiguration.isExpected) == true
            let logger = makeLogger()
            if let error {
                if expected {
                    logger.info("CLI command rejected")
                } else {
                    logger.error("CLI command failed")
                    capture(error)
                }
            } else {
                logger.info("CLI command completed")
            }
            command.withLock { state in
                if let transaction = state.transaction {
                    let status =
                        error == nil
                        ? SENTRY_SPAN_STATUS_OK
                        : expected ? SENTRY_SPAN_STATUS_INVALID_ARGUMENT : SENTRY_SPAN_STATUS_INTERNAL_ERROR
                    sentry_transaction_set_status(transaction, status)
                    _ = sentry_transaction_finish(transaction)
                    state.transaction = nil
                }
            }
            // Closing flushes logs, metrics and the transport using the configured shutdown timeout.
            _ = sentry_close()
        }

        private func capture(_ error: any Error) {
            let event = sentry_value_new_event()
            let exception = sentry_value_new_exception(String(reflecting: type(of: error)), "CLI command failed")
            sentry_value_set_by_key(exception, "stacktrace", sentry_value_new_stacktrace(nil, 0))
            sentry_event_add_exception(event, exception)
            _ = sentry_capture_event(event)
        }

        private func recordPopularity(_ context: TelemetryCommandContext) {
            guard let technology = context.technology else { return }
            _ = sentry_metrics_count(
                "apple_docs.technology.requested", 1,
                NativeSentryValue.attributes(["apple_docs.technology": technology])
            )
            if let name = context.typeName {
                _ = sentry_metrics_count(
                    "apple_docs.type.requested", 1,
                    NativeSentryValue.attributes(["apple_docs.technology": technology, "apple_docs.type": name])
                )
            }
        }
    }
#endif
