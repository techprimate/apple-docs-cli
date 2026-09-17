enum BrowserEntryReducer {
    static func reduce(state: inout BrowserState, action: BrowserAction) -> [BrowserEffect] {
        switch action {
        case .start: return start(state: &state)
        case .ensureRoot(let technology): return root(technology, state: &state)
        case .retryRoot(let technology):
            let canonical = state.canonicalTechnology(technology)
            guard state.catalog.rootErrors.removeValue(forKey: canonical) != nil else { return [] }
            return root(technology, state: &state)
        case .rootLoaded, .rootFailed: completeRoot(state: &state, action: action)
        case .typesLoaded, .typesFailed: completeTypes(state: &state, action: action)
        case .technologiesLoaded, .technologiesFailed: completeTechnologies(state: &state, action: action)
        default: break
        }
        return []
    }

    private static func completeTechnologies(state: inout BrowserState, action: BrowserAction) {
        switch action {
        case .technologiesLoaded(let requestID, let technologies):
            guard state.catalog.pendingTechnologiesID == requestID else { return }
            state.catalog.pendingTechnologiesID = nil
            state.catalog.technologies = technologies
            state.catalog.technologiesError = nil
        case .technologiesFailed(let requestID, let message):
            guard state.catalog.pendingTechnologiesID == requestID else { return }
            state.catalog.pendingTechnologiesID = nil
            state.catalog.technologiesError = message
        default: break
        }
    }

    static func retryCatalog(state: inout BrowserState) -> [BrowserEffect] {
        switch state.currentLocation {
        case .types(let technology):
            let canonical = state.canonicalTechnology(technology)
            guard state.catalog.typeErrors.removeValue(forKey: canonical) != nil else { return [] }
            state.nextRequestID += 1
            state.catalog.pendingTypes[canonical] = state.nextRequestID
            return [.loadTypes(requestID: state.nextRequestID, technology: canonical)]
        case .technologies:
            guard state.catalog.technologiesError != nil else { return [] }
            state.catalog.technologiesError = nil
            state.nextRequestID += 1
            state.catalog.pendingTechnologiesID = state.nextRequestID
            return [.loadTechnologies(requestID: state.nextRequestID)]
        default: return []
        }
    }

    static func register(_ technology: String, canonical: String, state: inout BrowserState) {
        let alias = technology.lowercased()
        guard alias != canonical else { return }
        state.catalog.aliases[alias] = canonical
        if var search = state.technologySearches.removeValue(forKey: alias) {
            search.technology = canonical
            state.technologySearches[canonical] = search
        }
        if let types = state.catalog.types.removeValue(forKey: alias) { state.catalog.types[canonical] = types }
        if case .types(let current) = state.currentLocation, current.lowercased() == alias {
            state.currentLocation = .types(technology: canonical)
            if let snapshot = state.snapshot { state.history.updateCurrent(snapshot) }
        }
    }

    static func clearCancelled(_ requestID: UInt64, state: inout BrowserState) {
        state.catalog.pendingRoots = state.catalog.pendingRoots.filter { $0.value != requestID }
        state.catalog.pendingTypes = state.catalog.pendingTypes.filter { $0.value != requestID }
        if state.catalog.pendingTechnologiesID == requestID { state.catalog.pendingTechnologiesID = nil }
    }

    private static func start(state: inout BrowserState) -> [BrowserEffect] {
        switch state.entry {
        case .type(let name, let technology):
            return BrowserReducer.reduce(state: &state, action: .openNamed(name: name, technology: technology))
                + root(technology, state: &state)
        case .types(let technology): return types(technology, state: &state)
        case .technologies:
            state.currentLocation = .technologies
            if let snapshot = state.snapshot { state.history.visit(snapshot) }
            state.nextRequestID += 1
            state.catalog.pendingTechnologiesID = state.nextRequestID
            return [.loadTechnologies(requestID: state.nextRequestID)]
        case .search(let query, let technology):
            var effects = types(technology, state: &state)
            effects += SearchReducer.reduceBrowser(state: &state, action: .showSearch)
            effects += SearchReducer.reduceBrowser(state: &state, action: .editQuery(query))
            effects += SearchReducer.reduceBrowser(state: &state, action: .submitSearch)
            return effects
        }
    }

    private static func types(_ technology: String, state: inout BrowserState) -> [BrowserEffect] {
        let canonical = state.canonicalTechnology(technology)
        state.currentLocation = .types(technology: canonical)
        if let snapshot = state.snapshot { state.history.visit(snapshot) }
        state.nextRequestID += 1
        state.catalog.pendingTypes[technology.lowercased()] = state.nextRequestID
        return [.loadTypes(requestID: state.nextRequestID, technology: technology)] + root(technology, state: &state)
    }

    private static func root(_ technology: String, state: inout BrowserState) -> [BrowserEffect] {
        let canonical = state.canonicalTechnology(technology)
        guard state.technologyNavigators[canonical]?.roots.isEmpty != false,
            state.catalog.rootErrors[canonical] == nil,
            !state.catalog.pendingRoots.keys.contains(where: { state.canonicalTechnology($0) == canonical })
        else { return [] }
        state.nextRequestID += 1
        state.catalog.pendingRoots[technology.lowercased()] = state.nextRequestID
        return [.loadRoot(requestID: state.nextRequestID, technology: technology)]
    }

    private static func completeRoot(state: inout BrowserState, action: BrowserAction) {
        switch action {
        case .rootLoaded(let requestID, let technology, let loaded):
            guard state.catalog.pendingRoots[technology.lowercased()] == requestID else { return }
            state.catalog.pendingRoots.removeValue(forKey: technology.lowercased())
            let canonical = loaded.page.destination.technology
            register(technology, canonical: canonical, state: &state)
            state.catalog.rootErrors.removeValue(forKey: canonical)
            var navigator = state.technologyNavigators[canonical] ?? NavigatorState()
            NavigatorReducer.installRoot(loaded.page, state: &navigator)
            state.technologyNavigators[canonical] = navigator
        case .rootFailed(let requestID, let technology, let message):
            guard state.catalog.pendingRoots[technology.lowercased()] == requestID else { return }
            state.catalog.pendingRoots.removeValue(forKey: technology.lowercased())
            state.catalog.rootErrors[state.canonicalTechnology(technology)] = message
        default: break
        }
    }

    private static func completeTypes(state: inout BrowserState, action: BrowserAction) {
        switch action {
        case .typesLoaded(let requestID, let technology, let types):
            guard state.catalog.pendingTypes[technology.lowercased()] == requestID else { return }
            state.catalog.pendingTypes.removeValue(forKey: technology.lowercased())
            let canonical = state.canonicalTechnology(technology)
            state.catalog.types[canonical] = types
            state.catalog.typeErrors.removeValue(forKey: canonical)
        case .typesFailed(let requestID, let technology, let message):
            guard state.catalog.pendingTypes[technology.lowercased()] == requestID else { return }
            state.catalog.pendingTypes.removeValue(forKey: technology.lowercased())
            state.catalog.typeErrors[state.canonicalTechnology(technology)] = message
        default: break
        }
    }
}
