import Foundation
import Testing
import Twill

@testable import CLI

#if canImport(Darwin)
    import Darwin
#else
    import Glibc
#endif

@MainActor
struct BrowserTerminal {
    struct Step {
        let visible: String
        let keys: [UInt8]

        init(_ visible: String, keys: [UInt8] = []) {
            self.visible = visible
            self.keys = keys
        }
    }

    private let host: FileHandle
    private let terminal: FileHandle
    private let pipe = Pipe()
    private let runLoop = DefaultRunLoop()
    private let columns = 48
    private let rows = 6
    private let client: BrowserCatalogFixture

    init(client: BrowserCatalogFixture) throws {
        var hostDescriptor: Int32 = -1
        var terminalDescriptor: Int32 = -1
        try #require(openpty(&hostDescriptor, &terminalDescriptor, nil, nil, nil) == 0)
        host = FileHandle(fileDescriptor: hostDescriptor, closeOnDealloc: true)
        terminal = FileHandle(fileDescriptor: terminalDescriptor, closeOnDealloc: true)
        var size = winsize(ws_row: 6, ws_col: 48, ws_xpixel: 0, ws_ypixel: 0)
        try #require(ioctl(terminalDescriptor, TIOCSWINSZ, &size) == 0)
        self.client = client
    }

    func run(_ steps: [Step]) async throws -> [String] {
        let reader = DefaultInputSource(fileDescriptor: .custom(pipe.fileHandleForReading.fileDescriptor))
        let application = Application(
            rootView: BrowserView(client: client),
            runLoop: runLoop,
            terminalSession: DefaultTerminalSession(
                fileDescriptor: .custom(terminal.fileDescriptor),
                output: DefaultTerminalOutput(fileDescriptor: .custom(pipe.fileHandleForWriting.fileDescriptor))
            ),
            terminalViewport: DefaultTerminalViewport(fileDescriptor: .custom(terminal.fileDescriptor))
        )
        runLoop.add(Twill.Timer(interval: .seconds(3)) { application.stop() })
        reader.start()
        let task = Task {
            try await application.run()
            try pipe.fileHandleForWriting.close()
        }
        defer { task.cancel() }
        var output = Data()
        var screens: [String] = []

        do {
            for try await bytes in reader.events {
                output.append(contentsOf: bytes)
                guard let text = String(bytes: output, encoding: .utf8) else { continue }
                let screen = BrowserTerminalScreen.render(text, columns: columns, rows: rows)
                guard screens.count < steps.count, screen.contains(steps[screens.count].visible) else { continue }
                let step = steps[screens.count]
                screens.append(screen)
                if step.keys.isEmpty { break }
                try host.write(contentsOf: Data(step.keys))
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
        try #require(screens.count == steps.count, "Expected \(steps.count) screens, got \(screens.count): \(screens)")
        return screens
    }
}

struct BrowserCatalogFixture: TechnologyCatalogClient {
    let technologies: [Technology]

    static var sequential: Self {
        Self(
            technologies: (0..<30).map {
                Technology(name: String(format: "Item%02d", $0), identifier: "item\($0)")
            })
    }

    static var edges: Self {
        Self(
            technologies: (0..<30).map { index in
                Technology(
                    name: index == 0 ? "First" : index == 29 ? "Last" : "Item\(index)",
                    identifier: "item\(index)")
            })
    }

    func fetchTechnologies() async throws -> [Technology] { technologies }
}
