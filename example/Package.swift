// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "WarpExample",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "warp", targets: ["warp"]),
        .executable(name: "warpx", targets: ["warpx"]),
        .library(name: "WarpConsole", targets: ["WarpConsole"]),
        .library(name: "WarpTime", targets: ["WarpTime"]),
        .library(name: "WarpRandom", targets: ["WarpRandom"]),
        .library(name: "WarpFile", targets: ["WarpFile"]),
        .library(name: "WarpNet", targets: ["WarpNet"]),
        .library(name: "WarpJSON", targets: ["WarpJSON"]),
        .library(name: "WarpProcess", targets: ["WarpProcess"])
    ],
    dependencies: [
        // Hosts of the runtime's build product, kept outside the package they
        // host.
        .package(path: "..")
    ],
    targets: [
        // A host that builds and runs whatever documents it is handed. What
        // it adds to the runtime is the vocabulary its modules lend; what a
        // document does with it is the document's.
        .executableTarget(
            name: "warp",
            dependencies: [
                .product(name: "Warp", package: "warp-runtime-swift"),
                .product(name: "WarpSyntax", package: "warp-runtime-swift"),
                .product(name: "WarpStandard", package: "warp-runtime-swift"),
                "WarpConsole",
                "WarpTime",
                "WarpRandom",
                "WarpFile",
                "WarpNet",
                "WarpJSON",
                "WarpProcess"
            ]
        ),
        // A host for measuring the runtime: it builds a program two ways,
        // straight from its documents and back through their objects, runs
        // both and prints each answer.
        .executableTarget(
            name: "warpx",
            dependencies: [
                .product(name: "Warp", package: "warp-runtime-swift"),
                .product(name: "WarpSyntax", package: "warp-runtime-swift"),
                .product(name: "WarpStandard", package: "warp-runtime-swift"),
                "WarpJSON"
            ]
        ),
        // Vocabulary modules a host may lend a program, one library each, so a
        // host takes the ones it means to lend and nothing else. A module is
        // the declarations a document links against and where they reach;
        // where one reaches the host it names a protocol the host's
        // environment adopts.
        .target(name: "WarpConsole", dependencies: [.product(name: "Warp", package: "warp-runtime-swift")]),
        .target(name: "WarpTime", dependencies: [.product(name: "Warp", package: "warp-runtime-swift")]),
        .target(name: "WarpRandom", dependencies: [.product(name: "Warp", package: "warp-runtime-swift")]),
        .target(name: "WarpFile", dependencies: [.product(name: "Warp", package: "warp-runtime-swift")]),
        .target(name: "WarpNet", dependencies: [.product(name: "Warp", package: "warp-runtime-swift")]),
        .target(name: "WarpJSON", dependencies: [.product(name: "Warp", package: "warp-runtime-swift")]),
        .target(name: "WarpProcess", dependencies: [.product(name: "Warp", package: "warp-runtime-swift")])
    ],
    swiftLanguageModes: [.v6]
)
