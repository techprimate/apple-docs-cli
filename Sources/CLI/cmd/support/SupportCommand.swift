import ArgumentParser

struct SupportCommand: AsyncParsableCommand, GlobalOptionsProviding {
    @OptionGroup var global: GlobalOptions

    static let configuration = CommandConfiguration(
        commandName: "support",
        abstract: "Browse Apple support resources and read supported HTML content.",
        subcommands: [
            SupportArticlesCommand.self, SupportGuidesCommand.self, SupportGlossaryCommand.self,
            SupportTermsCommand.self, SupportViewCommand.self,
        ])
}

protocol SupportExecutableCommand: AsyncParsableCommand, GlobalOptionsProviding {
    var output: OutputOptions { get }
    var request: SupportRequest { get }
}

extension SupportExecutableCommand {
    mutating func run() async throws {
        try await run(deps: AppleDocs.dependencies)
    }

    func run(deps: SupportCommandDependencies) async throws {
        deps.telemetry.startCommand(
            TelemetryCommandContext(
                command: request.commandName, outputJSON: output.json, technology: nil, typeName: nil))
        let runner = SupportCommandRunner(
            service: deps.supportService, renderer: deps.supportRenderer(output: output))
        deps.commandOutputWriter.write(try await runner.run(request))
    }
}

struct SupportViewCommand: SupportExecutableCommand {
    @OptionGroup var global: GlobalOptions
    @OptionGroup var output: OutputOptions
    @Option(help: "A supported path relative to developer.apple.com, including help/ or support/.")
    var path: String

    static let configuration = CommandConfiguration(
        commandName: "view", abstract: "Read a supported HTML document. PDFs and unknown layouts are not parsed.")

    var request: SupportRequest { .article(path: path) }
}
