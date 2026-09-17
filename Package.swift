// swift-tools-version: 6.4

import PackageDescription

var packageDependencies: [Package.Dependency] = [
    .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.8.2"),
    .package(url: "https://github.com/apple/swift-log.git", exact: "1.15.1"),
    .package(url: "https://github.com/SwiftTUI/swift-tui.git", exact: "0.13.5"),
]
var cliDependencies: [Target.Dependency] = [
    .product(name: "ArgumentParser", package: "swift-argument-parser"),
    .product(name: "Logging", package: "swift-log"),
    .product(name: "SwiftTUIRuntime", package: "swift-tui"),
]

#if os(macOS)
    packageDependencies += [
        .package(
            url: "https://github.com/getsentry/sentry-apple-swift-log.git",
            exact: "9.28.0",
            traits: ["SentryFromSource"]
        ),
        .package(
            url: "https://github.com/getsentry/sentry-cocoa.git",
            exact: "9.28.0",
            traits: ["NoUIFramework"]
        ),
    ]
    cliDependencies += [
        .product(name: "SentrySwiftLog", package: "sentry-apple-swift-log"),
        .product(name: "SentrySPM", package: "sentry-cocoa"),
    ]
#endif

let package = Package(
    name: "apple-docs-cli",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "apple-docs", targets: ["CLI"])
    ],
    dependencies: packageDependencies,
    targets: [
        .executableTarget(
            name: "CLI",
            dependencies: cliDependencies
        ),
        .testTarget(
            name: "CLITests",
            dependencies: [
                "CLI",
                .product(name: "SwiftTUIRuntime", package: "swift-tui"),
            ]
        ),
        .testTarget(name: "CLIIntegrationTests"),
    ],
    swiftLanguageModes: [.v6]
)
