import ArgumentParser

#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#endif

struct TerminalCapabilities: Equatable, Sendable {
    let stdinIsTTY: Bool
    let stdoutIsTTY: Bool

    func mode(for command: any ParsableCommand) -> OutputMode? {
        (command as? any OutputOptionsProviding)?.output.mode(stdinIsTTY: stdinIsTTY, stdoutIsTTY: stdoutIsTTY)
    }

    static let current = TerminalCapabilities(
        stdinIsTTY: isatty(STDIN_FILENO) == 1,
        stdoutIsTTY: isatty(STDOUT_FILENO) == 1
    )
}
