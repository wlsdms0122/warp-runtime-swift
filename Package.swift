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
        .library(name: "WarpStandard", targets: ["WarpStandard"]),
    ],
    targets: [
        // The language as Swift holds it: the constructs a program is made of, and
        // everything done to them. Checking, linking and running. No
        // dependencies and no `Decodable`, because a language
        // that can decode itself has confused itself with one of its notations.
        //
        // A caller that builds these directly needs this and nothing
        // else. That is what a front end with a syntax of its own does, and
        // what running a program that never travels takes.
        .target(
            name: "Warp"
        ),
        // The vocabulary a program sends to: arithmetic, text, collections,
        // logic, control and running at once. Procedures on top of the language
        // rather than part of it, and the dependency graph is where that is
        // said rather than claimed. `Value` belongs to the language, so a
        // procedure here cannot ask for a representation of its own, and the
        // language learns a procedure only through the contract a caller hands
        // it.
        .target(
            name: "WarpStandard",
            dependencies: [
                "Warp"
            ]
        ),
        // What a document is: the bytes and the text one is carried in, which
        // key names which construct, the spellings a notation may write
        // instead, and the way back out. Data in, the language's own values out.
        //
        // Optional, and the dependency graph is where that is said rather than
        // claimed. A program travels as a document, so this is what a program
        // comes through to leave one machine and arrive at another.
        //
        // The wire is written and read without learning what the tree means, so
        // an implementation in another language can speak it without also
        // implementing what a procedure is. The line this package is cut on is
        // what a caller can leave out: a caller that reads bytes needs all of
        // this, and a caller assembling a program in Swift needs none of it.
        .target(
            name: "WarpSyntax",
            dependencies: [
                "Warp"
            ]
        ),
        // One test target per target, and the dependencies are the point: a test
        // that cannot import the syntax can only be saying something about the
        // language. Where a behaviour is tested is then a fact anyone reads off
        // the imports rather than a claim. Each layer writes its own fixtures,
        // in the form that layer takes.
        .testTarget(
            name: "WarpTests",
            dependencies: [
                "Warp",
                "WarpStandard"
            ]
        ),
        // The vocabulary's own tests reach the language too: a record under a
        // nominal name is made where the link makes one, and no public door
        // spells one, so the fixtures come from inside. Declared rather than
        // taken through the target below it, so the imports stay the fact
        // this package reads them as.
        .testTarget(
            name: "WarpStandardTests",
            dependencies: [
                "Warp",
                "WarpStandard"
            ]
        ),
        .testTarget(
            name: "WarpSyntaxTests",
            dependencies: [
                "WarpSyntax",
                "WarpStandard"
            ]
        ),
        // The specification's cases, run against this implementation. It imports
        // what any caller imports and nothing more: a runner that could see
        // inside would pass by agreeing with the implementation rather than
        // with the specification.
        .testTarget(
            name: "WarpConformanceTests",
            dependencies: [
                "Warp",
                "WarpSyntax",
                "WarpStandard"
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
