import SwiftTUIRuntime
import Testing

@testable import CLI

#if canImport(Darwin)
    import Darwin
#else
    import Glibc
#endif

@Suite("Owned terminal signals", .serialized, .timeLimit(.minutes(1)))
@MainActor
struct TerminalSignalsTests {
    @Test func deliversResizeAndRestoresPreviousHandlers() async throws {
        // -- Arrange --
        let before = [SIGWINCH, SIGINT, SIGTERM, SIGSEGV, SIGABRT].map(SignalSnapshot.init)
        let signals = try await TerminalSignals()
        defer { signals.close() }
        var events = signals.events().makeAsyncIterator()

        // -- Act --
        kill(getpid(), SIGWINCH)
        let event = await events.next()
        signals.close()
        signals.close()
        let after = [SIGWINCH, SIGINT, SIGTERM, SIGSEGV, SIGABRT].map(SignalSnapshot.init)

        // -- Assert --
        #expect(event == "SIGWINCH")
        #expect(after == before)
        #expect(await events.next() == nil)
    }

    private struct SignalSnapshot: Equatable {
        let handler: UInt
        let flags: Int32
        let mask: [Int32]

        init(_ number: Int32) {
            var action = sigaction()
            _ = sigaction(number, nil, &action)
            #if canImport(Darwin)
                handler = unsafeBitCast(action.__sigaction_u.__sa_handler, to: UInt.self)
            #else
                handler = unsafeBitCast(action.__sigaction_handler.sa_handler, to: UInt.self)
            #endif
            #if os(Linux) && arch(x86_64)
                // glibc adds SA_RESTORER even when reinstalling the original sigaction unchanged.
                flags = action.sa_flags & ~0x0400_0000
            #else
                flags = action.sa_flags
            #endif
            mask = (1..<NSIG).filter { sigismember(&action.sa_mask, $0) == 1 }
        }
    }
}
