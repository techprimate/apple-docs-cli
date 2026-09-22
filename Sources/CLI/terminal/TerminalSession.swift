import Logging
import SwiftTUIRuntime

@MainActor
struct TerminalSession {
    let surface: any PresentationSurface
    let input: any TerminalInputReading
    var signals: (any SignalReading)?
    var logger = Logger(label: "apple-docs.terminal")

    var issueSink: RuntimeIssueSink {
        RuntimeIssueSink { issue in
            logger.log(
                level: issue.severity == .error ? .error : .warning,
                "\(issue.message)", metadata: ["code": .string(issue.code)])
        }
    }

    private struct Snapshot: Equatable, Sendable {
        var browser: BrowserState
        var logs: [SessionLogEntry]
    }

    func run(coordinator: BrowserCoordinator, logs: SessionLogBuffer) async throws {
        let identity = Identity(components: ["documentation-browser"])
        let container = StateContainer(
            initialState: Snapshot(browser: coordinator.state, logs: logs.snapshot()),
            invalidationIdentities: [identity])
        coordinator.onChange = { state in container.mutate { $0.browser = state } }
        let logChanges = Task {
            for await _ in logs.changes {
                guard !Task.isCancelled else { break }
                container.mutate { $0.logs = logs.snapshot() }
            }
        }
        defer {
            logChanges.cancel()
            coordinator.onChange = nil
            coordinator.stop()
        }
        let runtime = SwiftTUIRuntime.RunLoop(
            rootIdentity: identity, presentationSurface: surface, terminalInputReader: input,
            signalReader: signals, stateContainer: container,
            focusTracker: FocusTracker(invalidationIdentities: [identity]), exitKeyBindings: .none,
            viewBuilder: { snapshot, _ in
                BrowserView(
                    state: snapshot.browser, logs: snapshot.logs,
                    model: DocumentationViewportModel(
                        state: snapshot.browser, terminalWidth: surface.surfaceSize.width),
                    readState: { coordinator.state }, send: coordinator.send)
            })
        runtime.runtimeIssueSink = issueSink
        coordinator.start()
        _ = try await runtime.run()
    }
}
