import ArgumentParser
import Twill

struct CLI: AsyncParsableCommand, GlobalOptionsProviding {
    #if DEBUG
        typealias Deps = any TechnologyCatalogClientProvider
    #else
        typealias Deps = Dependencies
    #endif

    @OptionGroup var global: GlobalOptions

    static let configuration = CommandConfiguration(
        commandName: "apple-docs",
        abstract: "Access Apple developer documentation from the command line.",
        discussion: """
            Run 'apple-docs agent skills list' to see bundled Agent Skills with task-specific guidance.
            """,
        version: BuildMetadata.formatted,
        subcommands: [
            TypesCommand.self,
            TechnologiesCommand.self,
            CacheCommand.self,
            AgentCommand.self,
        ]
    )

    mutating func run() async throws {
        try await run(deps: Dependencies.shared)
    }

    @MainActor
    func run(deps: Deps) async throws {
        let rootView = BrowserView(client: deps.documentationClient)
        let application = Application(rootView: rootView)
        try await application.run()
    }
}
