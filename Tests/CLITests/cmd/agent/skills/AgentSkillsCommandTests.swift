import Testing

@testable import CLI

@Suite("Agent skills commands")
struct AgentSkillsCommandTests {
    @Test("registers the nested list command")
    func parsesListCommand() throws {
        let command = try CLI.parseAsRoot(["agent", "skills", "list"])

        #expect(command is AgentSkillsListCommand)
    }

    @Test("registers the nested get command with a skill name")
    func parsesGetCommand() throws {
        let command = try CLI.parseAsRoot([
            "agent", "skills", "get", "apple-docs",
        ])
        let getCommand = try #require(command as? AgentSkillsGetCommand)

        #expect(getCommand.name == "apple-docs")
    }
}
