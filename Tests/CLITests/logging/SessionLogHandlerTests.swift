import Logging
import Testing

@testable import CLI

@Suite("Session log handler")
struct SessionLogHandlerTests {
    @Test(
        "captures warnings by default and debug logs when verbose without requiring a visible panel",
        arguments: [false, true])
    func capturesConfiguredLevels(verbose: Bool) {
        // -- Arrange --
        let buffer = SessionLogBuffer()
        let logger = Logger(label: "test.session") { label in
            var handler = SessionLogHandler(buffer: buffer, label: label)
            if verbose { handler.logLevel = .debug }
            return handler
        }

        // -- Act --
        for level in [Logger.Level.trace, .debug, .info, .notice, .warning, .error, .critical] {
            logger.log(level: level, "Event", metadata: ["request": "safe"])
        }

        // -- Assert --
        let expected: [Logger.Level] =
            verbose ? [.debug, .info, .notice, .warning, .error, .critical] : [.warning, .error, .critical]
        #expect(buffer.snapshot().map(\.level) == expected)
        #expect(buffer.snapshot().allSatisfy { $0.label == "test.session" && $0.metadata["request"] == "safe" })
    }

    @Test("metadata merges handler, provider, and event values in increasing precedence")
    func mergesMetadata() {
        // -- Arrange --
        let buffer = SessionLogBuffer()
        let logger = Logger(label: "test.session") { label in
            var handler = SessionLogHandler(buffer: buffer, label: label)
            handler.metadata = ["base": "kept", "scope": "handler"]
            handler.metadataProvider = Logger.MetadataProvider { ["provider": "kept", "scope": "provider"] }
            return handler
        }

        // -- Act --
        logger.warning("Failure", metadata: ["scope": "event"])

        // -- Assert --
        #expect(buffer.snapshot().first?.metadata == ["base": "kept", "provider": "kept", "scope": "event"])
        #expect(buffer.snapshot().count == 1)
    }

    @Test("logger copies retain value-semantic metadata and levels while sharing the buffer")
    func keepsLoggerValueSemantics() {
        // -- Arrange --
        let buffer = SessionLogBuffer()
        var original = Logger(label: "test.session") { label in SessionLogHandler(buffer: buffer, label: label) }
        original[metadataKey: "scope"] = "original"
        var copy = original
        copy[metadataKey: "scope"] = "copy"
        copy.logLevel = .debug

        // -- Act --
        original.debug("Ignored")
        original.warning("Original")
        copy.debug("Copy")

        // -- Assert --
        let entries = buffer.snapshot()
        #expect(entries.map(\.message) == ["Original", "Copy"])
        #expect(entries.map { $0.metadata["scope"] } == ["original", "copy"])
        #expect(entries.map(\.id) == [1, 2])
        #expect(buffer.snapshot().count == 2)
    }

    @Test("does not expand error payloads into new log metadata")
    func capturesOnlyExplicitContent() {
        // -- Arrange --
        struct PayloadError: Error, CustomStringConvertible { let description = "Private error payload" }
        let buffer = SessionLogBuffer()
        let handler = SessionLogHandler(buffer: buffer, label: "test.session")
        let event = LogEvent(
            level: .error, message: "Request failed", error: PayloadError(), metadata: ["request": "safe"],
            source: "test", file: #fileID, function: #function, line: #line)

        // -- Act --
        handler.log(event: event)

        // -- Assert --
        #expect(buffer.snapshot().first?.message == "Request failed")
        #expect(buffer.snapshot().first?.metadata == ["request": "safe"])
    }
}
