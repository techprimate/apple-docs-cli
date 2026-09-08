import Foundation

enum AppleDocsCommandError: Error, LocalizedError {
    case failed(status: Int32, stderr: String)
    case invalidUTF8(stream: String)
    case missingExecutable

    var errorDescription: String? {
        switch self {
        case .failed(let status, let stderr):
            return "apple-docs exited with status \(status): \(stderr)"
        case .invalidUTF8(let stream):
            return "apple-docs returned invalid UTF-8 on \(stream)."
        case .missingExecutable:
            return "APPLE_DOCS_EXECUTABLE is not set. Run the tests with make test-integration."
        }
    }
}

func runAppleDocs(_ arguments: [String]) throws -> String {
    guard let executablePath = ProcessInfo.processInfo.environment["APPLE_DOCS_EXECUTABLE"] else {
        throw AppleDocsCommandError.missingExecutable
    }

    let process = Process()
    let standardOutput = Pipe()
    let standardError = Pipe()
    process.executableURL = URL(fileURLWithPath: executablePath)
    process.arguments = arguments
    process.standardOutput = standardOutput
    process.standardError = standardError

    try process.run()
    let outputData = standardOutput.fileHandleForReading.readDataToEndOfFile()
    let errorData = standardError.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()

    guard let output = String(data: outputData, encoding: .utf8) else {
        throw AppleDocsCommandError.invalidUTF8(stream: "standard output")
    }
    guard let error = String(data: errorData, encoding: .utf8) else {
        throw AppleDocsCommandError.invalidUTF8(stream: "standard error")
    }
    guard process.terminationStatus == 0 else {
        throw AppleDocsCommandError.failed(status: process.terminationStatus, stderr: error)
    }
    return output
}
