import Dispatch
import SwiftTUIRuntime

#if canImport(Darwin)
    import Darwin
#else
    import Glibc
#endif

final class TerminalSignals: SignalReading {
    private struct Registration {
        let number: Int32
        var previous: sigaction
        let source: any DispatchSourceSignal
    }

    struct InstallationError: Error {
        let signal: Int32
        let code: Int32
    }

    private let stream = AsyncStream<String>.makeStream()
    private var registrations: [Registration] = []

    @MainActor init() async throws {
        do {
            for (number, name) in [(SIGWINCH, "SIGWINCH"), (SIGINT, "SIGINT"), (SIGTERM, "SIGTERM")] {
                var ignored = sigaction()
                sigemptyset(&ignored.sa_mask)
                #if canImport(Darwin)
                    ignored.__sigaction_u.__sa_handler = SIG_IGN
                #else
                    ignored.__sigaction_handler.sa_handler = SIG_IGN
                #endif
                var previous = sigaction()
                guard sigaction(number, &ignored, &previous) == 0 else {
                    throw InstallationError(signal: number, code: errno)
                }
                let source = DispatchSource.makeSignalSource(signal: number, queue: .main)
                let continuation = stream.continuation
                source.setEventHandler { continuation.yield(name) }
                registrations.append(Registration(number: number, previous: previous, source: source))
                await withCheckedContinuation { ready in
                    source.setRegistrationHandler { ready.resume() }
                    source.activate()
                }
                try Task.checkCancellation()
            }
        } catch {
            close()
            throw error
        }
    }

    deinit { close() }

    func events() -> AsyncStream<String> { stream.stream }

    func close() {
        for var registration in registrations.reversed() {
            registration.source.cancel()
            _ = sigaction(registration.number, &registration.previous, nil)
        }
        registrations.removeAll()
        stream.continuation.finish()
    }
}
