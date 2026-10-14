import Testing

@Suite("Browser application integration")
@MainActor
struct BrowserApplicationTests {
    @Test("Enter has no action and arrows reveal focused buttons", .timeLimit(.minutes(1)))
    func navigatesButtons() async throws {
        // -- Arrange --
        let terminal = try BrowserTerminal(client: .sequential)

        // -- Act --
        let screens = try await terminal.run([
            .init("Item00", keys: [0x0D, 0x1B, 0x5B, 0x43, 0x1B, 0x5B, 0x43, 0x1B, 0x5B, 0x43]),
            .init("Item03"),
        ])

        // -- Assert --
        #expect(screens[1].contains("Apple Docs CLI"))
        #expect(!screens[1].contains("Item00"))
        #expect(screens[1].contains("Item03"))
    }

    @Test("page down reveals grid rows outside the viewport", .timeLimit(.minutes(1)))
    func scrollsGrid() async throws {
        // -- Arrange --
        let terminal = try BrowserTerminal(client: .sequential)

        // -- Act --
        let screens = try await terminal.run([
            .init("Item00", keys: [0x1B, 0x5B, 0x36, 0x7E]),
            .init("Item03"),
        ])

        // -- Assert --
        #expect(screens[0].contains("Item00"))
        #expect(!screens[0].contains("Item03"))
        #expect(screens[1].contains("Item03"))
        #expect(!screens[1].contains("Item00"))
    }

    @Test("navigation hints stay visible while jumping between grid edges", .timeLimit(.minutes(1)))
    func showsNavigationFooter() async throws {
        // -- Arrange --
        let terminal = try BrowserTerminal(client: .edges)

        // -- Act --
        let screens = try await terminal.run([
            .init("First", keys: Array("G".utf8)),
            .init("Last"),
        ])

        // -- Assert --
        for screen in screens {
            #expect(screen.split(separator: "\n").last == "Arrows: Move  g/G: Top/Bottom")
        }
    }

    @Test("g and G jump to the first and last grid rows", .timeLimit(.minutes(1)))
    func jumpsToGridEdges() async throws {
        // -- Arrange --
        let terminal = try BrowserTerminal(client: .edges)

        // -- Act --
        let screens = try await terminal.run([
            .init("First", keys: Array("G".utf8)),
            .init("Last", keys: Array("g".utf8)),
            .init("First"),
        ])

        // -- Assert --
        #expect(screens[0].contains("First"))
        #expect(!screens[0].contains("Last"))
        #expect(screens[1].contains("Last"))
        #expect(!screens[1].contains("First"))
        #expect(screens[2].contains("First"))
        #expect(!screens[2].contains("Last"))
    }
}
