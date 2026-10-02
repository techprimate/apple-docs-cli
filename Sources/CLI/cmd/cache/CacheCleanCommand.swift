import ArgumentParser

struct CacheCleanCommand: ParsableCommand, GlobalOptionsProviding {
    #if DEBUG
        typealias Deps = any (TelemetryProvider & DocumentationCacheProvider & CommandOutputWriterProvider)
    #else
        typealias Deps = Dependencies
    #endif

    @OptionGroup var global: GlobalOptions

    static let configuration = CommandConfiguration(
        commandName: "clean",
        abstract: "Clear cached Apple documentation."
    )

    mutating func run() throws {
        run(deps: Dependencies.shared)
    }

    func run(deps: Deps) {
        deps.telemetry.startCommand(.cacheClean)
        let runner = CacheCleanCommandRunner(
            cache: deps.documentationCache
        )
        let result = runner.run()
        deps.commandOutputWriter.write(result.output)
    }
}
