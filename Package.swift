// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "apple-docs-cli",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "apple-docs", targets: ["CLI"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.8.2")
    ],
    targets: [
        .executableTarget(
            name: "CLI",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]),
        .testTarget(name: "CLITests", dependencies: ["CLI"]),
        .testTarget(name: "CLIIntegrationTests"),
    ],
    swiftLanguageModes: [.v6]
)
