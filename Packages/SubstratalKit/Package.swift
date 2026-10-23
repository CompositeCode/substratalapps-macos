// swift-tools-version: 6.0
// SubstratalKit — the Hub's shared core (macOS now, iOS later): the generated
// Platform API client, request middleware, sessions, Capabilities, the screen
// catalog and routes, and the theme. The app targets hold views only.
import PackageDescription

let package = Package(
    name: "SubstratalKit",
    platforms: [.macOS(.v15), .iOS(.v18)],
    products: [
        .library(name: "SubstratalKit", targets: ["SubstratalKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-openapi-generator", from: "1.6.0"),
        .package(url: "https://github.com/apple/swift-openapi-runtime", from: "1.7.0"),
        .package(url: "https://github.com/apple/swift-openapi-urlsession", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-http-types", from: "1.3.0"),
    ],
    targets: [
        // Generated at build time from openapi.yaml (vendored by scripts/sync-openapi.sh).
        .target(
            name: "SubstratalAPI",
            dependencies: [
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
            ],
            plugins: [.plugin(name: "OpenAPIGenerator", package: "swift-openapi-generator")]
        ),
        .target(
            name: "SubstratalKit",
            dependencies: [
                "SubstratalAPI",
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
                .product(name: "OpenAPIURLSession", package: "swift-openapi-urlsession"),
                .product(name: "HTTPTypes", package: "swift-http-types"),
            ],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "SubstratalKitTests",
            dependencies: [
                "SubstratalKit",
                .product(name: "HTTPTypes", package: "swift-http-types"),
            ]
        ),
    ]
)
