import Foundation
import Testing

@testable import CLI

@Suite("Text type documentation renderer")
struct TextTypeDocumentationRendererTests {
    @Test("renders the type summary and declaration")
    func rendersSummaryAndDeclaration() throws {
        // -- Arrange --
        let data = Data(
            """
            {
              "abstract": [{"text": "An object representing a diagnostic report.", "type": "text"}],
              "metadata": {
                "modules": [{"name": "MetricKit"}],
                "platforms": [],
                "roleHeading": "Class",
                "symbolKind": "class",
                "title": "MXHangDiagnostic"
              },
              "primaryContentSections": [{
                "declarations": [{
                  "languages": ["swift"],
                  "platforms": ["iOS"],
                  "tokens": [
                    {"kind": "keyword", "text": "class"},
                    {"kind": "text", "text": " "},
                    {"kind": "identifier", "text": "MXHangDiagnostic"}
                  ]
                }],
                "kind": "declarations"
              }],
              "references": {}
            }
            """.utf8
        )
        let page = try JSONDecoder().decode(TypeDocumentationPageDTO.self, from: data)

        // -- Act --
        let output = TextTypeDocumentationRenderer().render(page)

        // -- Assert --
        #expect(
            output == """
                MXHangDiagnostic
                ━━━━━━━━━━━━━━━━
                Class · MetricKit

                  An object representing a diagnostic report.

                Declaration
                ───────────
                  ╭─ Swift ────────────────╮
                  │ class MXHangDiagnostic │
                  ╰────────────────────────╯
                """
        )
    }

    @Test("renders referenced deprecation guidance")
    func rendersDeprecationGuidance() throws {
        // -- Arrange --
        let data = Data(
            """
            {
              "abstract": [],
              "deprecationSummary": [{
                "inlineContent": [
                  {"text": "Use ", "type": "text"},
                  {
                    "identifier": "doc://com.apple.metrickit/documentation/MetricKit/HangDiagnostic",
                    "isActive": true,
                    "type": "reference"
                  },
                  {"text": " instead.", "type": "text"}
                ],
                "type": "paragraph"
              }],
              "metadata": {
                "modules": [{"name": "MetricKit"}],
                "platforms": [],
                "roleHeading": "Class",
                "symbolKind": "class",
                "title": "MXHangDiagnostic"
              },
              "primaryContentSections": [],
              "references": {
                "doc://com.apple.metrickit/documentation/MetricKit/HangDiagnostic": {
                  "kind": "symbol",
                  "role": "symbol",
                  "title": "HangDiagnostic",
                  "type": "topic",
                  "url": "/documentation/metrickit/hangdiagnostic"
                }
              }
            }
            """.utf8
        )
        let page = try JSONDecoder().decode(TypeDocumentationPageDTO.self, from: data)

        // -- Act --
        let output = TextTypeDocumentationRenderer().render(page)

        // -- Assert --
        #expect(output.contains("Deprecated\n──────────\n  Use HangDiagnostic instead."))
    }

    @Test("renders platform availability ranges")
    func rendersPlatformAvailability() throws {
        // -- Arrange --
        let data = Data(
            """
            {
              "abstract": [],
              "metadata": {
                "modules": [{"name": "MetricKit"}],
                "platforms": [
                  {"deprecatedAt": "27.0", "introducedAt": "14.0", "name": "iOS"},
                  {"introducedAt": "12.0", "name": "macOS"}
                ],
                "roleHeading": "Class",
                "symbolKind": "class",
                "title": "MXHangDiagnostic"
              },
              "primaryContentSections": [],
              "references": {}
            }
            """.utf8
        )
        let page = try JSONDecoder().decode(TypeDocumentationPageDTO.self, from: data)

        // -- Act --
        let output = TextTypeDocumentationRenderer().render(page)

        // -- Assert --
        #expect(
            output.contains(
                """
                Availability
                ────────────
                  ╭───────┬───────────╮
                  │ iOS   │ 14.0–27.0 │
                  │ macOS │ 12.0+     │
                  ╰───────┴───────────╯
                """
            )
        )
    }

    @Test("renders linked documentation sections")
    // Most of this function is the DocC fixture covering several linked section kinds.
    // swiftlint:disable:next function_body_length
    func rendersLinkedSections() throws {
        // -- Arrange --
        let data = Data(
            """
            {
              "abstract": [],
              "metadata": {
                "modules": [{"name": "MetricKit"}],
                "platforms": [],
                "roleHeading": "Class",
                "symbolKind": "class",
                "title": "MXHangDiagnostic"
              },
              "primaryContentSections": [],
              "references": {
                "doc://mxdiagnostic": {
                  "kind": "symbol",
                  "role": "symbol",
                  "title": "MXDiagnostic",
                  "type": "topic",
                  "url": "/documentation/metrickit/mxdiagnostic"
                },
                "doc://hangduration": {
                  "abstract": [{"text": "The total duration of hangs.", "type": "text"}],
                  "kind": "symbol",
                  "role": "symbol",
                  "title": "hangDuration",
                  "type": "topic",
                  "url": "/documentation/metrickit/mxhangdiagnostic/hangduration"
                },
                "doc://crash": {
                  "kind": "symbol",
                  "role": "symbol",
                  "title": "MXCrashDiagnostic",
                  "type": "topic",
                  "url": "/documentation/metrickit/mxcrashdiagnostic"
                }
              },
              "relationshipsSections": [{
                "identifiers": ["doc://mxdiagnostic"],
                "kind": "relationships",
                "title": "Inherits From",
                "type": "inheritsFrom"
              }],
              "seeAlsoSections": [{
                "identifiers": ["doc://crash"],
                "title": "Performance diagnostics"
              }],
              "topicSections": [{
                "identifiers": ["doc://hangduration"],
                "title": "Reading total app hang time"
              }]
            }
            """.utf8
        )
        let page = try JSONDecoder().decode(TypeDocumentationPageDTO.self, from: data)

        // -- Act --
        let output = TextTypeDocumentationRenderer().render(page)

        // -- Assert --
        #expect(output.contains("Inherits From\n─────────────\n  • MXDiagnostic"))
        #expect(
            output.contains(
                """
                Reading total app hang time
                ───────────────────────────
                  • hangDuration
                    The total duration of hangs.
                """
            )
        )
        #expect(output.contains("Topics\n━━━━━━"))
        #expect(output.contains("See Also\n━━━━━━━━"))
        #expect(output.contains("Performance diagnostics\n───────────────────────\n  • MXCrashDiagnostic"))
    }

    @Test("omits untitled references from documentation sections")
    func omitsUntitledReferences() throws {
        // -- Arrange --
        let data = Data(
            """
            {
              "abstract": [],
              "metadata": {
                "modules": [{"name": "Swift"}],
                "platforms": [],
                "roleHeading": "Structure",
                "symbolKind": "struct",
                "title": "String"
              },
              "primaryContentSections": [],
              "references": {
                "Swift-PageImage-card.png": {
                  "identifier": "Swift-PageImage-card.png",
                  "type": "image"
                }
              },
              "topicSections": [{
                "identifiers": ["Swift-PageImage-card.png"],
                "title": "Resources"
              }]
            }
            """.utf8
        )
        let page = try JSONDecoder().decode(TypeDocumentationPageDTO.self, from: data)

        // -- Act --
        let output = TextTypeDocumentationRenderer().render(page)

        // -- Assert --
        #expect(output == "String\n━━━━━━\nStructure · Swift")
    }
}
