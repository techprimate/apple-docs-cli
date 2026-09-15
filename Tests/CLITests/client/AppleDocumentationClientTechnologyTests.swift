import Foundation
import Logging
import Testing

@testable import CLI

@Suite("Apple documentation technology client")
struct AppleDocumentationClientTechnologyTests {
    @Test("fetches technologies from every catalog group")
    func fetchesTechnologies() async throws {
        // -- Arrange --
        let expectedURL = try #require(
            URL(string: "https://developer.apple.com/tutorials/data/documentation/technologies.json")
        )
        let transport = HTTPTestTransport(responses: [expectedURL: .http(data: technologyCatalogData)])
        let client = DefaultAppleDocumentationClient(
            logger: Logger(label: "test") { _ in SwiftLogNoOpLogHandler() },
            dependencies: transport
        )

        // -- Act --
        let technologies = try await client.fetchTechnologies()

        // -- Assert --
        #expect(
            technologies
                == [
                    Technology(
                        name: "MetricKit",
                        identifier: "doc://com.apple.documentation/documentation/MetricKit"
                    ),
                    Technology(
                        name: "Human Interface Guidelines",
                        identifier: "doc://com.apple.documentation/design/human-interface-guidelines"
                    ),
                ]
        )
    }
}

private let technologyCatalogData = Data(
    """
    {
      "hierarchy": {},
      "identifier": {"url": "doc://com.apple.documentation/documentation/technologies"},
      "kind": "technologies",
      "legalNotices": {},
      "metadata": {"role": "overview", "title": "Technologies"},
      "references": {},
      "schemaVersion": {"major": 0, "minor": 3, "patch": 0},
      "sections": [
        {
          "kind": "technologies",
          "groups": [
            {
              "name": "System",
              "technologies": [
                {
                  "content": [],
                  "destination": {
                    "identifier": "doc://com.apple.documentation/documentation/MetricKit",
                    "isActive": true,
                    "type": "reference"
                  },
                  "languages": ["occ", "swift"],
                  "tags": ["Diagnostics", "System"],
                  "title": "MetricKit"
                }
              ]
            },
            {
              "name": "Design",
              "technologies": [
                {
                  "content": [],
                  "destination": {
                    "identifier": "doc://com.apple.documentation/design/human-interface-guidelines",
                    "isActive": true,
                    "type": "reference"
                  },
                  "languages": ["swift"],
                  "tags": ["Design"],
                  "title": "Human Interface Guidelines"
                }
              ]
            }
          ]
        }
      ]
    }
    """.utf8
)
