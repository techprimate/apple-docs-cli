import Foundation

extension DefaultAppleDocumentationClient {
    func searchTypes(query: String, technology: String) async throws -> DocumentationSearchResult {
        let root = try await fetchDocumentationRoot(technology: technology)
        return try await searchDocumentation(query: query, root: root)
    }

    private func searchDocumentation(query: String, root: DocumentationRoot) async throws -> DocumentationSearchResult {
        try Task.checkCancellation()
        let rootPath = "/documentation/\(root.slug.lowercased())"
        logger.debug("Traversing documentation collection groups", metadata: ["path": .string(rootPath)])
        var typesByPath: [String: DocumentationType] = [:]
        var unavailablePaths: [String] = []
        for type in documentationTypes(in: root.page, technology: root.slug) {
            typesByPath[type.path] = type
        }
        var visitedPaths = Set([rootPath])
        var pendingPaths = collectionGroupPaths(in: root.page, technology: root.slug).filter {
            visitedPaths.insert($0).inserted
        }

        // Collection groups form a small curated graph. Batching limits pressure on Apple's service
        // while avoiding the thousands of requests required to crawl every individual symbol page.
        while !pendingPaths.isEmpty {
            try Task.checkCancellation()
            let batch = Array(pendingPaths.prefix(6))
            pendingPaths.removeFirst(batch.count)
            logger.trace(
                "Dequeued collection group batch",
                metadata: [
                    "batch_size": .stringConvertible(batch.count), "pending": .stringConvertible(pendingPaths.count),
                ])
            let pages = try await fetchDocumentationPages(paths: batch)

            for result in pages {
                guard case .page(let page) = result else {
                    if case .unavailable(let path) = result { unavailablePaths.append(path) }
                    continue
                }
                for type in documentationTypes(in: page, technology: root.slug) {
                    typesByPath[type.path] = type
                }
                for path in collectionGroupPaths(in: page, technology: root.slug)
                where visitedPaths.insert(path).inserted {
                    pendingPaths.append(path)
                }
            }
        }

        try Task.checkCancellation()
        return searchResult(
            query: query, root: root, types: Array(typesByPath.values), unavailablePaths: unavailablePaths)
    }

    private func searchResult(
        query: String, root: DocumentationRoot, types: [DocumentationType], unavailablePaths: [String]
    ) -> DocumentationSearchResult {
        logger.debug(
            "Documentation search coverage",
            metadata: [
                "apple_docs.technology": .string(root.slug), "candidates": .stringConvertible(types.count),
                "unavailable": .stringConvertible(unavailablePaths.count),
            ])
        let normalizedQuery = query.lowercased()
        let matches = sortTypes(
            types.filter {
                $0.name.lowercased().contains(normalizedQuery)
                    || $0.path.lowercased().contains(normalizedQuery)
            }
        )
        if matches.isEmpty {
            logger.notice(
                "No matching documentation types",
                metadata: [
                    "query": .string(query), "apple_docs.technology": .string(root.name),
                    "candidates": .stringConvertible(types.count),
                ])
        }
        logger.info(
            "Documentation search completed",
            metadata: [
                "apple_docs.technology": .string(root.name), "matches": .stringConvertible(matches.count),
            ])
        return DocumentationSearchResult(types: matches, unavailableCollectionPaths: unavailablePaths.sorted())
    }

    private enum CollectionResult: Sendable {
        case page(TechnologyDocumentationPageDTO)
        case unavailable(String)
    }

    private func fetchDocumentationPages(
        paths: [String]
    ) async throws -> [CollectionResult] {
        logger.debug("Fetching collection group batch", metadata: ["count": .stringConvertible(paths.count)])
        return try await withThrowingTaskGroup(of: CollectionResult.self) { group in
            for path in paths {
                group.addTask {
                    do {
                        return .page(try await fetchDocumentationPage(path: path))
                    } catch {
                        if error is CancellationError || (error as? URLError)?.code == .cancelled {
                            throw CancellationError()
                        }
                        logger.warning(
                            "Skipping unavailable collection group",
                            metadata: [
                                "path": .string(path), "error_type": .string(String(reflecting: type(of: error))),
                            ])
                        return .unavailable(path)
                    }
                }
            }

            var pages: [CollectionResult] = []
            for try await page in group {
                pages.append(page)
            }
            logger.debug(
                "Fetched collection group batch",
                metadata: [
                    "requested": .stringConvertible(paths.count), "received": .stringConvertible(pages.count),
                ])
            return pages
        }
    }

    private func collectionGroupPaths(
        in page: TechnologyDocumentationPageDTO,
        technology: String
    ) -> [String] {
        let pathPrefix = "/documentation/\(technology.lowercased())/"
        let paths: [String] = page.references.values.compactMap { reference in
            guard
                reference.role == "collectionGroup",
                let path = reference.url,
                path.lowercased().hasPrefix(pathPrefix)
            else {
                return nil
            }
            return path
        }
        logger.trace(
            "Filtered collection group paths",
            metadata: [
                "references": .stringConvertible(page.references.count), "count": .stringConvertible(paths.count),
            ])
        return paths
    }
}
