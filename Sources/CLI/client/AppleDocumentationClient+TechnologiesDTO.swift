struct TechnologyCatalogPageDTO: Decodable, Sendable {
    let sections: [TechnologyCatalogSectionDTO]
}

struct TechnologyCatalogSectionDTO: Decodable, Sendable {
    let groups: [TechnologyCatalogGroupDTO]
}

struct TechnologyCatalogGroupDTO: Decodable, Sendable {
    let technologies: [TechnologyCatalogItemDTO]
}

struct TechnologyCatalogItemDTO: Decodable, Sendable {
    let destination: TechnologyCatalogDestinationDTO
    let title: String
}

struct TechnologyCatalogDestinationDTO: Decodable, Sendable {
    let identifier: String
}
