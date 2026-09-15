import Foundation

extension DefaultAppleDocumentationClient {
    func searchTypes(query: String, technology: String) async throws -> [DocumentationType] {
        logger.debug(
            "Searching documentation types",
            metadata: [
                "query": .string(query), "apple_docs.technology": .string(technology),
            ])
        var slug = technology
        var displayName = technology
        var technologyURL = "https://developer.apple.com/documentation/\(technology.lowercased())"
        let rootPage: TechnologyDocumentationPageDTO

        do {
            rootPage = try await fetchDocumentationPage(
                path: "/documentation/\(technology.lowercased())"
            )
        } catch Error.httpStatus(404) {
            logger.debug("Search root not found, resolving technology")
            let resolved = try await resolveTechnology(named: technology)
            guard let resolvedSlug = resolved.documentationSlug else {
                logger.notice("Technology has no searchable documentation root")
                throw Error.unsupportedTechnology(name: resolved.name, url: resolved.url)
            }
            slug = resolvedSlug
            displayName = resolved.name
            technologyURL = resolved.url
            logger.debug("Retrying search with canonical technology", metadata: ["slug": .string(resolvedSlug)])
            rootPage = try await fetchDocumentationPage(
                path: "/documentation/\(resolvedSlug.lowercased())"
            )
        }

        let matches = try await searchTypes(
            query: query,
            documentationSlug: slug,
            displayName: displayName,
            technologyURL: technologyURL,
            rootPage: rootPage
        )
        logger.info(
            "Documentation search completed",
            metadata: [
                "apple_docs.technology": .string(displayName), "matches": .stringConvertible(matches.count),
            ])
        return matches
    }

    private func searchTypes(
        query: String,
        documentationSlug: String,
        displayName: String,
        technologyURL: String,
        rootPage: TechnologyDocumentationPageDTO
    ) async throws -> [DocumentationType] {
        let rootPath = "/documentation/\(documentationSlug.lowercased())"
        logger.debug("Traversing documentation collection groups", metadata: ["path": .string(rootPath)])
        var typesByPath: [String: DocumentationType] = [:]
        for type in documentationTypes(in: rootPage, technology: documentationSlug) {
            typesByPath[type.path] = type
        }
        var visitedPaths = Set([rootPath])
        var pendingPaths = collectionGroupPaths(in: rootPage, technology: documentationSlug).filter {
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
                for type in documentationTypes(in: page, technology: documentationSlug) {
                    typesByPath[type.path] = type
                }
                for path in collectionGroupPaths(in: page, technology: documentationSlug)
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
                    "query": .string(query), "apple_docs.technology": .string(displayName),
                    "candidates": .stringConvertible(typesByPath.count),
                ])
            throw Error.typeSearchNoResults(
                query: query,
                technology: displayName,
                technologyURL: technologyURL
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
