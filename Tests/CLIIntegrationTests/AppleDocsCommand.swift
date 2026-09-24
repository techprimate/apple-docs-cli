import Dispatch
import Foundation

#if canImport(Darwin)
    import Darwin
#else
    import Glibc
#endif

enum AppleDocsCommandError: Error, LocalizedError {
    case failed(status: Int32, stderr: String)
    case invalidUTF8(stream: String)
    case missingExecutable
    case readFailed(code: Int32)

    var errorDescription: String? {
        switch self {
        case .failed(let status, let stderr):
            return "apple-docs exited with status \(status): \(stderr)"
        case .invalidUTF8(let stream):
            return "apple-docs returned invalid UTF-8 on \(stream)."
        case .missingExecutable:
            return "APPLE_DOCS_EXECUTABLE is not set. Run the tests with make test-integration."
        case .readFailed(let code):
            return "Could not read apple-docs output: errno \(code)."
        }
    }
}

func runAppleDocs(
    _ arguments: [String],
    executablePath: String? = ProcessInfo.processInfo.environment["APPLE_DOCS_EXECUTABLE"],
    captureStandardError: (String) -> Void = { _ in }
) throws -> String {
    guard let executablePath else {
        throw AppleDocsCommandError.missingExecutable
    }

    let process = Process()
    let standardOutput = Pipe()
    let standardError = Pipe()
    process.executableURL = URL(fileURLWithPath: executablePath)
    process.arguments = arguments
    process.standardInput = FileHandle.nullDevice
    var environment = ProcessInfo.processInfo.environment
    environment["TELEMETRY_DISABLED"] = "true"
    process.environment = environment
    process.standardOutput = standardOutput
    process.standardError = standardError

    try process.run()
    let errorBuffer = CommandErrorBuffer()
    let draining = DispatchGroup()
    draining.enter()
    DispatchQueue.global().async {
        let result = Result { try readCommandOutput(standardError.fileHandleForReading) }
        errorBuffer.store(result)
        draining.leave()
    }
    let outputResult = Result { try readCommandOutput(standardOutput.fileHandleForReading) }
    process.waitUntilExit()
    draining.wait()
    let outputData = try outputResult.get()
    let errorData = try errorBuffer.load().get()

    guard let output = String(data: outputData, encoding: .utf8) else {
        throw AppleDocsCommandError.invalidUTF8(stream: "standard output")
    }
    guard let error = String(data: errorData, encoding: .utf8) else {
        throw AppleDocsCommandError.invalidUTF8(stream: "standard error")
    }
    captureStandardError(error)
    guard process.terminationStatus == 0 else {
        throw AppleDocsCommandError.failed(status: process.terminationStatus, stderr: error)
    }
    return output
}

// NSLock keeps the integration harness usable on the package's macOS 13 deployment target.
private final class CommandErrorBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var result: Result<Data, any Error> = .success(Data())

    func store(_ result: Result<Data, any Error>) {
        lock.withLock { self.result = result }
    }

    func load() -> Result<Data, any Error> {
        lock.withLock { result }
    }
}

private func readCommandOutput(_ handle: FileHandle) throws -> Data {
    var result = Data()
    var buffer = [UInt8](repeating: 0, count: 16384)
    while true {
        let count = read(handle.fileDescriptor, &buffer, buffer.count)
        if count < 0 && errno == EINTR { continue }
        guard count >= 0 else { throw AppleDocsCommandError.readFailed(code: errno) }
        if count == 0 { return result }
        result.append(contentsOf: buffer.prefix(count))
    }
}
