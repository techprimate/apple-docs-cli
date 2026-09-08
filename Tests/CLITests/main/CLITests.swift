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

    @Test("reports complete build metadata")
    func includesBuildMetadataInVersion() {
        #expect(
            CLI.configuration.version
                == "dev (commit: none, built: unknown, environment: development)"
        )
    }
}
