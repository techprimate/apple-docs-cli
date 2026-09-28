enum TelemetryMetric: Sendable {
    case technologyCatalog(count: Int)
    case typeCatalog(count: Int)
    case typeSearch(matches: Int)
    case typeView(responseBytes: Int)
}
