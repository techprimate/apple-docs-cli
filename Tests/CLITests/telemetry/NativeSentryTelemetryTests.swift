#if os(Linux)
    import ArgumentParser
    import Foundation
    import Logging
    import SentryNative
    import Synchronization
    import Testing

    @testable import CLI

    @Suite("Native Sentry telemetry", .serialized)
    struct NativeSentryTelemetryTests {
        @Test("configures system CA certificates and honors an explicit trust bundle")
        func configuresCertificateTrust() throws {
            // -- Arrange --
            let options = try #require(NativeSentryConfiguration.makeOptions(environment: [:]))
            defer { sentry_options_free(options) }
            let certificatePath = try #require(sentry_options_get_ca_certs(options))
            let path = String(cString: certificatePath)
            let overrideURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.copyItem(at: URL(fileURLWithPath: path), to: overrideURL)
            defer { try? FileManager.default.removeItem(at: overrideURL) }

            // -- Act --
            let overridden = try #require(
                NativeSentryConfiguration.makeOptions(environment: [
                    "SSL_CERT_FILE": overrideURL.path
                ]))
            defer { sentry_options_free(overridden) }
            let overridePath = try #require(sentry_options_get_ca_certs(overridden))

            // -- Assert --
            #expect(FileManager.default.isReadableFile(atPath: path))
            #expect(String(cString: overridePath) == overrideURL.path)
        }

        @Test("captures a command transaction, logs and all metric kinds")
        func capturesCommand() throws {
            // -- Arrange --
            let sdk = try NativeTestSDK()
            defer { sdk.close() }
            let telemetry = sdk.telemetry()
            let context = TelemetryCommandContext.typesView(name: "String", technology: "Swift", json: true)

            // -- Act --
            telemetry.startCommand(context)
            telemetry.record(.technologyCatalog(count: 10), context: context)
            telemetry.record(.typeCatalog(count: 20), context: context)
            telemetry.record(.typeSearch(matches: 3), context: context)
            telemetry.record(.typeView(responseBytes: 100), context: context)
            telemetry.finishCommand(error: nil)

            // -- Assert --
            let transaction = try #require(sdk.payloads(for: "transaction").first)
            #expect(transaction["transaction"] as? String == "apple-docs types.view")
            let contexts = try #require(transaction["contexts"] as? [String: [String: Any]])
            #expect(contexts["trace"]?["status"] as? String == "ok")
            let metrics = try sdk.items(for: "trace_metric")
            #expect(
                Set(metrics.compactMap { $0["name"] as? String }) == [
                    "apple_docs.technology.catalog.count", "apple_docs.type.catalog.count",
                    "apple_docs.type.search.result.count", "apple_docs.response.size",
                    "apple_docs.technology.requested", "apple_docs.type.requested",
                ])
            #expect(
                try sdk.items(for: "log").compactMap { $0["body"] as? String } == [
                    "CLI command started", "CLI command completed",
                ])
            #expect(try sdk.payloads(for: "event").isEmpty)
        }

        @Test("captures unexpected errors with a generic message and native stack frames")
        func capturesUnexpectedError() throws {
            // -- Arrange --
            let sdk = try NativeTestSDK()
            defer { sdk.close() }
            let telemetry = sdk.telemetry()

            // -- Act --
            telemetry.startCommand(.cacheClean)
            telemetry.finishCommand(error: NSError(domain: "private-token", code: 1))

            // -- Assert --
            let event = try #require(sdk.payloads(for: "event").first)
            let exception = try #require(event["exception"] as? [String: [[String: Any]]])
            let failure = try #require(exception["values"]?.first)
            #expect(failure["value"] as? String == "CLI command failed")
            let stack = try #require(failure["stacktrace"] as? [String: Any])
            #expect(!(stack["frames"] as? [[String: Any]] ?? []).isEmpty)
            #expect(try !sdk.serialized.contains("private-token"))
        }

        @Test("does not capture expected command errors")
        func ignoresExpectedErrors() throws {
            // -- Arrange --
            let sdk = try NativeTestSDK()
            defer { sdk.close() }
            let telemetry = sdk.telemetry()

            // -- Act --
            telemetry.startCommand(.cacheClean)
            telemetry.finishCommand(error: ValidationError("private-token"))

            // -- Assert --
            #expect(try sdk.payloads(for: "event").isEmpty)
            #expect(try sdk.items(for: "log").last?["body"] as? String == "CLI command rejected")
            #expect(try !sdk.serialized.contains("private-token"))
        }

        @Test("treats documentation lookup misses as expected errors")
        func ignoresLookupMisses() throws {
            // -- Arrange --
            let sdk = try NativeTestSDK()
            defer { sdk.close() }
            let telemetry = sdk.telemetry()
            let error = AppleDocumentationRepositoryError.typeNotFound(
                name: "private-token", technology: "Swift", suggestion: nil,
                technologyURL: "https://developer.apple.com/documentation/swift"
            )

            // -- Act --
            telemetry.startCommand(.cacheClean)
            telemetry.finishCommand(error: error)

            // -- Assert --
            #expect(try sdk.payloads(for: "event").isEmpty)
            #expect(try !sdk.serialized.contains("private-token"))
        }

        @Test("disabled telemetry does not initialize the SDK or create its cache")
        func disablesBeforeInitialization() {
            // -- Arrange --
            let cacheURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            let telemetry = DefaultTelemetry(
                logger: { Logger(label: "test") { _ in NativeSentryLogHandler() } },
                environment: ["TELEMETRY_DISABLED": "TRUE", "XDG_CACHE_HOME": cacheURL.path]
            )

            // -- Act --
            telemetry.start()
            telemetry.startCommand(.cacheClean)
            telemetry.finishCommand(error: nil)

            // -- Assert --
            #expect(sentry_is_enabled() == 0)
            #expect(!FileManager.default.fileExists(atPath: cacheURL.path))
            #expect(telemetry.makeLogHandler() == nil)
        }

        @Test("scrubs events and transaction metadata before the transport receives them")
        func scrubsPrivateData() throws {
            // -- Arrange --
            let sdk = try NativeTestSDK()
            defer { sdk.close() }
            let eventJSON = """
                {"user":{"id":"private-token"},"request":{"url":"private-token"},
                 "server_name":"private-token","extra":{"raw":"private-token"},
                 "tags":{"raw":"private-token"},"message":"private-token",
                 "contexts":{"device":{"name":"private-token"},"cli":{"raw":"private-token"}},
                 "debug_meta":{"images":[{"code_file":"/private-token/apple-docs"}]},
                 "exception":{"values":[{"type":"ExampleError","value":"private-token",
                   "stacktrace":{"frames":[{"package":"/private-token/apple-docs"}]}}]},
                 "breadcrumbs":[{"category":"network","message":"private-token"},
                   {"category":"cli.command","message":"private-token","data":{"raw":"private-token"}}]}
                """
            let telemetry = sdk.telemetry()
            sentry_set_user(nativeJSON("{\"id\":\"private-token\"}"))
            sentry_set_extra("raw", sentry_value_new_string("private-token"))

            // -- Act --
            _ = sentry_capture_event(nativeJSON(eventJSON))
            telemetry.startCommand(.cacheClean)
            telemetry.finishCommand(error: nil)

            // -- Assert --
            #expect(try sdk.payloads(for: "event").count == 1)
            #expect(try sdk.payloads(for: "transaction").count == 1)
            #expect(try !sdk.serialized.contains("private-token"))
        }

        @Test("removes unapproved metric attributes")
        func filtersMetricAttributes() throws {
            // -- Arrange --
            let sdk = try NativeTestSDK()
            defer { sdk.close() }
            let attributes = nativeJSON(
                """
                {"raw":{"value":"private-token","type":"string"},
                 "apple_docs.type":{"value":"String","type":"string"}}
                """)

            // -- Act --
            _ = sentry_metrics_count("apple_docs.type.requested", 1, attributes)
            _ = sentry_flush(2_000)

            // -- Assert --
            let metric = try #require(sdk.items(for: "trace_metric").first)
            let captured = try #require(metric["attributes"] as? [String: Any])
            #expect(captured["apple_docs.type"] != nil)
            #expect(try !sdk.serialized.contains("private-token"))
        }

        @Test("filters unapproved logs, metrics and log metadata")
        func filtersSignals() throws {
            // -- Arrange --
            let sdk = try NativeTestSDK()
            defer { sdk.close() }
            let logger = Logger(label: "test") { _ in NativeSentryLogHandler() }

            // -- Act --
            logger.info("private-token")
            logger.info(
                "CLI command started",
                metadata: ["raw": "private-token", "source": "private-token", "cli.command": "cache.clean"]
            )
            _ = sentry_metrics_count("private-token", 1, sentry_value_new_null())
            _ = sentry_flush(2_000)

            // -- Assert --
            #expect(try sdk.items(for: "log").compactMap { $0["body"] as? String } == ["CLI command started"])
            #expect(try sdk.items(for: "trace_metric").isEmpty)
            #expect(try !sdk.serialized.contains("private-token"))
        }
    }

    private func nativeJSON(_ json: String) -> sentry_value_t {
        json.withCString { sentry_value_from_json($0, json.utf8.count) }
    }

    private final class NativeTestSDK: Sendable {
        private let envelopes = Mutex<[Data]>([])
        private let cacheURL: URL

        init() throws {
            cacheURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            let options = try #require(
                NativeSentryConfiguration.makeOptions(environment: [
                    "XDG_CACHE_HOME": cacheURL.path
                ]))
            let transport = sentry_transport_new { envelope, state in
                defer { sentry_envelope_free(envelope) }
                guard let state else { return }
                let recorder = Unmanaged<NativeTestSDK>.fromOpaque(state).takeUnretainedValue()
                var count = 0
                guard let bytes = sentry_envelope_serialize(envelope, &count) else { return }
                defer { sentry_free(bytes) }
                recorder.envelopes.withLock { $0.append(Data(bytes: bytes, count: count)) }
            }
            sentry_transport_set_state(transport, Unmanaged.passUnretained(self).toOpaque())
            sentry_options_set_transport(options, transport)
            #expect(sentry_init(options) == 0)
        }

        func telemetry() -> DefaultTelemetry {
            DefaultTelemetry(
                logger: { Logger(label: "test") { _ in NativeSentryLogHandler() } },
                environment: [:]
            )
        }

        func close() {
            _ = sentry_close()
            try? FileManager.default.removeItem(at: cacheURL)
        }

        var serialized: String {
            get throws {
                try envelopes.withLock { data in
                    try data.map { try #require(String(data: $0, encoding: .utf8)) }.joined()
                }
            }
        }

        func payloads(for type: String) throws -> [[String: Any]] {
            try envelopes.withLock { envelopes in
                try envelopes.flatMap { envelope in
                    let lines = envelope.split(separator: 10)
                    return try stride(from: 1, to: lines.count - 1, by: 2).compactMap { index -> [String: Any]? in
                        let header = try JSONSerialization.jsonObject(with: Data(lines[index])) as? [String: Any]
                        guard header?["type"] as? String == type else { return nil }
                        return try JSONSerialization.jsonObject(with: Data(lines[index + 1])) as? [String: Any]
                    }
                }
            }
        }

        func items(for type: String) throws -> [[String: Any]] {
            try payloads(for: type).flatMap { $0["items"] as? [[String: Any]] ?? [] }
        }
    }
#endif
