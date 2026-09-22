import Foundation
import Synchronization
import Testing

@testable import CLI

@Suite("External browser boundary")
struct ExternalURLOpenerTests {
    @Test func passesTheEntireURLAsOneArgumentWithoutAShell() async throws {
        // -- Arrange --
        let directory = try makeLauncherDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let calls = Mutex<[(URL, [String])]>([])
        let opener = DefaultExternalURLOpener(
            environment: ["PATH": directory.path],
            launch: { executable, arguments in
                calls.withLock { $0.append((executable, arguments)) }
            })
        let url = try #require(URL(string: "https://example.com/path?q=$(echo+hello)&name='quoted'"))

        // -- Act --
        try await opener.open(url)

        // -- Assert --
        let recorded = calls.withLock { $0 }
        #expect(recorded.count == 1)
        #expect(recorded.first?.1 == [url.absoluteString])
        #if os(macOS)
            #expect(recorded.first?.0.path == "/usr/bin/open")
        #else
            #expect(recorded.first?.0 == directory.appendingPathComponent("xdg-open"))
        #endif
    }

    @Test(arguments: [
        "file:///tmp/example", "javascript:alert(1)", "ftp://example.com/file",
        "https://user:password@example.com", "https://example.com/%0A",
    ])
    func rejectsUnsafeURLsBeforeLaunching(_ raw: String) async throws {
        // -- Arrange --
        let launches = Mutex(0)
        let opener = DefaultExternalURLOpener(launch: { _, _ in launches.withLock { $0 += 1 } })
        let url = try #require(URL(string: raw))

        // -- Act --
        await #expect(throws: ExternalOpeningError.invalidURL) { try await opener.open(url) }

        // -- Assert --
        #expect(launches.withLock { $0 } == 0)
    }

    @Test func propagatesLauncherFailure() async throws {
        // -- Arrange --
        let directory = try makeLauncherDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let opener = DefaultExternalURLOpener(
            environment: ["PATH": directory.path],
            launch: { _, _ in throw ExternalOpeningError.failed(status: 7) })
        let url = try #require(URL(string: "https://example.com"))

        // -- Act --
        let result = await #expect(throws: ExternalOpeningError.failed(status: 7)) { try await opener.open(url) }

        // -- Assert --
        #expect(result != nil)
    }

    private func makeLauncherDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let executable = directory.appendingPathComponent("xdg-open")
        try #require(
            FileManager.default.createFile(
                atPath: executable.path, contents: Data(), attributes: [.posixPermissions: 0o700]))
        return directory
    }

    #if os(Linux)
        @Test func missingPATHDoesNotInventAnExecutable() async throws {
            // -- Arrange --
            let opener = DefaultExternalURLOpener(
                environment: ["PATH": ""],
                launch: { _, _ in
                    Issue.record("No executable should be launched")
                })
            let url = try #require(URL(string: "https://example.com"))

            // -- Act --
            let error = await #expect(throws: ExternalOpeningError.unavailable) { try await opener.open(url) }

            // -- Assert --
            #expect(error != nil)
        }
    #endif
}
