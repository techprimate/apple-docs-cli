import ArgumentParser
import Logging

#if canImport(SentrySwift)
    @preconcurrency import SentrySwift
#endif

struct AgentSkillsListCommand: ParsableCommand {
    private static let logger = Logger(
        label: "com.techprimate.apple-docs.agent-skills-list"
    )

    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List Agent Skills bundled with apple-docs."
    )

    mutating func run() throws {
        #if canImport(SentrySwift)
            if SentrySDK.isEnabled {
                let context = SentryCommandContext.agentSkillsList
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
                Self.logger.info(
                    "CLI command started",
                    metadata: context.logMetadata
                )
            }
        #endif

        for skill in BundledAgentSkills.all {
            print("\(skill.name)\t\(skill.shortDescription)")
        }
    }
}
