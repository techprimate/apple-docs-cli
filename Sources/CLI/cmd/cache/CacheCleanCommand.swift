import ArgumentParser

struct CacheCleanCommand: ParsableCommand, GlobalOptionsProviding {
    @OptionGroup var global: GlobalOptions

    static let configuration = CommandConfiguration(
        commandName: "clean",
        abstract: "Clear cached Apple documentation."
    )

    mutating func run() throws {
        run(telemetry: Dependencies.telemetry)
    }

    func run(telemetry: Telemetry) {
        telemetry.startCommand(.cacheClean)
        let result = CacheCleanCommandRunner(
            cache: Dependencies.documentationCache
        ).run()
        print(result.output)
    }
}
