import Foundation
import Testing

@testable import CLI

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

@Suite("Dependencies")
struct DependenciesTests {
    @Test("uses a dedicated large documentation cache")
    func usesDedicatedDocumentationCache() throws {
        // -- Arrange --
        let session = Dependencies.httpDataTransport

        // -- Act --
        let cache = try #require(session.configuration.urlCache)
        let documentationCache = try #require(Dependencies.documentationCache)

        // -- Assert --
        #expect(session !== URLSession.shared)
        #expect(cache === documentationCache)
        #expect(cache.diskCapacity == 1_000_000_000)
    }
}
