struct BundledAgentSkill: Sendable {
    let name: String
    let shortDescription: String
    let content: String
}

enum BundledAgentSkills {
    static let all = [
        BundledAgentSkill(
            name: "apple-docs",
            shortDescription: "Retrieve Apple Developer documentation for known API types.",
            content: appleDocsContent
        )
    ]

    static func skill(named name: String) -> BundledAgentSkill? {
        all.first { $0.name == name }
    }

    private static let appleDocsContent = """
        ---
        name: apple-docs
        description: >-
          Access Apple Developer documentation for known API types with the apple-docs CLI. Use when a user asks about
          an Apple framework type, its declaration, availability, inheritance, conformances, members, or raw DocC data.
        ---

        # Apple Docs

        Use `apple-docs` to retrieve current Apple Developer documentation for a known type and technology.

        ## Retrieve type documentation

        Pass the exact type and framework names. The command is stateless, so always include the technology.

        ```bash
        apple-docs types view MXHangDiagnostic --technology MetricKit
        ```

        The text output includes the type summary, declaration, availability, inheritance, conformances, documented
        members, related APIs, and canonical Apple Developer URL. Use a returned slash-separated path, or a dotted
        Swift type name, to retrieve nested documentation:

        ```bash
        apple-docs types view URLSession.AsyncBytes --technology Foundation
        ```

        ## Discover root types

        List the symbols referenced directly by a technology's root DocC page:

        ```bash
        apple-docs types list --technology MetricKit
        apple-docs types list --technology MetricKit --json
        ```

        Apple's root pages are curated and may link to collection pages instead of listing every API directly.

        Search the root page and its recursively linked collection groups by symbol name or path:

        ```bash
        apple-docs types search Button --technology SwiftUI
        ```

        Search does not crawl individual symbol pages. Collection pages may directly expose some nested members, but
        search is not an exhaustive nested-member index.

        ## Retrieve raw DocC JSON

        Use `--json` when structured data is needed or when the text renderer omits a field from Apple's response.

        ```bash
        apple-docs types view MXHangDiagnostic --technology MetricKit --json
        ```

        Treat the JSON as Apple's upstream DocC representation. Field availability can vary between documentation pages.

        ## Errors

        If the command reports an HTTP error, verify the technology and type spelling against the canonical
        documentation URL before retrying. Do not assume that similarly named types belong to the same framework.
        """
}
