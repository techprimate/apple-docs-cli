import Foundation

#if canImport(SentrySwift)
    @preconcurrency import SentrySwift
#endif

protocol ExpectedCommandError: Error {
    var isExpected: Bool { get }
}

#if canImport(SentrySwift)
    struct SentryConfiguration {
        private static let allowedBreadcrumbDataKeys: Set<String> = [
            "apple_docs.technology",
            "apple_docs.type",
            "cli.command",
            "cli.output_json",
        ]
        private static let allowedContextKeys: Set<String> = [
            "cli",
            "os",
            "runtime",
            "trace",
        ]
        private static let allowedLogAttributes: Set<String> = [
            "environment",
            "release",
            "sentry.origin",
            "sentry.sdk.name",
            "sentry.sdk.version",
            "swift-log.apple_docs.technology",
            "swift-log.apple_docs.type",
            "swift-log.cli.command",
            "swift-log.cli.output_json",
            "swift-log.level",
            "swift-log.source",
        ]
        private static let allowedLogBodies: Set<String> = [
            "CLI command completed",
            "CLI command failed",
            "CLI command rejected",
            "CLI command started",
        ]
        private static let allowedMetricAttributes: Set<String> = [
            "apple_docs.technology",
            "apple_docs.type",
            "cli.command",
            "environment",
            "release",
        ]
        private static let allowedMetricNames: Set<String> = [
            "apple_docs.response.size",
            "apple_docs.technology.catalog.count",
            "apple_docs.type.catalog.count",
            "apple_docs.type.search.result.count",
            "apple_docs.technology.requested",
            "apple_docs.type.requested",
        ]
        static let breadcrumbCategory = "cli.command"
        static let dsn =
            "https://927b98fc26175a0d5dda2124b9b471dd@o188824.ingest.us.sentry.io/4512051116376064"

        static func isEnabled(environment: [String: String]) -> Bool {
            environment["TELEMETRY_DISABLED"]?.caseInsensitiveCompare("true") != .orderedSame
        }

        static func isExpected(error: Swift.Error) -> Bool {
            (error as? any ExpectedCommandError)?.isExpected == true
        }

        static func configure(_ options: Options) {
            options.dsn = dsn
            options.environment = BuildMetadata.environment
            options.releaseName = BuildMetadata.sentryRelease
            options.debug = false
            configureErrorMonitoring(options)
            configureTracing(options)
            configureBreadcrumbs(options)
            configureSignals(options)
            configureFilters(options)
        }

        private static func configureErrorMonitoring(_ options: Options) {
            options.sendDefaultPii = false
            options.attachStacktrace = true
            options.enableCrashHandler = true
            options.enableAppHangTracking = false
            options.enableMemoryIntrospection = false
        }

        private static func configureTracing(_ options: Options) {
            options.tracesSampleRate = 1.0
            options.enableAutoPerformanceTracing = false
            options.enableNetworkTracking = false
            options.enableFileIOTracing = false
            options.enableCoreDataTracing = false
            options.enableSwizzling = false
            options.tracePropagationTargets = []
        }

        private static func configureBreadcrumbs(_ options: Options) {
            options.enableAutoBreadcrumbTracking = false
            options.enableNetworkBreadcrumbs = false
            options.enableCaptureFailedRequests = false
            options.maxBreadcrumbs = 10
            options.beforeBreadcrumb = { breadcrumb in
                guard breadcrumb.category == breadcrumbCategory else {
                    return nil
                }
                breadcrumb.message = "CLI command invoked"
                breadcrumb.type = "user"
                if let data = breadcrumb.data {
                    for key in data.keys where !allowedBreadcrumbDataKeys.contains(key) {
                        breadcrumb.setData(value: nil, key: key)
                    }
                }
                return breadcrumb
            }
        }

        private static func configureSignals(_ options: Options) {
            options.enableLogs = true
            options.enableMetrics = true
        }

        private static func configureFilters(_ options: Options) {
            options.beforeSend = { event in
                event.user = nil
                event.request = nil
                event.serverName = nil
                event.extra = nil
                event.tags = nil
                event.message = nil
                event.error = nil
                event.context = event.context?.filter {
                    allowedContextKeys.contains($0.key)
                }
                event.breadcrumbs = event.breadcrumbs?.filter {
                    $0.category == breadcrumbCategory
                }
                for exception in event.exceptions ?? [] {
                    exception.value = "CLI command failed"
                }
                sanitizePaths(in: event)
                return event
            }
            options.beforeSendSpan = { span in
                span.operation == "console.command" ? span : nil
            }
            options.beforeSendLog = { log in
                guard allowedLogBodies.contains(log.body) else {
                    return nil
                }
                log.attributes = log.attributes.filter {
                    allowedLogAttributes.contains($0.key)
                }
                return log
            }
            options.beforeSendMetric = { metric in
                guard allowedMetricNames.contains(metric.name) else {
                    return nil
                }
                var metric = metric
                metric.attributes = metric.attributes.filter {
                    allowedMetricAttributes.contains($0.key)
                }
                return metric
            }
        }

        private static func sanitizePaths(in event: Event) {
            for debugImage in event.debugMeta ?? [] {
                debugImage.codeFile = fileName(from: debugImage.codeFile)
            }
            for exception in event.exceptions ?? [] {
                sanitizePaths(in: exception.stacktrace)
            }
            for thread in event.threads ?? [] {
                sanitizePaths(in: thread.stacktrace)
            }
        }

        private static func sanitizePaths(in stacktrace: SentryStacktrace?) {
            for frame in stacktrace?.frames ?? [] {
                frame.package = fileName(from: frame.package)
            }
        }

        private static func fileName(from path: String?) -> String? {
            path.map { URL(fileURLWithPath: $0).lastPathComponent }
        }
    }
#endif
