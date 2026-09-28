import Testing

@testable import CLI

@Suite("Documentation output options")
struct OutputOptionsTests {
    @Test(
        "selects human text by default and separates audience from format",
        arguments: [
            ([], OutputAudience.human, OutputFormat.text),
            (["--agent"], .agent, .text),
            (["--json"], .human, .json),
            (["--agent", "--json"], .agent, .json),
            (["--json", "--agent"], .agent, .json),
        ])
    func selectsOutput(flags: [String], audience: OutputAudience, format: OutputFormat) throws {
        // -- Arrange --
        let arguments = ["types", "view", "String", "--technology", "Swift"] + flags

        // -- Act --
        let command = try #require(CLI.parseAsRoot(arguments) as? TypesViewCommand)

        // -- Assert --
        #expect(command.output.audience == audience)
        #expect(command.output.format == format)
    }

    @Test(
        "parses non-interactive for every documentation command",
        arguments: [
            ["technologies", "list"],
            ["types", "list", "--technology", "Swift"],
            ["types", "search", "String", "--technology", "Swift"],
            ["types", "view", "String", "--technology", "Swift"],
        ])
    func parsesNonInteractive(arguments: [String]) throws {
        // -- Arrange --
        let arguments = arguments + ["--non-interactive"]

        // -- Act --
        let command = try CLI.parseAsRoot(arguments)

        // -- Assert --
        switch command {
        case let command as TechnologiesListCommand: #expect(command.output.nonInteractive)
        case let command as TypesListCommand: #expect(command.output.nonInteractive)
        case let command as TypesSearchCommand: #expect(command.output.nonInteractive)
        case let command as TypesViewCommand: #expect(command.output.nonInteractive)
        default: Issue.record("Unexpected documentation command")
        }
    }

    @Test("a partial terminal override is used through the protocol")
    func partialTerminalOverride() throws {
        // -- Arrange --
        let terminal: any TerminalCapabilities = OutputNotTTY()
        let options = try OutputOptions.parse([])

        // -- Act --
        let mode = terminal.mode(for: options)

        // -- Assert --
        #expect(!terminal.stdoutIsTTY)
        #expect(mode == .oneShot(audience: .human, format: .text))
    }

    private struct OutputNotTTY: TerminalCapabilities {
        var stdoutIsTTY: Bool { false }
    }

    private struct StubTerminalCapabilities: TerminalCapabilities {
        let stdinIsTTY: Bool
        let stdoutIsTTY: Bool
    }

    struct TerminalCase: Sendable {
        let input: Bool
        let output: Bool
        let expected: OutputMode
    }

    struct FlagCase: Sendable {
        let flags: [String]
        let expected: OutputMode
    }

    @Test(
        "only two terminal descriptors select interactive output",
        arguments: [
            TerminalCase(input: true, output: true, expected: .interactive),
            TerminalCase(input: false, output: true, expected: .oneShot(audience: .human, format: .text)),
            TerminalCase(input: true, output: false, expected: .oneShot(audience: .human, format: .text)),
            TerminalCase(input: false, output: false, expected: .oneShot(audience: .human, format: .text)),
        ])
    func selectsDefaultMode(test: TerminalCase) throws {
        // -- Arrange --
        let options = try OutputOptions.parse([])
        let terminal = StubTerminalCapabilities(stdinIsTTY: test.input, stdoutIsTTY: test.output)

        // -- Act --
        let mode = terminal.mode(for: options)

        // -- Assert --
        #expect(mode == test.expected)
    }

    @Test(
        "explicit flags are independent, order-independent, and never interactive",
        arguments: [
            FlagCase(flags: ["--non-interactive"], expected: .oneShot(audience: .human, format: .text)),
            FlagCase(flags: ["--json"], expected: .oneShot(audience: .human, format: .json)),
            FlagCase(flags: ["--agent"], expected: .oneShot(audience: .agent, format: .text)),
            FlagCase(flags: ["--agent", "--json"], expected: .oneShot(audience: .agent, format: .json)),
            FlagCase(flags: ["--json", "--agent"], expected: .oneShot(audience: .agent, format: .json)),
            FlagCase(flags: ["--non-interactive", "--agent"], expected: .oneShot(audience: .agent, format: .text)),
            FlagCase(flags: ["--agent", "--non-interactive"], expected: .oneShot(audience: .agent, format: .text)),
            FlagCase(flags: ["--json", "--non-interactive"], expected: .oneShot(audience: .human, format: .json)),
            FlagCase(flags: ["--non-interactive", "--json"], expected: .oneShot(audience: .human, format: .json)),
            FlagCase(
                flags: ["--agent", "--json", "--non-interactive"], expected: .oneShot(audience: .agent, format: .json)),
            FlagCase(
                flags: ["--agent", "--non-interactive", "--json"], expected: .oneShot(audience: .agent, format: .json)),
            FlagCase(
                flags: ["--json", "--agent", "--non-interactive"], expected: .oneShot(audience: .agent, format: .json)),
            FlagCase(
                flags: ["--json", "--non-interactive", "--agent"], expected: .oneShot(audience: .agent, format: .json)),
            FlagCase(
                flags: ["--non-interactive", "--agent", "--json"], expected: .oneShot(audience: .agent, format: .json)),
            FlagCase(
                flags: ["--non-interactive", "--json", "--agent"], expected: .oneShot(audience: .agent, format: .json)),
        ])
    func selectsExplicitMode(test: FlagCase) throws {
        // -- Arrange --
        let options = try OutputOptions.parse(test.flags)

        // -- Act --
        let modes = [
            StubTerminalCapabilities(stdinIsTTY: true, stdoutIsTTY: true).mode(for: options),
            StubTerminalCapabilities(stdinIsTTY: false, stdoutIsTTY: true).mode(for: options),
            StubTerminalCapabilities(stdinIsTTY: true, stdoutIsTTY: false).mode(for: options),
            StubTerminalCapabilities(stdinIsTTY: false, stdoutIsTTY: false).mode(for: options),
        ]

        // -- Assert --
        #expect(modes.allSatisfy { $0 == test.expected })
    }
}
