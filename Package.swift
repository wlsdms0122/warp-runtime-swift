// swift-tools-version: 6.3

import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "Warp",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "Warp", targets: ["Warp"]),
        .library(name: "WarpSyntax", targets: ["WarpSyntax"]),
        .library(name: "WarpStandard", targets: ["WarpStandard"]),
        .library(name: "WarpMacros", targets: ["WarpMacros"])
    ],
    traits: [
        .trait(name: "Macros", description: "Builds WarpMacros, the one product that depends on swift-syntax.")
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "604.0.0")
    ],
    targets: [
        // The language as Swift holds it: the constructs a program is made of,
        // and checking, linking and running them. No dependencies and no
        // `Decodable`. A module of native procedures a host lends needs only
        // this.
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
        // key names which construct, and the way back out. The wire is written
        // and read without learning what the tree means. A caller that reads bytes needs it, and
        // so does one that links `Module.standard`.
        .target(
            name: "WarpSyntax",
            dependencies: [
                "Warp"
            ]
        ),
        // Macros that write a host's `ValueRepresentable` and
        // `ProcedureConvertible` conformances from its Swift declarations. The
        // only target that reaches swift-syntax, and only under the `Macros`
        // trait, so a host that leaves the trait off depends on none of it.
        .target(
            name: "WarpMacros",
            dependencies: [
                "Warp",
                "WarpMacrosPlugin"
            ]
        ),
        .macro(
            name: "WarpMacrosPlugin",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax", condition: .when(traits: ["Macros"])),
                .product(name: "SwiftSyntaxBuilder", package: "swift-syntax", condition: .when(traits: ["Macros"])),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax", condition: .when(traits: ["Macros"]))
            ]
        ),
        // What the tests say the same way: the entry a test runs from and how
        // it runs against the standard vocabulary, the expressions a test
        // writes by hand, the native procedures a test declares, and a value
        // with one place of it replaced, over every place it holds. Built the
        // way a host builds against the products, so it reaches only what they
        // make public.
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
            name: "WarpMacrosTests",
            dependencies: [
                "Warp",
                "WarpMacros",
                "WarpMacrosPlugin",
                "WarpTestSupport",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax", condition: .when(traits: ["Macros"]))
            ]
        ),
        // The specification's cases, run through the doors a host has, with
        // the support's mutator for the cases that damage an object.
        .testTarget(
            name: "WarpConformanceTests",
            dependencies: [
                "Warp",
                "WarpSyntax",
                "WarpStandard",
                "WarpTestSupport"
            ]
        )
    ],
    swiftLanguageModes: [.v6]
)
