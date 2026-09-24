import ArgumentParser

enum OutputAudience: String, Codable, Equatable, Sendable {
    case human, agent
}

enum OutputFormat: Equatable, Sendable {
    case text, json
}

struct OutputOptions: ParsableArguments {
    @Flag(help: "Print JSON. Page output preserves Apple's raw DocC document, even with --agent.")
    var json = false

    @Flag(help: "Print agent-oriented Markdown with follow-up commands. --json takes precedence.")
    var agent = false

    var audience: OutputAudience { agent && !json ? .agent : .human }
    var format: OutputFormat { json ? .json : .text }
}
