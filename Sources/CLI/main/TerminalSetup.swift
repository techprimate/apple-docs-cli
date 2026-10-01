#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#elseif canImport(Musl)
    import Musl
#endif

struct TerminalSetup {
    func configure() {
        // Ignore SIGPIPE so writing to a closed pipe fails with EPIPE instead of terminating.
        signal(SIGPIPE, SIG_IGN)
    }
}
