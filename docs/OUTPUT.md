# Output formats and JSON

Documentation commands select audience and format independently. Human text, agent Markdown, and JSON derive from shared presentations of normalized documentation content.

## Audience and format selection

| Flags            | Audience | Format                        |
| ---------------- | -------- | ----------------------------- |
| No output flags  | Human    | Text or discovery tables      |
| `--json`         | Human    | JSON                          |
| `--agent`        | Agent    | Markdown                      |
| `--agent --json` | Agent    | JSON with navigation commands |

All commands print once and exit, including when stdin and stdout are terminals. There is no interactive browser or `--non-interactive` flag. Flag order does not matter. These output options belong to `types view`, `types list`, `types search`, `technologies list`, and every support catalog or content command, not to cache or skill commands.

Successful output goes to stdout. Errors, partial-search warnings, and requested verbose diagnostics go to stderr. Unhandled command failures exit nonzero. JSON stdout contains only the structured result, without terminal escape sequences or progress messages.

```bash
apple-docs types view String --technology Swift
apple-docs types view String --technology Swift --agent
apple-docs types view String --technology Swift --json
apple-docs types view String --technology Swift --agent --json
apple-docs support view --path support/fee-waiver --agent --json
```

## Human and agent content

Human text uses section headings, declarations, availability tables, prose, and grouped references. Agent Markdown uses predictable headings, explicit technology and path information, and copyable follow-up commands. Agent output does not deliberately summarize or remove content to save tokens.

Support text also preserves available lists, code, tables, images, and notices. Agent Markdown escapes literal text and uses safe code and link delimiters. JSON retains table-cell spans and named anchors that need not have an identical text representation.

Parity means the representations share normalized content. It does not promise support for every upstream DocC field or identical fields in every output format. Missing normalized content is not evidence that Apple supplies no such content.

For DocC APIs, agent navigation uses supported CLI commands, explicit technology arguments, `--agent`, and shell-quoted values. Technology roots use `types list`. Representable document paths use `types view`. External or unavailable targets have no CLI navigation command.

Named CLI input interprets dots as hierarchy separators and lowercases paths. Normalized documentation links preserve Apple's path spelling and punctuation. The presenter omits follow-up commands for paths that cannot round-trip through named input rather than fabricating a command. Dash-prefixed operands use the argument terminator (`--`).

For support resources, agent navigation selects catalog, guide-contents, glossary, terms-entry, or document commands and quotes their identifiers. Follow-up commands are generated only for recognized destinations. Other links remain references, including PDFs and unsupported pages. A generated command still depends on the source page retaining a supported layout.

## DocC JSON result shapes

There is no versioned envelope. DocC page and search output are objects. Symbol and technology catalogs are top-level arrays.

### Pages

`types view --json` exposes these top-level fields:

| Fields                               | Meaning                                                          |
| ------------------------------------ | ---------------------------------------------------------------- |
| `title`, `kind`                      | Display title and page/symbol kind                               |
| `technology`, `path`, `url`          | Technology slug, full documentation path, and canonical URL      |
| `modules`                            | Module names                                                     |
| `abstract`                           | Semantic summary as inline records                               |
| `deprecation`                        | Deprecation content as blocks                                    |
| `declarations`                       | Objects with `text` and a `languages` array                      |
| `availability`                       | Platform metadata, including version and availability qualifiers |
| `content`                            | Ordered body blocks                                              |
| `relationships`, `topics`, `seeAlso` | Ordered reference groups                                         |

Groups contain `id`, `title`, and `references`. References contain `id`, `title`, `kind`, `abstract`, and a validated `target`. Agent JSON adds `navigation` to representable page, discovery-result, or grouped-reference destinations.

Availability entries contain `name`, `isBeta`, and `isUnavailable`. Version strings `introducedAt`, `deprecatedAt`, and `obsoletedAt` are included when supplied. The boolean fields are present even when false.

Array-valued fields remain arrays when empty. Inapplicable optional fields are omitted. JSON is pretty-printed with sorted keys and unescaped forward slashes. Consumers should parse keys and values rather than rely on field ordering or whitespace.

### Semantic content and links

Inline records contain `type` and `text`. Types are `text`, `code`, and `link`. A link also contains `target`.

| Block `type`    | Content fields                          |
| --------------- | --------------------------------------- |
| `paragraph`     | `inlineContent` array of inline records |
| `heading`       | `text`                                  |
| `codeListing`   | `code` line array and optional `syntax` |
| `orderedList`   | `items` and `startIndex`                |
| `unorderedList` | `items`                                 |
| `aside`         | `content`, `style`, and optional `name` |

Each list item is an array of blocks. An aside's `content` is also an array of blocks, so nested content retains its structure.

Targets use a `type` of `documentation`, `external`, or `unavailable`. Documentation targets contain `technology`, full `path`, `url`, and an optional `fragment`. External targets contain `url`. Unavailable targets retain `label` rather than an executable destination.

### Discovery results

- `types list`: an array of objects with `name`, `kind`, technology-relative `path`, and `url`.
- `types search`: an object with resolved `technology`, a `types` array with those same symbol fields, and `coverage`.
- `technologies list`: a case-insensitively sorted array of objects with `name` and `identifier`.
- Agent variants additionally include `navigation` where supported. Navigation contains `technology`, a technology-relative `path` for document destinations, and `command`. Technology-root navigation omits `path`.

No search matches is a successful result with an empty `types` array, not an error. Search coverage contains `isComplete` and `unavailableCollections`. Each unavailable collection contains `path` and `kind`: `http` with `status`, `transport` with a URL error `code`, `invalidResponse`, or `decoding`.

Completeness refers to the reachable curated collection graph, not an exhaustive index of every symbol. Partial results remain usable and also emit a warning to stderr. Unexpected failures abort the search. Human text reports no matches explicitly. Cancellation stops the search rather than returning partial results.

## Support JSON result shapes

Every support result is an object with a `kind` discriminator. Catalogs retain their source hierarchy rather than flattening into DocC symbol arrays.

| Command                   | `kind`            | Payload fields                                                                     |
| ------------------------- | ----------------- | ---------------------------------------------------------------------------------- |
| `support articles list`   | `articlesCatalog` | `header`, `categories`                                                             |
| `support guides list`     | `helpCatalog`     | `header`, `featuredResources`, `topicsTitle`, `topics`, `glossary`                 |
| `support guides contents` | `guideContents`   | `header`, `entries`                                                                |
| `support glossary list`   | `glossary`        | `header`, `entries`                                                                |
| `support glossary view`   | `glossaryEntry`   | `term`, `definition`                                                               |
| `support terms list`      | `termsCatalog`    | `header`, `categories`                                                             |
| `support terms view`      | `termsEntry`      | `id`, `title`, `description`, `resources`                                          |
| `support view`            | `article`         | `url`, `title`, optional `context`, `breadcrumbs`, `content`, `related`, `notices` |

A header contains `url`, `title`, and `introduction`. Page links contain `title` and `url`, not DocC `target` records. Described links contain a `link` and a `summary`.

Agent JSON additionally contains a `navigation` array, which may be empty. Each navigation entry has `title`, `command`, and an optional `url`. Human JSON omits `navigation`. Glossary and terms-entry selectors can generate commands without a URL.

### Catalog hierarchy and document resources

- Article categories contain `id`, `title`, `summary`, and `links`.
- Help topics contain `title` and `groups`. Each group has `links` and an optional `title`. Featured resources and the glossary use described links.
- Guide entries contain `title`, an optional `link`, and recursively nested `children`.
- Glossary entries contain `term` and a `definition` array of support content blocks.
- Terms categories contain `id`, `title`, block-valued `introduction`, and `entries`. Each entry has `id`, `title`, inline-valued `description`, and `resources`.
- A terms resource has a `link` and an optional `translations` object. That object contains block-valued `notice`, optional `lastUpdatedLabel`, and a `translations` array of page links. Translation groups belong to their individual resource, not the entire catalog entry.

Category filters use source identifiers. Glossary queries match term names, not definition text. Empty glossary matches return an empty `entries` array. Unknown category identifiers, missing terms, and unsupported layouts fail rather than returning an unrelated result.

Terms output describes public document resources. It does not include the linked legal document text or establish account-specific acceptance. Supported HTML landing pages can expose notices without containing the agreement itself. PDFs and unknown layouts are not parsed.

### Rich support content

Support inline records have their own schema:

| Inline `type`                       | Fields                           |
| ----------------------------------- | -------------------------------- |
| `text`, `code`                      | `text`                           |
| `emphasis`, `strong`, `superscript` | Recursive `content` inline array |
| `link`                              | Inline `label` array and `url`   |
| `image`                             | `url`, `alt`                     |
| `anchor`                            | `name`, inline `content`         |
| `lineBreak`                         | No additional fields             |

Support blocks retain ordered structure:

| Block `type`  | Fields                             |
| ------------- | ---------------------------------- |
| `paragraph`   | Inline `content`                   |
| `heading`     | `level`, `text`, optional `anchor` |
| `list`        | `ordered`, `start`, `items`        |
| `codeListing` | String `text`, optional `syntax`   |
| `aside`       | `style`, block `content`           |
| `table`       | `rows`                             |
| `image`       | `url`, `alt`, inline `caption`     |
| `separator`   | No additional fields               |

Each list item is an array of blocks. Table rows contain `cells`; each cell has block-valued `content`, `isHeader`, `columnSpan`, and `rowSpan`. Inline images can appear inside links, paragraphs, lists, or table cells.

Articles retain available canonical URLs, ordered breadcrumbs, related page links, and substantive footer notices. Breadcrumbs contain `title` and an optional `url`. Named anchors are represented by inline `anchor` records or heading `anchor` fields. Optional fields are omitted when absent; array fields remain arrays when empty.

### Reading structured results

Parse JSON with a tool such as [jq](https://jqlang.org/), installed separately:

```bash
apple-docs types view String --technology Swift --json | jq -r '.title'
apple-docs support guides contents --name app-store-connect --json | jq -r '.entries[].title'
apple-docs support terms view --name apple-developer-program-license-agreement --json | jq -r '.resources[].link.url'
```

JSON contains normalized semantic content, not original DocC bytes or raw HTML. There is no raw-document export flag, and a missing normalized field is not evidence that Apple supplies no such information.

See [Development](DEVELOPMENT.md) for verification commands and [Telemetry](TELEMETRY.md) for the separate diagnostic-upload policy.
