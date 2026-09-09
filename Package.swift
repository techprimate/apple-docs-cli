// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "apple-docs-cli",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "apple-docs", targets: ["CLI"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.8.2"),
        .package(url: "https://github.com/apple/swift-log.git", exact: "1.15.1"),
        .package(
            url: "https://github.com/getsentry/sentry-apple-swift-log.git",
            exact: "9.27.0",
            traits: ["SentryFromSource"]
        ),
        .package(
            url: "https://github.com/getsentry/sentry-cocoa.git",
            exact: "9.27.0",
            traits: ["NoUIFramework"]
        ),
    ],
    targets: [
        .executableTarget(
            name: "CLI",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "SentrySwiftLog", package: "sentry-apple-swift-log"),
                .product(name: "SentrySPM", package: "sentry-cocoa"),
            ]),
        .testTarget(name: "CLITests", dependencies: ["CLI"]),
        .testTarget(name: "CLIIntegrationTests"),
    ],
    swiftLanguageModes: [.v6]
)
