import Foundation

struct CacheCleanCommandRunner {
    struct Result {
        let clearedByteCount: Int?
        let output: String
    }

    private let cache: DocumentationCache?

    init(cache: DocumentationCache?) {
        self.cache = cache
    }

    func run() -> Result {
        guard let cache else {
            return Result(
                clearedByteCount: nil,
                output: "Apple documentation cache is unavailable."
            )
        }

        let clearedByteCount = cache.currentDiskUsage
        cache.removeAllCachedResponses()
        let formattedByteCount = ByteCountFormatter.string(
            fromByteCount: Int64(clearedByteCount),
            countStyle: .file
        )
        return Result(
            clearedByteCount: clearedByteCount,
            output: "Cleared \(formattedByteCount) of cached Apple documentation."
        )
    }
}
