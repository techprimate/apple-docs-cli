import Testing

@testable import CLI

@Suite("CLI help")
struct CLITests {
    @Test(
        "accepts verbose at every command depth",
        arguments: [
            ["--verbose", "agent", "skills", "list"],
            ["agent", "--verbose", "skills", "list"],
            ["agent", "skills", "--verbose", "list"],
            ["agent", "skills", "list", "--verbose"],
        ])
    func acceptsVerboseAtEveryDepth(arguments: [String]) throws {
        // -- Arrange --
        let expectedType = AgentSkillsListCommand.self

        // -- Act --
        let command = try CLI.parseAsRoot(arguments)

        // -- Assert --
        #expect(type(of: command) == expectedType)
        let options = try #require(command as? any GlobalOptionsProviding)
        #expect(options.global.verbose)
    }

    @Test(
        "accepts verbose on each executable command",
        arguments: [
            ["types", "view", "String", "--technology", "Swift", "--json"],
            ["types", "list", "--technology", "Swift", "--agent"],
            ["types", "search", "String", "--technology", "Swift"],
            ["technologies", "list", "--json"],
            ["cache", "clean"],
            ["agent", "skills", "get", "apple-docs"],
            ["agent", "skills", "list"],
            ["agent", "skills", "install", "apple-docs", "--dry-run"],
            ["agent", "skills", "uninstall", "apple-docs", "--dry-run"],
        ])
    func acceptsVerboseOnEachCommand(arguments: [String]) throws {
        // -- Arrange --
        let arguments = arguments + ["--verbose"]

        // -- Act --
        let command = try CLI.parseAsRoot(arguments)

        // -- Assert --
        #expect(type(of: command).configuration.subcommands.isEmpty)
        let options = try #require(command as? any GlobalOptionsProviding)
        #expect(options.global.verbose)
    }

    @Test("does not treat positional values after the terminator as flags")
    func respectsArgumentTerminator() throws {
        // -- Arrange --
        let arguments = ["agent", "skills", "get", "--", "--verbose"]

        // -- Act --
        let command = try #require(CLI.parseAsRoot(arguments) as? AgentSkillsGetCommand)

        // -- Assert --
        #expect(command.name == "--verbose")
        #expect(!command.global.verbose)
    }

    @Test("leaves verbose disabled by default")
    func defaultsToQuietLogging() throws {
        // -- Arrange --
        let arguments = ["agent", "skills", "list"]

        // -- Act --
        let command = try #require(CLI.parseAsRoot(arguments) as? AgentSkillsListCommand)

        // -- Assert --
        #expect(!command.global.verbose)
    }

    @Test("directs agents to bundled skills")
    func includesAgentSkillsHint() {
        #expect(
            CLI.helpMessage().contains(
                "Run 'apple-docs agent skills list' to see bundled Agent Skills"
            )
        )
    }

    @Test("accepts the technologies list command hierarchy")
    func acceptsTechnologiesListCommand() throws {
        // -- Arrange --
        let arguments = ["technologies", "list"]

        // -- Act --
        let command = try CLI.parseAsRoot(arguments)

        // -- Assert --
        #expect(command is TechnologiesListCommand)
    }

    @Test(
        "accepts JSON and agent output for technologies list",
        arguments: [
            ["--json"], ["--agent"], ["--json", "--agent"], ["--agent", "--json"],
        ])
    func acceptsTechnologiesListJSONOutput(flags: [String]) throws {
        // -- Arrange --
        let arguments = ["technologies", "list"] + flags

        // -- Act --
        let command = try CLI.parseAsRoot(arguments)

        // -- Assert --
        let listCommand = try #require(command as? TechnologiesListCommand)
        #expect(listCommand.json)
    }

    @Test("reports complete build metadata")
    func includesBuildMetadataInVersion() {
        #expect(
            CLI.configuration.version
                == "dev (commit: none, built: unknown, environment: development)"
        )
    }
}
