// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "WarpBench",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        // A consumer of the runtime's build product, kept outside the package
        // it measures: it imports what any host imports and nothing more.
        .package(path: "../..")
    ],
    targets: [
        .executableTarget(
            name: "WarpBench",
            dependencies: [
                .product(name: "Warp", package: "warp-runtime-swift"),
                .product(name: "WarpSyntax", package: "warp-runtime-swift"),
                .product(name: "WarpStandard", package: "warp-runtime-swift")
            ]
        )
    ],
    swiftLanguageModes: [.v6]
)
