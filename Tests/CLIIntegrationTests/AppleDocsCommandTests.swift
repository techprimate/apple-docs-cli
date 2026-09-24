import Foundation
import Testing

@Suite("CLI subprocess capture")
struct AppleDocsCommandTests {
    @Test("captures stdout and stderr separately and disables telemetry")
    func capturesSeparateStreams() throws {
        // -- Arrange --
        let script = "printf '%s' \"$TELEMETRY_DISABLED\"; printf '%s' diagnostics >&2"
        var diagnostics = ""

        // -- Act --
        let output = try runAppleDocs(
            ["-c", script], executablePath: "/bin/sh", captureStandardError: { diagnostics = $0 })

        // -- Assert --
        #expect(output == "true")
        #expect(diagnostics == "diagnostics")
    }

    @Test("drains large stderr while stdout is still open")
    func drainsBothPipes() throws {
        // -- Arrange --
        // The watchdog turns a pipe deadlock into an ordinary subprocess failure.
        let script = """
            parent=$$
            (sleep 10; kill -TERM "$parent") >/dev/null 2>&1 &
            watchdog=$!
            trap 'kill "$watchdog" 2>/dev/null' EXIT
            dd if=/dev/zero bs=1024 count=256 >&2 2>/dev/null
            printf complete
            """
        var diagnostics = ""

        // -- Act --
        let output = try runAppleDocs(
            ["-c", script], executablePath: "/bin/sh", captureStandardError: { diagnostics = $0 })

        // -- Assert --
        #expect(output == "complete")
        #expect(diagnostics.utf8.count == 262_144)
    }

    @Test("reports nonzero exit status and stderr")
    func reportsFailure() throws {
        // -- Arrange --
        let script = "printf '%s' failure >&2; exit 7"

        // -- Act --
        do {
            _ = try runAppleDocs(["-c", script], executablePath: "/bin/sh")
            Issue.record("Expected a subprocess failure")
        } catch AppleDocsCommandError.failed(let status, let stderr) {
            // -- Assert --
            #expect(status == 7)
            #expect(stderr == "failure")
        }
    }
}
