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
