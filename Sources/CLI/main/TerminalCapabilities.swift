#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#endif

protocol TerminalCapabilities {
    var stdinIsTTY: Bool { get }
    var stdoutIsTTY: Bool { get }
    func mode(for output: OutputOptions) -> OutputMode
}

extension TerminalCapabilities {
    var stdinIsTTY: Bool { isatty(STDIN_FILENO) == 1 }
    var stdoutIsTTY: Bool { isatty(STDOUT_FILENO) == 1 }

    func mode(for output: OutputOptions) -> OutputMode {
        output.mode(stdinIsTTY: stdinIsTTY, stdoutIsTTY: stdoutIsTTY)
    }
}

struct DefaultTerminalCapabilities: TerminalCapabilities {}

#if DEBUG
    protocol TerminalCapabilitiesProvider {
        associatedtype Capabilities: TerminalCapabilities
        var terminalCapabilities: Capabilities { get }
    }

    extension Dependencies: TerminalCapabilitiesProvider {}
#endif
