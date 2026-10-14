import Foundation
import Logging
import Testing

@testable import CLI

@Suite("Skill command partial completion")
struct AgentSkillsRecoveryCommandTests {
    @Test("prints completed outcomes before propagating a later filesystem failure")
    func reportsPartialCompletion() throws {
        // -- Arrange --
        let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
            .appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let command = try AgentSkillsInstallCommand.parse([
            "apple-docs", "apple-docs-discover-api", "--dir", root.path,
        ])
        let deps = RecoveryDependencies()

        // -- Act --
        #expect(throws: InjectedSkillFailure.self) { try command.run(deps: deps) }

        // -- Assert --
        #expect(deps.output.lines.count == 1)
        #expect(deps.output.lines.first?.contains("Installed: apple-docs at") == true)
        #expect(deps.output.lines.first?.contains("Installed: apple-docs-discover-api at") == false)
    }
}

private struct RecoveryDependencies: AgentSkillInstallationServiceProvider, CommandOutputWriterProvider {
    let output = RecordingCommandOutputWriter()
    var commandOutputWriter: RecordingCommandOutputWriter { output }

    func agentSkillFileManager() -> FaultInjectingSkillFileSystem {
        FaultInjectingSkillFileSystem(
            operation: .write, filename: ".apple-docs-managed.json", skillName: "apple-docs-discover-api")
    }

    func agentSkillInstallationService() -> DefaultAgentSkillInstallationService {
        DefaultAgentSkillInstallationService(
            logger: Logger(label: "test") { _ in SwiftLogNoOpLogHandler() }, fileManager: agentSkillFileManager())
    }
}
