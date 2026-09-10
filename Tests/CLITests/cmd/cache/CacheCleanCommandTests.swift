import Testing

@testable import CLI

@Suite("Cache clean command")
struct CacheCleanCommandTests {
    @Test("registers the cache clean command hierarchy")
    func parsesCacheCleanCommand() throws {
        // -- Arrange --
        let arguments = ["cache", "clean"]

        // -- Act --
        let command = try CLI.parseAsRoot(arguments)

        // -- Assert --
        #expect(command is CacheCleanCommand)
    }
}
