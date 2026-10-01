struct Technology: Codable, Equatable, Identifiable, Sendable {
    let name: String
    let identifier: String

    var id: String { identifier }
}
