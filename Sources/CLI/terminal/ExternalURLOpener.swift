import Foundation
import Synchronization

#if DEBUG
    protocol ExternalURLOpener: Sendable {
        func open(_ url: URL) async throws
    }
#else
    typealias ExternalURLOpener = DefaultExternalURLOpener
#endif

enum ExternalOpeningError: Error, Equatable, LocalizedError {
    case invalidURL
    case unavailable
    case failed(status: Int32)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Only HTTP or HTTPS website URLs without credentials can be opened."
        case .unavailable: return "Could not find xdg-open in PATH."
        case .failed(let status): return "The system browser launcher exited with status \(status)."
        }
    }
}

struct DefaultExternalURLOpener: Sendable {
    private let environment: [String: String]
    private let launch: @Sendable (URL, [String]) async throws -> Void

    init(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        launch: @escaping @Sendable (URL, [String]) async throws -> Void = launchExternalURLProcess
    ) {
        self.environment = environment
        self.launch = launch
    }

    func open(_ url: URL) async throws {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
            let scheme = components.scheme?.lowercased(), ["http", "https"].contains(scheme),
            let host = components.host, !host.isEmpty, components.user == nil, components.password == nil,
            let decoded = url.absoluteString.removingPercentEncoding,
            decoded.rangeOfCharacter(from: .controlCharacters) == nil
        else { throw ExternalOpeningError.invalidURL }
        try Task.checkCancellation()
        #if os(macOS)
            let executable = URL(fileURLWithPath: "/usr/bin/open")
        #else
            let candidates = (environment["PATH"] ?? "").split(separator: ":").map {
                URL(fileURLWithPath: String($0), isDirectory: true).appendingPathComponent("xdg-open")
            }
            guard let executable = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0.path) })
            else {
                throw ExternalOpeningError.unavailable
            }
        #endif
        try await launch(executable, [url.absoluteString])
    }
}

#if DEBUG
    extension DefaultExternalURLOpener: ExternalURLOpener {}
#endif

private func launchExternalURLProcess(_ executable: URL, arguments: [String]) async throws {
    let process = Process()
    process.executableURL = executable
    process.arguments = arguments
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice
    let cancelled = Mutex(false)
    try await withTaskCancellationHandler {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            process.terminationHandler = { completed in
                if cancelled.withLock({ $0 }) {
                    continuation.resume(throwing: CancellationError())
                } else if completed.terminationStatus == 0 {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: ExternalOpeningError.failed(status: completed.terminationStatus))
                }
            }
            do {
                try cancelled.withLock { cancelled in
                    if cancelled { throw CancellationError() }
                    try process.run()
                }
            } catch {
                process.terminationHandler = nil
                continuation.resume(throwing: error)
            }
        }
    } onCancel: {
        cancelled.withLock { value in
            value = true
            if process.isRunning { process.terminate() }
        }
    }
}
