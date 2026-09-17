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

        // -- Act --
        let mode = options.mode(stdinIsTTY: test.input, stdoutIsTTY: test.output)

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
            options.mode(stdinIsTTY: true, stdoutIsTTY: true),
            options.mode(stdinIsTTY: false, stdoutIsTTY: true),
            options.mode(stdinIsTTY: true, stdoutIsTTY: false),
            options.mode(stdinIsTTY: false, stdoutIsTTY: false),
        ]

        // -- Assert --
        #expect(modes.allSatisfy { $0 == test.expected })
    }
}
