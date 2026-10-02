import Testing

@testable import CLI

@Suite("Agent skills commands")
struct AgentSkillsCommandTests {
    @Test("list writes the bundled skill names through the injected output")
    func writesSkillList() throws {
        // -- Arrange --
        let command = try AgentSkillsListCommand.parse([])
        let deps = SkillListDependencies()

        // -- Act --
        command.run(deps: deps)

        // -- Assert --
        #expect(deps.output.lines.count == BundledAgentSkills.all.count)
        #expect(deps.output.lines.first?.hasPrefix("apple-docs\t") == true)
        #expect(deps.telemetry.commands == ["agent.skills.list"])
    }

    @Test("registers the nested list command")
    func parsesListCommand() throws {
        // -- Arrange --
        let arguments = ["agent", "skills", "list"]

        // -- Act --
        let command = try CLI.parseAsRoot(arguments)

        // -- Assert --
        #expect(command is AgentSkillsListCommand)
    }

    @Test("registers the nested get command with a skill name")
    func parsesGetCommand() throws {
        // -- Arrange --
        let arguments = ["agent", "skills", "get", "apple-docs"]

        // -- Act --
        let command = try CLI.parseAsRoot(arguments)

        // -- Assert --
        let getCommand = try #require(command as? AgentSkillsGetCommand)
        #expect(getCommand.name == "apple-docs")
    }
}

private struct SkillListDependencies: TelemetryProvider, CommandOutputWriterProvider {
    let telemetry = RecordingCommandTelemetry()
    let output = RecordingCommandOutputWriter()
    var commandOutputWriter: RecordingCommandOutputWriter { output }
}
