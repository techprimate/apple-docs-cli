import Testing

@testable import CLI

@Suite("Documentation command output selection")
struct DocumentationCommandParsingTests {
    static let commands = [
        ["types", "view", "String", "--technology", "Swift"],
        ["types", "list", "--technology", "Swift"],
        ["types", "search", "String", "--technology", "Swift"],
        ["technologies", "list"],
    ]

    @Test(
        arguments: commands,
        [
            ["--agent"], ["--agent", "--json"], ["--json", "--agent"],
            ["--agent", "--non-interactive"], ["--json", "--non-interactive"],
        ])
    func flagsAreIndependent(arguments: [String], flags: [String]) throws {
        // -- Arrange --
        let capabilities = TerminalCapabilities(stdinIsTTY: true, stdoutIsTTY: true)

        // -- Act --
        let command = try CLI.parseAsRoot(arguments + flags)
        let options = try #require(command as? any OutputOptionsProviding).output

        // -- Assert --
        #expect(options.agent == flags.contains("--agent"))
        #expect(options.json == flags.contains("--json"))
        #expect(
            capabilities.mode(for: command)
                == .oneShot(
                    audience: flags.contains("--agent") ? .agent : .human,
                    format: flags.contains("--json") ? .json : .text))
    }

    @Test(
        arguments: commands,
        [
            TerminalCapabilities(stdinIsTTY: true, stdoutIsTTY: true),
            TerminalCapabilities(stdinIsTTY: false, stdoutIsTTY: true),
            TerminalCapabilities(stdinIsTTY: true, stdoutIsTTY: false),
        ])
    func automaticMode(arguments: [String], capabilities: TerminalCapabilities) throws {
        // -- Arrange --
        let expected: OutputMode =
            capabilities.stdinIsTTY && capabilities.stdoutIsTTY
            ? .interactive : .oneShot(audience: .human, format: .text)

        // -- Act --
        let command = try CLI.parseAsRoot(arguments)

        // -- Assert --
        #expect(capabilities.mode(for: command) == expected)
    }

    @Test(arguments: [["agent", "skills", "list"], ["cache", "clean"]])
    func otherCommandsHaveNoDocumentationMode(arguments: [String]) throws {
        // -- Arrange --
        let capabilities = TerminalCapabilities(stdinIsTTY: true, stdoutIsTTY: true)

        // -- Act --
        let command = try CLI.parseAsRoot(arguments)

        // -- Assert --
        #expect(capabilities.mode(for: command) == nil)
    }
}
