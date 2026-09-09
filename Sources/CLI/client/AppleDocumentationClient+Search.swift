extension DefaultAppleDocumentationClient {
    func searchTypes(query: String, technology: String) async throws -> [DocumentationType] {
        var slug = technology
        var displayName = technology
        var technologyURL = "https://developer.apple.com/documentation/\(technology.lowercased())"
        let rootPage: TechnologyDocumentationPageDTO

        do {
            rootPage = try await fetchDocumentationPage(
                path: "/documentation/\(technology.lowercased())"
            )
        } catch Error.httpStatus(404) {
            let resolved = try await resolveTechnology(named: technology)
            guard let resolvedSlug = resolved.documentationSlug else {
                throw Error.unsupportedTechnology(name: resolved.name, url: resolved.url)
            }
            slug = resolvedSlug
            displayName = resolved.name
            technologyURL = resolved.url
            rootPage = try await fetchDocumentationPage(
                path: "/documentation/\(resolvedSlug.lowercased())"
            )
        }

        return try await searchTypes(
            query: query,
            documentationSlug: slug,
            displayName: displayName,
            technologyURL: technologyURL,
            rootPage: rootPage
        )
    }

    private func searchTypes(
        query: String,
        documentationSlug: String,
        displayName: String,
        technologyURL: String,
        rootPage: TechnologyDocumentationPageDTO
    ) async throws -> [DocumentationType] {
        let rootPath = "/documentation/\(documentationSlug.lowercased())"
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
        await withTaskGroup(
            of: TechnologyDocumentationPageDTO?.self,
            returning: [TechnologyDocumentationPageDTO].self
        ) { group in
            for path in paths {
                group.addTask {
                    do {
                        return try await fetchDocumentationPage(path: path)
                    } catch {
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
            return pages
        }
    }

    private func collectionGroupPaths(
        in page: TechnologyDocumentationPageDTO,
        technology: String
    ) -> [String] {
        let pathPrefix = "/documentation/\(technology.lowercased())/"
        return page.references.values.compactMap { reference in
            guard
                reference.role == "collectionGroup",
                let path = reference.url,
                path.lowercased().hasPrefix(pathPrefix)
            else {
                return nil
            }
            return path
        }
    }
}
