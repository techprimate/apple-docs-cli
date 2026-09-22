import Foundation
import Testing

#if canImport(Darwin)
    import Darwin
#else
    import Glibc
#endif

@Suite(
    "Release terminal browser", .serialized,
    .enabled(
        if: ProcessInfo.processInfo.environment["APPLE_DOCS_EXECUTABLE"] != nil,
        "Run with make test-integration."))
struct TerminalBrowserIntegrationTests {
    @Test(arguments: ["q", "\u{3}"])
    func restoresTerminalOnKeyboardExit(_ key: String) throws {
        // -- Arrange --
        let terminal = try TerminalPTYHarness()
        try terminal.waitFor("Documentation")

        // -- Act --
        try terminal.send(key)
        try terminal.waitForExit()

        // -- Assert --
        #expect(terminal.process.terminationStatus == 0)
        #expect(try terminal.attributesRestored())
    }

    @Test func negotiatesEnhancedKeyboardBeforeReadingKeys() throws {
        // -- Arrange --
        let terminal = try TerminalPTYHarness(enhancedKeyboard: true)
        try terminal.waitFor("Documentation")

        // -- Act --
        try terminal.send("\u{1B}[113u")
        try terminal.waitForExit()

        // -- Assert --
        #expect(terminal.output.range(of: "\u{1B}\\[>[0-9]+u", options: .regularExpression) != nil)
        #expect(terminal.process.terminationStatus == 0)
        #expect(try terminal.attributesRestored())
    }

    @Test(arguments: [SIGINT, SIGTERM])
    func restoresTerminalOnSignal(_ signal: Int32) throws {
        // -- Arrange --
        let terminal = try TerminalPTYHarness()
        try terminal.waitFor("Documentation")

        // -- Act --
        kill(terminal.process.processIdentifier, signal)
        try terminal.waitForExit()

        // -- Assert --
        #expect(terminal.process.terminationStatus == 0)
        #expect(try terminal.attributesRestored())
    }

    @Test(arguments: [true, false])
    func oneRedirectedDescriptorNeverStartsTheBrowser(_ inputIsTTY: Bool) throws {
        // -- Arrange --
        let terminal = try TerminalPTYHarness(inputIsTTY: inputIsTTY, outputIsTTY: !inputIsTTY)

        // -- Act --
        try terminal.waitFor("Declaration")
        try terminal.waitForExit()

        // -- Assert --
        #expect(terminal.output.contains("Structure · Swift"))
        #expect(!terminal.output.contains("\u{1B}[?1049h"))
        #expect(!terminal.output.contains("Navigator"))
        #expect(terminal.process.terminationStatus == 0)
        #expect(try terminal.attributesRestored())
    }

    @Test func searchTypingSubmissionAndRetainedResults() throws {
        // -- Arrange --
        let terminal = try TerminalPTYHarness(arguments: [
            "types", "view", "MXHangDiagnostic", "--technology", "MetricKit",
        ])
        try terminal.waitFor("class MXHangDiagnostic")

        // -- Act --
        try terminal.send("/")
        try terminal.waitFor("Enter submits")
        try terminal.send("q/`o[]")
        let typed = terminal.checkpoint
        try terminal.send("\u{1B}")
        try terminal.waitFor("Documentation", after: typed)
        let queryReopened = terminal.checkpoint
        try terminal.send("/")
        try terminal.waitFor("q/`o[]", after: queryReopened)
        try terminal.send(String(repeating: "\u{7F}", count: 6) + "MXHangDiagnostic\r")
        try terminal.waitFor("mxhangdiagnostic")
        try terminal.send("\t")
        try terminal.waitFor("query")
        let opened = terminal.checkpoint
        try terminal.send("\r")
        try terminal.waitFor("Documentation", after: opened)
        let reopened = terminal.checkpoint
        try terminal.send("/")
        try terminal.waitFor("mxhangdiagnostic", after: reopened)
        let closed = terminal.checkpoint
        try terminal.send("\u{1B}")
        try terminal.waitFor("Documentation", after: closed)
        try terminal.send("q")
        try terminal.waitForExit()

        // -- Assert --
        #expect(terminal.process.terminationStatus == 0)
        #expect(try terminal.attributesRestored())
    }

    @Test func crossTechnologyLinksAndHistoryRestoreTheDocument() throws {
        // -- Arrange --
        let terminal = try TerminalPTYHarness(arguments: [
            "types", "view", "MXHangDiagnostic", "--technology", "MetricKit", "--verbose",
        ])
        try terminal.waitFor("class MXHangDiagnostic")

        // -- Act --
        try terminal.send("]]]\r")
        try terminal.waitFor("protocol CVarArg")
        let back = terminal.checkpoint
        try terminal.send("\u{1B}[1;3D")
        try terminal.waitFor("MXHangDiagnostic", after: back)
        let forward = terminal.checkpoint
        try terminal.send("\u{1B}[1;3C")
        try terminal.waitFor("protocol CVarArg", after: forward)
        try terminal.send("q")
        try terminal.waitForExit()

        // -- Assert --
        #expect(!terminal.output.contains(" debug "))
        #expect(!terminal.output.contains(" warning "))
        #expect(terminal.process.terminationStatus == 0)
        #expect(try terminal.attributesRestored())
    }

    @Test func resizingAndPanelTogglesKeepTheSessionUsable() throws {
        // -- Arrange --
        let terminal = try TerminalPTYHarness()
        try terminal.waitFor("Navigator")

        // -- Act --
        try terminal.send("\u{2}")
        try terminal.resize(width: 50, height: 15)
        try terminal.send("`")
        try terminal.waitFor("Logs")
        try terminal.send("\u{1B}")
        try terminal.resize(width: 80, height: 24)
        try terminal.send("\u{2}q")
        try terminal.waitForExit()

        // -- Assert --
        #expect(terminal.process.terminationStatus == 0)
        #expect(try terminal.attributesRestored())
    }
}
