import Foundation
import Logging
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
        let first = makeDependencies()
        let second = makeDependencies()

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
        let dependencies = makeDependencies()
        let session = dependencies.httpDataTransport

        // -- Act --
        let cache = try #require(session.configuration.urlCache)
        let documentationCache = try #require(dependencies.documentationCache)

        // -- Assert --
        #expect(session !== URLSession.shared)
        #expect(cache === documentationCache)
        #expect(cache.diskCapacity == 1_000_000_000)
    }

    private func makeDependencies() -> Dependencies {
        Dependencies(
            telemetry: DefaultTelemetry(
                logger: { Logger(label: "test") { _ in SwiftLogNoOpLogHandler() } },
                environment: ["TELEMETRY_DISABLED": "true"]
            )
        )
    }
}
