import Testing

@testable import CLI

@Suite("Cache clean command runner")
struct CacheCleanCommandRunnerTests {
    @Test("clears cached responses and reports their disk usage")
    func clearsCache() {
        // -- Arrange --
        let cache = TestDocumentationCache(currentDiskUsage: 5_000_000)
        let runner = CacheCleanCommandRunner(cache: cache)

        // -- Act --
        let result = runner.run()

        // -- Assert --
        #expect(cache.isEmpty)
        #expect(result.clearedByteCount == 5_000_000)
        #expect(result.output == "Cleared 5 MB of cached Apple documentation.")
    }

    @Test("reports when no cache is available")
    func reportsUnavailableCache() {
        // -- Arrange --
        let runner = CacheCleanCommandRunner(cache: nil)

        // -- Act --
        let result = runner.run()

        // -- Assert --
        #expect(result.clearedByteCount == nil)
        #expect(result.output == "Apple documentation cache is unavailable.")
    }
}

private final class TestDocumentationCache: DocumentationCache {
    private(set) var currentDiskUsage: Int

    var isEmpty: Bool {
        currentDiskUsage == 0
    }

    init(currentDiskUsage: Int) {
        self.currentDiskUsage = currentDiskUsage
    }

    func removeAllCachedResponses() {
        currentDiskUsage = 0
    }
}
