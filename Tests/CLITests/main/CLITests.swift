import Testing

@testable import CLI

@Suite("CLI help")
struct CLITests {
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

    @Test("accepts JSON output for the technologies list")
    func acceptsTechnologiesListJSONOutput() throws {
        // -- Arrange --
        let arguments = ["technologies", "list", "--json"]

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
