import Testing

@testable import CLI

@Suite("Technology browser")
struct BrowserViewTests {
    @Test("technology identity remains stable when its display name changes")
    func technologyIdentity() {
        // -- Arrange --
        let original = Technology(name: "SwiftUI", identifier: "swiftui")
        let renamed = Technology(name: "SwiftUI Framework", identifier: "swiftui")

        // -- Act --
        let originalID = original.id
        let renamedID = renamed.id

        // -- Assert --
        #expect(originalID == "swiftui")
        #expect(originalID == renamedID)
    }
}
