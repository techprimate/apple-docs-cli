import Foundation
import Testing

@testable import CLI

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

#if canImport(SentrySwift)
    @preconcurrency import SentrySwift

    @Suite("Sentry configuration")
    struct SentryConfigurationTests {
        @Test("reports Swift decoding failures without response values or underlying errors")
        func reportsDecodingFailure() throws {
            // -- Arrange --
            let options = Options()
            SentryConfiguration.configure(options)
            let data = Data(#"{"metadata":{"title":"Article"}}"#.utf8)
            struct Page: Decodable {
                struct Metadata: Decodable { let symbolKind: String }
                let metadata: Metadata
            }
            let error: any Error
            do {
                _ = try JSONDecoder().decode(Page.self, from: data)
                Issue.record("Expected missing symbolKind")
                return
            } catch let decodingError {
                error = decodingError
            }

            // -- Act --
            let event = SentryConfiguration.errorEvent(for: error)
            let filtered = try #require(options.beforeSend?(event))
            let exception = try #require(filtered.exceptions?.first)

            // -- Assert --
            #expect(exception.type == "Swift.DecodingError.keyNotFound")
            #expect(exception.value == "Missing required key at metadata.symbolKind")
            #expect(exception.mechanism?.data == nil)
            #expect(exception.mechanism?.desc == nil)
        }

        @Test(
            "reports decoding categories and paths without payload values",
            arguments: [
                (#"["secret"]"#, "Swift.DecodingError.typeMismatch", "Expected Swift.Int at [0]"),
                ("[null]", "Swift.DecodingError.valueNotFound", "Missing Swift.Int value at [0]"),
                ("secret", "Swift.DecodingError.dataCorrupted", "Invalid documentation data at <root>"),
            ])
        func reportsDecodingCategories(json: String, type: String, message: String) throws {
            // -- Arrange --
            let options = Options()
            SentryConfiguration.configure(options)
            let error: any Error
            do {
                _ = try JSONDecoder().decode([Int].self, from: Data(json.utf8))
                Issue.record("Expected invalid integer array")
                return
            } catch let decodingError {
                error = decodingError
            }

            // -- Act --
            let filtered = try #require(options.beforeSend?(SentryConfiguration.errorEvent(for: error)))
            let exception = try #require(filtered.exceptions?.first)

            // -- Assert --
            #expect(exception.type == type)
            #expect(exception.value == message)
            #expect(!String(describing: filtered.serialize()).contains("secret"))
        }

        @Test("scrubs SDK exception details that can contain arbitrary error data")
        func scrubsSDKExceptionDetails() throws {
            // -- Arrange --
            let options = Options()
            SentryConfiguration.configure(options)
            let event = Event(level: .error)
            let exception = Exception(value: "secret", type: "NSCocoaErrorDomain")
            let mechanism = Mechanism(type: "NSError")
            mechanism.desc = "secret"
            mechanism.data = ["response": "secret"]
            exception.mechanism = mechanism
            event.exceptions = [exception]

            // -- Act --
            let filtered = try #require(options.beforeSend?(event))

            // -- Assert --
            #expect(filtered.exceptions?.first?.value == "CLI command failed")
            #expect(!String(describing: filtered.serialize()).contains("secret"))
        }

        @Test("does not send arbitrary error descriptions")
        func redactsErrorDescription() throws {
            // -- Arrange --
            let error = NSError(domain: "Example", code: 42, userInfo: [NSLocalizedDescriptionKey: "secret"])
            let options = Options()
            SentryConfiguration.configure(options)

            // -- Act --
            let event = SentryConfiguration.errorEvent(for: error)
            let filtered = try #require(options.beforeSend?(event))
            let exception = try #require(filtered.exceptions?.first)

            // -- Assert --
            #expect(exception.type == String(reflecting: type(of: error)))
            #expect(exception.value == "Command failed (code: 42)")
            #expect(!String(describing: filtered.serialize()).contains("secret"))
        }

        @Test("enables telemetry by default")
        func enablesTelemetryByDefault() {
            // -- Arrange --
            let environment: [String: String] = [:]

            // -- Act --
            let enabled = SentryConfiguration.isEnabled(environment: environment)

            // -- Assert --
            #expect(enabled)
        }

        @Test(
            "disables telemetry for a true environmental flag",
            arguments: ["true", "TRUE", "True"]
        )
        func disablesTelemetry(value: String) {
            // -- Arrange --
            let environment = ["TELEMETRY_DISABLED": value]

            // -- Act --
            let enabled = SentryConfiguration.isEnabled(environment: environment)

            // -- Assert --
            #expect(!enabled)
        }

        @Test("marks CLI executable frames as in-app")
        func marksCLIExecutableFramesAsInApp() {
            // -- Arrange --
            let options = Options()

            // -- Act --
            SentryConfiguration.configure(options)

            // -- Assert --
            #expect(options.inAppIncludes.contains("apple-docs"))
        }

        @Test("treats documentation lookup failures as expected command errors")
        func treatsLookupFailureAsExpected() {
            // -- Arrange --
            let error = AppleDocumentationRepositoryError.typeNotFound(
                name: "Model",
                technology: "SwiftData",
                suggestion: nil,
                technologyURL: "https://developer.apple.com/documentation/swiftdata"
            )

            // -- Act --
            let expected = SentryConfiguration.isExpected(error: error)

            // -- Assert --
            #expect(expected)
        }

        @Test("keeps telemetry enabled for other environmental flag values")
        func ignoresOtherFlagValues() {
            // -- Arrange --
            let environment = ["TELEMETRY_DISABLED": "false"]

            // -- Act --
            let enabled = SentryConfiguration.isEnabled(environment: environment)

            // -- Assert --
            #expect(enabled)
        }
    }
#endif
