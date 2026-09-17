struct NavigatorNodeID: Hashable, Sendable {
    let components: [String]
}

struct NavigatorSnapshot: Equatable, Sendable {
    var expandedIDs: Set<NavigatorNodeID> = []
    var selectedID: NavigatorNodeID?
    var topRow = 0
}
