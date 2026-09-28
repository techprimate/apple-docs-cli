import Foundation

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

#if DEBUG
    protocol DocumentationCache {
        var currentDiskUsage: Int { get }

        func removeAllCachedResponses()
    }

    extension URLCache: DocumentationCache {}

    protocol DocumentationCacheProvider {
        associatedtype Cache: DocumentationCache
        var documentationCache: Cache? { get }
    }

    extension Dependencies: DocumentationCacheProvider {}
#else
    typealias DocumentationCache = URLCache
#endif
