import Foundation
import Testing
import Twill

@testable import CLI

#if canImport(Darwin)
    import Darwin
#else
    import Glibc
#endif

@Suite("Technology browser")
struct BrowserViewTests {
    @Test("browser scrolls to technologies below the terminal viewport", .timeLimit(.minutes(1)))
    @MainActor
    func scrollsGrid() async throws {
        // -- Arrange --
        var hostDescriptor: Int32 = -1
        var applicationDescriptor: Int32 = -1
        try #require(openpty(&hostDescriptor, &applicationDescriptor, nil, nil, nil) == 0)
        let host = FileHandle(fileDescriptor: hostDescriptor, closeOnDealloc: true)
        let terminal = FileHandle(fileDescriptor: applicationDescriptor, closeOnDealloc: true)
        var size = winsize(ws_row: 6, ws_col: 48, ws_xpixel: 0, ws_ypixel: 0)
        try #require(ioctl(applicationDescriptor, TIOCSWINSZ, &size) == 0)
        let pipe = Pipe()
        let reader = DefaultInputSource(fileDescriptor: .custom(pipe.fileHandleForReading.fileDescriptor))
        let client = BrowserTestClient.fixture
        let runLoop = DefaultRunLoop()
        let application = makeBrowserApplication(client: client, terminal: terminal, pipe: pipe, runLoop: runLoop)
        runLoop.add(Twill.Timer(interval: .seconds(3)) { application.stop() })
        var unhandledKeys: [KeyEvent] = []
        application.onKeyEvent = { unhandledKeys.append($0) }
        reader.start()
        let task = Task {
            try await application.run()
            try pipe.fileHandleForWriting.close()
        }
        defer { task.cancel() }
        var output = ""
        var sentScroll = false
        var sawNextRow = false

        // -- Act --
        do {
            for try await bytes in reader.events {
                output += try #require(String(bytes: bytes, encoding: .utf8))
                if !sentScroll, output.contains("Item00") {
                    sentScroll = true
                    try host.write(contentsOf: Data([0x1B, 0x5B, 0x36, 0x7E]))
                }
                if sentScroll, output.contains("Item06") {
                    sawNextRow = true
                    break
                }
            }
            application.stop()
            try await task.value
        } catch {
            task.cancel()
            _ = await task.result
            await reader.stop()
            throw error
        }
        await reader.stop()

        // -- Assert --
        #expect(sentScroll)
        #expect(sawNextRow, "Unhandled keys: \(unhandledKeys), terminal output: \(output)")
    }

    @Test("g and G jump to the first and last grid rows", .timeLimit(.minutes(1)))
    @MainActor
    func jumpsToGridEdges() async throws {
        // -- Arrange --
        var hostDescriptor: Int32 = -1
        var applicationDescriptor: Int32 = -1
        try #require(openpty(&hostDescriptor, &applicationDescriptor, nil, nil, nil) == 0)
        let host = FileHandle(fileDescriptor: hostDescriptor, closeOnDealloc: true)
        let terminal = FileHandle(fileDescriptor: applicationDescriptor, closeOnDealloc: true)
        var size = winsize(ws_row: 6, ws_col: 48, ws_xpixel: 0, ws_ypixel: 0)
        try #require(ioctl(applicationDescriptor, TIOCSWINSZ, &size) == 0)
        let pipe = Pipe()
        let reader = DefaultInputSource(fileDescriptor: .custom(pipe.fileHandleForReading.fileDescriptor))
        let client = BrowserTestClient.edgeFixture
        let runLoop = DefaultRunLoop()
        let application = makeBrowserApplication(client: client, terminal: terminal, pipe: pipe, runLoop: runLoop)
        runLoop.add(Twill.Timer(interval: .seconds(3)) { application.stop() })
        reader.start()
        let task = Task {
            try await application.run()
            try pipe.fileHandleForWriting.close()
        }
        defer { task.cancel() }
        var output = ""
        var sentBottom = false
        var sentTop = false
        var returnedToTop = false

        // -- Act --
        do {
            for try await bytes in reader.events {
                output += try #require(String(bytes: bytes, encoding: .utf8))
                if !sentBottom, output.contains("First") {
                    sentBottom = true
                    try host.write(contentsOf: Data("G".utf8))
                }
                if sentBottom, !sentTop, output.contains("Last") {
                    sentTop = true
                    try host.write(contentsOf: Data("g".utf8))
                } else if sentTop, output.components(separatedBy: "First").count > 2 {
                    returnedToTop = true
                    break
                }
            }
            application.stop()
            try await task.value
        } catch {
            task.cancel()
            _ = await task.result
            await reader.stop()
            throw error
        }
        await reader.stop()

        // -- Assert --
        #expect(sentBottom)
        #expect(sentTop)
        #expect(returnedToTop, "Terminal output: \(output)")
    }

    @Test("technology identity remains stable when its display name changes")
    func technologyIdentity() {
        // -- Arrange --
        let original = Technology(name: "SwiftUI", identifier: "swiftui")
        let renamed = Technology(name: "SwiftUI Framework", identifier: "swiftui")

        // -- Act --
        let originalID = original.id
        let renamedID = renamed.id

        // -- Assert --
        #expect(originalID == "swiftui")
        #expect(originalID == renamedID)
    }
}

@MainActor
private func makeBrowserApplication(
    client: BrowserTestClient, terminal: FileHandle, pipe: Pipe, runLoop: DefaultRunLoop
) -> Application {
    Application(
        rootView: BrowserView(client: client),
        runLoop: runLoop,
        terminalSession: DefaultTerminalSession(
            fileDescriptor: .custom(terminal.fileDescriptor),
            output: DefaultTerminalOutput(fileDescriptor: .custom(pipe.fileHandleForWriting.fileDescriptor))
        ),
        terminalViewport: DefaultTerminalViewport(fileDescriptor: .custom(terminal.fileDescriptor))
    )
}

private struct BrowserTestClient: TechnologyCatalogClient {
    let technologies: [Technology]

    static var fixture: Self {
        Self(
            technologies: (0..<30).map {
                Technology(name: String(format: "Item%02d", $0), identifier: "item\($0)")
            })
    }

    static var edgeFixture: Self {
        Self(
            technologies: (0..<30).map { index in
                Technology(
                    name: index == 0 ? "First" : index == 29 ? "Last" : "Item\(index)",
                    identifier: "item\(index)")
            })
    }

    func fetchTechnologies() async throws -> [Technology] {
        technologies
    }
}
