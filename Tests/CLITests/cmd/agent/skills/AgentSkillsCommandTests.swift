import Foundation
import Logging
import Testing

@testable import CLI

@Suite("Agent skills commands")
struct AgentSkillsCommandTests {
    @Test("list writes the bundled skill names through the injected output")
    func writesSkillList() throws {
        // -- Arrange --
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let command = try AgentSkillsListCommand.parse(["--dir", root.path])
        let deps = SkillListDependencies()

        // -- Act --
        try command.run(deps: deps)

        // -- Assert --
        #expect(deps.output.lines.count == BundledAgentSkills.all.count)
        #expect(deps.output.lines.first?.hasPrefix("apple-docs\t") == true)
        #expect(deps.telemetry.commands == ["agent.skills.list"])
    }

    @Test(
        "get writes bundled skill content through the injected output",
        arguments: [
            "apple-docs", "apple-docs-discover-api", "apple-docs-check-availability", "apple-docs-support",
            "apple-docs-terms",
        ])
    func writesSkillContent(name: String) throws {
        // -- Arrange --
        let command = try AgentSkillsGetCommand.parse([name])
        let deps = SkillListDependencies()

        // -- Act --
        try command.run(deps: deps)

        // -- Assert --
        #expect(deps.output.lines == [BundledAgentSkills.skill(named: name)?.content])
        #expect(deps.telemetry.commands == ["agent.skills.get"])
    }

    @Test("list distinguishes installation state without changing files")
    func listsInstallationState() throws {
        // -- Arrange --
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let deps = SkillListDependencies()
        let service = deps.agentSkillInstallationService()
        _ = try service.install(Array(BundledAgentSkills.all.prefix(3)), root: root.path, dryRun: false, force: false)
        let outdated = root.appendingPathComponent("skills/apple-docs-discover-api")
        try Data("previous version".utf8).write(to: outdated.appendingPathComponent("SKILL.md"))
        let receipt = AgentSkillInstallationStore.Receipt(
            name: "apple-docs-discover-api", content: Data("previous version".utf8))
        try JSONEncoder().encode(receipt).write(to: outdated.appendingPathComponent(".apple-docs-managed.json"))
        let modified = root.appendingPathComponent("skills/apple-docs-check-availability/SKILL.md")
        try Data("local edits".utf8).write(to: modified)
        let unmanaged = root.appendingPathComponent("skills/apple-docs-support")
        try FileManager.default.createDirectory(at: unmanaged, withIntermediateDirectories: true)
        try Data("user skill".utf8).write(to: unmanaged.appendingPathComponent("SKILL.md"))
        let command = try AgentSkillsListCommand.parse(["--dir", root.path])

        // -- Act --
        try command.run(deps: deps)

        // -- Assert --
        #expect(deps.output.lines.contains { $0.hasPrefix("apple-docs\tinstalled\t") })
        #expect(deps.output.lines.contains { $0.hasPrefix("apple-docs-discover-api\tupdate available\t") })
        #expect(deps.output.lines.contains { $0.hasPrefix("apple-docs-check-availability\tmodified\t") })
        #expect(deps.output.lines.contains { $0.hasPrefix("apple-docs-support\tunmanaged\t") })
        #expect(deps.output.lines.contains { $0.hasPrefix("apple-docs-terms\tnot installed\t") })
        #expect(deps.output.lines.allSatisfy { $0.contains(root.path) })
        #expect(try String(contentsOf: modified, encoding: .utf8) == "local edits")
        #expect(
            try String(contentsOf: outdated.appendingPathComponent("SKILL.md"), encoding: .utf8) == "previous version")
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
    private func temporaryRoot() -> URL {
        FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent(UUID().uuidString)
    }
}

private struct SkillListDependencies: TelemetryProvider, CommandOutputWriterProvider {
    let telemetry = RecordingCommandTelemetry()
    let output = RecordingCommandOutputWriter()
    var commandOutputWriter: RecordingCommandOutputWriter { output }

    func agentSkillFileManager() -> FileManager { .default }

    func agentSkillInstallationService() -> DefaultAgentSkillInstallationService {
        DefaultAgentSkillInstallationService(logger: Logger(label: "test"))
    }
}

extension SkillListDependencies: AgentSkillInstallationServiceProvider {}
