// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "Warp",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "Warp", targets: ["Warp"]),
        .library(name: "WarpSyntax", targets: ["WarpSyntax"]),
        .library(name: "WarpStandard", targets: ["WarpStandard"])
    ],
    targets: [
        // The language as Swift holds it: the constructs a program is made of,
        // and checking, linking and running them. No dependencies and no
        // `Decodable`. A caller that assembles a program in Swift against a
        // vocabulary of its own needs only this.
        .target(
            name: "Warp"
        ),
        // The standard vocabulary: arithmetic, text, collections, logic,
        // control and running at once, as procedures on top of the language.
        // Part of it is written in Warp, so it reads documents.
        .target(
            name: "WarpStandard",
            dependencies: [
                "Warp",
                "WarpSyntax"
            ]
        ),
        // What a document is: the bytes and the text one is carried in, which
        // key names which construct, the spellings a notation may write
        // instead, and the way back out. The wire is written and read without
        // learning what the tree means. A caller that reads bytes needs it, and
        // so does one that links `Module.standard`.
        .target(
            name: "WarpSyntax",
            dependencies: [
                "Warp"
            ]
        ),
        // What a value looks like with one place of it replaced, over every
        // place it holds. Shared by the core tests and the conformance runner.
        .target(
            name: "WarpMutation",
            dependencies: [
                "Warp"
            ]
        ),
        // What the core, the vocabulary's and the syntax tests say the same
        // way: the entry a test runs from and how it runs against the standard
        // vocabulary, the expressions a test writes by hand, and the native
        // procedures a test declares. Built the way a host builds against the
        // products, so it reaches only what they make public.
        .target(
            name: "WarpTestSupport",
            dependencies: [
                "Warp",
                "WarpStandard"
            ],
            path: "Tests/WarpTestSupport"
        ),
        // One test target per library. Each writes its fixtures in the form its
        // layer takes.
        .testTarget(
            name: "WarpTests",
            dependencies: [
                "Warp",
                "WarpMutation",
                "WarpStandard",
                "WarpTestSupport"
            ]
        ),
        .testTarget(
            name: "WarpStandardTests",
            dependencies: [
                "Warp",
                "WarpStandard",
                "WarpSyntax",
                "WarpTestSupport"
            ]
        ),
        .testTarget(
            name: "WarpSyntaxTests",
            dependencies: [
                "Warp",
                "WarpSyntax",
                "WarpStandard",
                "WarpTestSupport"
            ]
        ),
        .testTarget(
            name: "WarpMutationTests",
            dependencies: [
                "Warp",
                "WarpMutation"
            ]
        ),
        // The specification's cases, run through the doors a host has, with
        // `WarpMutation` for the cases that damage an object.
        .testTarget(
            name: "WarpConformanceTests",
            dependencies: [
                "Warp",
                "WarpMutation",
                "WarpSyntax",
                "WarpStandard"
            ]
        )
    ],
    swiftLanguageModes: [.v6]
)
