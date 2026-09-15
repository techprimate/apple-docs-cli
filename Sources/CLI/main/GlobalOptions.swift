import ArgumentParser

struct GlobalOptions: ParsableArguments {
    @Flag(help: "Show debug and higher-level logs on stderr.")
    var verbose = false
}

protocol GlobalOptionsProviding {
    var global: GlobalOptions { get }
}
