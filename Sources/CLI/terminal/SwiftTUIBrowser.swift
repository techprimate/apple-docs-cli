#if DEBUG
    @MainActor protocol DocumentationBrowser {
        func run(entry: BrowserEntry) async throws
    }
#else
    typealias DocumentationBrowser = DefaultDocumentationBrowser
#endif

@MainActor
struct DefaultDocumentationBrowser {
    let repository: DocumentationRepository
    let logs: SessionLogBuffer
    let opener: ExternalURLOpener
    let session: TerminalSession

    func run(entry: BrowserEntry) async throws {
        let opener = opener
        let coordinator = BrowserCoordinator(
            repository: repository, entry: entry,
            openExternal: { url in
                try await opener.open(url)
            })
        try await session.run(coordinator: coordinator, logs: logs)
    }
}

#if DEBUG
    extension DefaultDocumentationBrowser: DocumentationBrowser {}
#endif
