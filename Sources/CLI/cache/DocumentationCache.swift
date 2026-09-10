import Foundation

#if DEBUG
    protocol DocumentationCache {
        var currentDiskUsage: Int { get }

        func removeAllCachedResponses()
    }

    extension URLCache: DocumentationCache {}
#else
    typealias DocumentationCache = URLCache
#endif
