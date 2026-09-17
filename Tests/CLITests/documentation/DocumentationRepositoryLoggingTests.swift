import Foundation
import Logging
import Testing

@testable import CLI

@Suite("Documentation repository logging")
struct DocumentationRepositoryLoggingTests {
    @Test("logs page normalization counts without documentation content")
    func logsNormalization() async throws {
        // -- Arrange --
        let recorder = ClientLogRecorder()
        let destination = DocumentationDestination(technology: "swift", path: "/documentation/swift/string")
        let data = Data(
            #"""
            {"metadata":{"title":"Private title","symbolKind":"struct"},
             "abstract":[{"text":"Private documentation body"}]}
            """#.utf8)
        let repository = try makeRepository(data: data, logger: recorder.logger())

        // -- Act --
        let loaded = try await repository.page(at: destination)

        // -- Assert --
        #expect(loaded.page.title == "Private title")
        let event = try #require(recorder.events.first { $0.message.description == "Normalized documentation page" })
        #expect(event.level == .debug)
        #expect(event.metadata?["bytes"]?.description == String(data.count))
        #expect(event.metadata?["path"]?.description == "/documentation/swift/string")
        #expect(!recorder.events.contains { $0.level >= .warning })
        for event in recorder.events {
            let output = "\(event.message) \(event.metadata ?? [:])"
            #expect(!output.contains("Private title"))
            #expect(!output.contains("Private documentation body"))
        }
    }

    @Test("logs decoding failure without exposing malformed bytes")
    func logsDecodingFailure() async throws {
        // -- Arrange --
        let recorder = ClientLogRecorder()
        let data = Data("private malformed document".utf8)
        let repository = try makeRepository(data: data, logger: recorder.logger())
        let destination = DocumentationDestination(technology: "swift", path: "/documentation/swift/string")

        // -- Act --
        await #expect(throws: DecodingError.self) { try await repository.page(at: destination) }

        // -- Assert --
        let event = try #require(recorder.events.first { $0.level == .error })
        #expect(event.message.description == "Failed to normalize documentation page")
        #expect(event.metadata?["path"]?.description == "/documentation/swift/string")
        #expect(
            !recorder.events.contains {
                "\($0.message) \($0.metadata ?? [:])".contains("private malformed document")
            })
    }

    private func makeRepository(
        data: Data, logger: Logger
    ) throws -> DefaultDocumentationRepository {
        let url = try #require(
            URL(
                string:
                    "https://developer.apple.com/tutorials/data/documentation/swift/string.json"))
        let client = DefaultAppleDocumentationClient(
            logger: Logger(label: "test") { _ in SwiftLogNoOpLogHandler() },
            dependencies: HTTPTestTransport(responses: [url: .http(data: data)])
        )
        return DefaultDocumentationRepository(logger: logger, dependencies: client)
    }
}
