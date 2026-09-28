import ArgumentParser

enum OutputAudience: String, Codable, Equatable, Sendable {
    case human, agent
}

enum OutputFormat: Equatable, Sendable {
    case text, json
}

enum OutputMode: Equatable, Sendable {
    case interactive
    case oneShot(audience: OutputAudience, format: OutputFormat)
}

struct OutputOptions: ParsableArguments {
    @Flag(help: "Print documentation once without opening the terminal browser.")
    var nonInteractive = false

    @Flag(help: "Print normalized semantic JSON. Combine with --agent to include follow-up commands.")
    var json = false

    @Flag(help: "Print agent-oriented Markdown with follow-up commands. Combine with --json for structured output.")
    var agent = false

    var audience: OutputAudience { agent ? .agent : .human }
    var format: OutputFormat { json ? .json : .text }

    func mode(stdinIsTTY: Bool, stdoutIsTTY: Bool) -> OutputMode {
        if json || agent || nonInteractive || !stdinIsTTY || !stdoutIsTTY {
            return .oneShot(audience: audience, format: format)
        }
        return .interactive
    }
}
