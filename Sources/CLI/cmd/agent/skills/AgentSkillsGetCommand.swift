import ArgumentParser
import Logging
@preconcurrency import SentrySwift

struct AgentSkillsGetCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "get",
        abstract: "Print a bundled Agent Skill."
    )

    @Argument(help: "The bundled skill name.")
    var name: String

    mutating func run() throws {
        if SentrySDK.isEnabled {
            let context = SentryCommandContext.agentSkillsGet
            let transaction = SentrySDK.startTransaction(
                name: context.transactionName,
                operation: "console.command",
                bindToScope: true
            )
            for (key, value) in context.attributes {
                transaction.setData(value: value, key: key)
            }
            SentrySDK.configureScope { scope in
                scope.setContext(value: context.attributes, key: "cli")
            }
            let breadcrumb = Breadcrumb(
                level: .info,
                category: SentryConfiguration.breadcrumbCategory
            )
            breadcrumb.type = "user"
            breadcrumb.message = "CLI command invoked"
            for (key, value) in context.attributes {
                breadcrumb.setData(value: value, key: key)
            }
            SentrySDK.addBreadcrumb(breadcrumb)
            let logger = Logger(label: "dev.techprimate.apple-docs")
            logger.info(
                "CLI command started",
                metadata: context.logMetadata
            )
        }

        guard let skill = BundledAgentSkills.skill(named: name) else {
            throw ValidationError("Unknown bundled Agent Skill '\(name)'.")
        }
        print(skill.content)
    }
}
