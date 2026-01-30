// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "FocusRelayMCP",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "focus-relay-mcp", targets: ["FocusRelayMCP"])
    ],
    dependencies: [
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.10.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.5.0")
    ],
    targets: [
        .target(
            name: "OmniFocusCore"
        ),
        .target(
            name: "OmniFocusAutomation",
            dependencies: ["OmniFocusCore"],
            linkerSettings: [
                .linkedFramework("OSAKit")
            ]
        ),
        .executableTarget(
            name: "FocusRelayMCP",
            dependencies: [
                "OmniFocusCore",
                "OmniFocusAutomation",
                .product(name: "MCP", package: "swift-sdk"),
                .product(name: "Logging", package: "swift-log")
            ]
        ),
        .testTarget(
            name: "OmniFocusCoreTests",
            dependencies: [
                "OmniFocusCore"
            ]
        ),
        .testTarget(
            name: "OmniFocusIntegrationTests",
            dependencies: [
                "OmniFocusAutomation",
                "OmniFocusCore"
            ]
        )
    ]
)
