import Foundation

#if canImport(Darwin)
    import Darwin
#else
    import Glibc
#endif

final class TerminalPTYHarness {
    enum Failure: Error {
        case system(Int32)
        case timeout(String)
        case outputLimit
        case attributesChanged(String)
        case flagsChanged(expected: Int32, actual: Int32)
        case exited(Int32, String)
    }

    let process = Process()
    private var controllerDescriptor: Int32 = -1
    private var terminalDescriptor: Int32 = -1
    private var original: Settings?
    private var originalFlags: Int32 = 0
    private var captured = Data()
    private var pendingProbes = Data()
    private let enhancedKeyboard: Bool
    var output: String { String(bytes: captured, encoding: .utf8) ?? "" }

    init(enhancedKeyboard: Bool = false) throws {
        self.enhancedKeyboard = enhancedKeyboard
        guard let executable = ProcessInfo.processInfo.environment["APPLE_DOCS_EXECUTABLE"] else {
            throw AppleDocsCommandError.missingExecutable
        }
        var size = winsize(ws_row: 24, ws_col: 80, ws_xpixel: 640, ws_ypixel: 384)
        guard openpty(&controllerDescriptor, &terminalDescriptor, nil, nil, &size) == 0 else {
            throw Failure.system(errno)
        }
        do {
            original = try settings()
            originalFlags = fileStatusFlags()
            let handle = FileHandle(fileDescriptor: terminalDescriptor, closeOnDealloc: false)
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = ["types", "view", "String", "--technology", "Swift"]
            process.standardInput = handle
            process.standardOutput = handle
            process.standardError = handle
            var environment = ProcessInfo.processInfo.environment
            environment["TELEMETRY_DISABLED"] = "true"
            environment["TERM"] = "xterm-256color"
            environment["SWIFTTUI_KITTY_KEYBOARD"] = "1"
            environment["TMUX"] = nil
            environment["STY"] = nil
            process.environment = environment
            try process.run()
        } catch {
            closeDescriptors()
            throw error
        }
    }

    deinit {
        if process.isRunning {
            process.terminate()
            let deadline = ContinuousClock.now.advanced(by: .seconds(1))
            while process.isRunning && ContinuousClock.now < deadline { try? pump() }
            if process.isRunning { kill(process.processIdentifier, SIGKILL) }
        }
        closeDescriptors()
    }

    func send(_ text: String) throws {
        let bytes = Array(text.utf8)
        var offset = 0
        while offset < bytes.count {
            let count = bytes.withUnsafeBytes { buffer in
                write(controllerDescriptor, buffer.baseAddress!.advanced(by: offset), bytes.count - offset)
            }
            if count < 0 && errno == EINTR { continue }
            guard count > 0 else { throw Failure.system(errno) }
            offset += count
        }
    }

    func waitFor(_ text: String, timeout: Double = 30) throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(timeout))
        while !output.contains(text) {
            guard process.isRunning else { throw Failure.exited(process.terminationStatus, output) }
            guard ContinuousClock.now < deadline else { throw Failure.timeout(text) }
            try pump()
        }
    }

    func waitForExit() throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(10))
        while process.isRunning {
            guard ContinuousClock.now < deadline else { throw Failure.timeout("process exit") }
            try pump()
        }
        try pump()
    }

    func resize(width: UInt16, height: UInt16) throws {
        var size = winsize(ws_row: height, ws_col: width, ws_xpixel: width * 8, ws_ypixel: height * 16)
        guard ioctl(terminalDescriptor, TIOCSWINSZ, &size) == 0 else { throw Failure.system(errno) }
        kill(process.processIdentifier, SIGWINCH)
    }

    func attributesRestored() throws -> Bool {
        let current = try settings()
        guard current == original else {
            throw Failure.attributesChanged("Expected \(String(describing: original)), got \(current)")
        }
        let flags = fileStatusFlags()
        guard flags == originalFlags else { throw Failure.flagsChanged(expected: originalFlags, actual: flags) }
        return true
    }

    private func fileStatusFlags() -> Int32 {
        // Darwin also exposes a write-history bit that F_SETFL cannot restore.
        let mask = O_ACCMODE | O_NONBLOCK | O_APPEND | O_ASYNC | O_SYNC | O_DSYNC
        return fcntl(terminalDescriptor, F_GETFL) & mask
    }

    private func pump() throws {
        var descriptor = pollfd(fd: controllerDescriptor, events: Int16(POLLIN), revents: 0)
        let ready = poll(&descriptor, 1, 50)
        if ready < 0 && errno == EINTR { return }
        guard ready >= 0 else { throw Failure.system(errno) }
        guard ready > 0 && descriptor.revents & Int16(POLLIN) != 0 else { return }
        var bytes = [UInt8](repeating: 0, count: 16384)
        let count = read(controllerDescriptor, &bytes, bytes.count)
        guard count > 0 else { return }
        guard captured.count + count <= 2_000_000 else { throw Failure.outputLimit }
        captured.append(contentsOf: bytes.prefix(count))
        pendingProbes.append(contentsOf: bytes.prefix(count))
        try answerProbes()
        pendingProbes = Data(pendingProbes.suffix(64))
    }

    private func answerProbes() throws {
        let replies = [
            ("\u{1B}[?u", enhancedKeyboard ? "\u{1B}[?0u" : ""),
            ("\u{1B}[c", "\u{1B}[?1;2c"),
            ("\u{1B}[?1016$p", "\u{1B}[?1016;0$y"),
            ("\u{1B}[16t", "\u{1B}[6;16;8t"),
        ]
        for (query, reply) in replies {
            while let range = pendingProbes.range(of: Data(query.utf8)) {
                pendingProbes.removeSubrange(range)
                try send(reply)
            }
        }
    }

    private func closeDescriptors() {
        if controllerDescriptor >= 0 {
            close(controllerDescriptor)
            controllerDescriptor = -1
        }
        if terminalDescriptor >= 0 {
            close(terminalDescriptor)
            terminalDescriptor = -1
        }
    }

    private func settings() throws -> Settings {
        var value = termios()
        guard tcgetattr(terminalDescriptor, &value) == 0 else { throw Failure.system(errno) }
        return Settings(
            input: value.c_iflag, output: value.c_oflag, control: value.c_cflag, local: value.c_lflag,
            characters: withUnsafeBytes(of: value.c_cc) { Data($0) },
            inputSpeed: cfgetispeed(&value), outputSpeed: cfgetospeed(&value))
    }

    private struct Settings: Equatable {
        let input: tcflag_t
        let output: tcflag_t
        let control: tcflag_t
        let local: tcflag_t
        let characters: Data
        let inputSpeed: speed_t
        let outputSpeed: speed_t
    }
}
