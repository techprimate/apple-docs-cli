import Foundation

extension DefaultAppleDocumentationClient {
    func searchTypes(query: String, technology: String) async throws -> [DocumentationType] {
        logger.debug(
            "Searching documentation types",
            metadata: [
                "query": .string(query), "apple_docs.technology": .string(technology),
            ])
        let root = try await fetchDocumentationRoot(technology: technology)
        let matches = try await searchTypes(query: query, root: root)
        logger.info(
            "Documentation search completed",
            metadata: [
                "apple_docs.technology": .string(root.name), "matches": .stringConvertible(matches.count),
            ])
        return matches
    }

    private func searchTypes(query: String, root: DocumentationRoot) async throws -> [DocumentationType] {
        let rootPath = "/documentation/\(root.slug.lowercased())"
        logger.debug("Traversing documentation collection groups", metadata: ["path": .string(rootPath)])
        var typesByPath: [String: DocumentationType] = [:]
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
            let batch = Array(pendingPaths.prefix(6))
            pendingPaths.removeFirst(batch.count)
            logger.trace(
                "Dequeued collection group batch",
                metadata: [
                    "batch_size": .stringConvertible(batch.count), "pending": .stringConvertible(pendingPaths.count),
                ])
            let pages = await fetchDocumentationPages(paths: batch)

            for page in pages {
                for type in documentationTypes(in: page, technology: root.slug) {
                    typesByPath[type.path] = type
                }
                for path in collectionGroupPaths(in: page, technology: root.slug)
                where visitedPaths.insert(path).inserted {
                    pendingPaths.append(path)
                }
            }
        }

        let normalizedQuery = query.lowercased()
        let matches = sortTypes(
            typesByPath.values.filter {
                $0.name.lowercased().contains(normalizedQuery)
                    || $0.path.lowercased().contains(normalizedQuery)
            }
        )
        guard !matches.isEmpty else {
            logger.notice(
                "No matching documentation types",
                metadata: [
                    "query": .string(query), "apple_docs.technology": .string(root.name),
                    "candidates": .stringConvertible(typesByPath.count),
                ])
            throw Error.typeSearchNoResults(
                query: query,
                technology: root.name,
                technologyURL: root.url
            )
        }
        return matches
    }

    private func fetchDocumentationPages(
        paths: [String]
    ) async -> [TechnologyDocumentationPageDTO] {
        logger.debug("Fetching collection group batch", metadata: ["count": .stringConvertible(paths.count)])
        return await withTaskGroup(
            of: TechnologyDocumentationPageDTO?.self,
            returning: [TechnologyDocumentationPageDTO].self
        ) { group in
            for path in paths {
                group.addTask {
                    do {
                        return try await fetchDocumentationPage(path: path)
                    } catch {
                        let cancelled = error is CancellationError || (error as? URLError)?.code == .cancelled
                        logger.log(
                            level: cancelled ? .debug : .warning, "Skipping unavailable collection group",
                            metadata: [
                                "path": .string(path), "error_type": .string(String(reflecting: type(of: error))),
                            ])
                        return nil
                    }
                }
            }

            var pages: [TechnologyDocumentationPageDTO] = []
            for await page in group {
                if let page {
                    pages.append(page)
                }
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
