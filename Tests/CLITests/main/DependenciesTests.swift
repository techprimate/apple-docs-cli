import Foundation
import Testing

@testable import CLI

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

@Suite("Dependencies")
struct DependenciesTests {
    @Test("separate dependency instances own separate transports and caches")
    func isolatesInstances() throws {
        // -- Arrange --
        let first = Dependencies()
        let second = Dependencies()

        // -- Act --
        let firstCache = try #require(first.documentationCache)
        let secondCache = try #require(second.documentationCache)

        // -- Assert --
        #expect(first.httpDataTransport !== second.httpDataTransport)
        #expect(firstCache !== secondCache)
        #expect(firstCache === first.httpDataTransport.configuration.urlCache)
        #expect(secondCache === second.httpDataTransport.configuration.urlCache)
    }

    @Test("uses a dedicated large documentation cache")
    func usesDedicatedDocumentationCache() throws {
        // -- Arrange --
        let dependencies = Dependencies.shared
        let session = dependencies.httpDataTransport

        // -- Act --
        let cache = try #require(session.configuration.urlCache)
        let documentationCache = try #require(dependencies.documentationCache)

        // -- Assert --
        #expect(session !== URLSession.shared)
        #expect(cache === documentationCache)
        #expect(cache.diskCapacity == 1_000_000_000)
    }
}
