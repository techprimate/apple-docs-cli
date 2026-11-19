#if os(Linux)
    import Foundation
    import NativeTelemetryPrivacy
    import SentryNative

    enum NativeSentryConfiguration {
        static func makeOptions(environment: [String: String]) -> OpaquePointer? {
            guard let options = sentry_options_new() else { return nil }
            sentry_options_set_dsn(options, SentryConfiguration.dsn)
            sentry_options_set_environment(options, BuildMetadata.environment)
            sentry_options_set_release(options, BuildMetadata.sentryRelease)
            sentry_options_set_debug(options, 0)
            if let certificates = certificateBundle(environment: environment) {
                sentry_options_set_ca_certs(options, certificates)
            }
            sentry_options_set_auto_session_tracking(options, 0)
            sentry_options_set_traces_sample_rate(options, 1.0)
            sentry_options_set_max_breadcrumbs(options, 10)
            sentry_options_set_shutdown_timeout(options, 2_000)
            sentry_options_set_database_path(options, cacheDirectory(environment: environment).path)
            apple_docs_configure_privacy(options)
            return options
        }

        private static func certificateBundle(environment: [String: String]) -> String? {
            if let path = environment["SSL_CERT_FILE"] {
                return path
            }
            // The static SDK's compiled-in TLS paths need not match the host distribution.
            return [
                "/etc/ssl/certs/ca-certificates.crt",
                "/etc/pki/tls/certs/ca-bundle.crt",
                "/etc/ssl/cert.pem",
            ].first { FileManager.default.isReadableFile(atPath: $0) }
        }

        static func cacheDirectory(environment: [String: String]) -> URL {
            let base: URL
            if let path = environment["XDG_CACHE_HOME"], path.hasPrefix("/") {
                base = URL(fileURLWithPath: path, isDirectory: true)
            } else {
                base = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".cache")
            }
            return base.appendingPathComponent("apple-docs/sentry", isDirectory: true)
        }
    }
#endif
