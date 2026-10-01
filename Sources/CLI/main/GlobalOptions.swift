import ArgumentParser

struct GlobalOptions: ParsableArguments {
    @Flag(help: "Show debug and higher-level logs (buffered in interactive mode).")
    var verbose = false
}

protocol GlobalOptionsProviding {
    var global: GlobalOptions { get }
}
