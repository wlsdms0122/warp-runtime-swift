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
        .library(name: "WarpSerialization", targets: ["WarpSerialization"]),
    ],
    targets: [
        // The language as Swift holds it: the shapes a program is made of, and
        // everything done to them — checking, linking, running, and the standard
        // vocabulary. No dependencies and no `Decodable`, because a language
        // that can decode itself has confused itself with one of its notations.
        //
        // A caller that builds these shapes directly needs this and nothing
        // else. That is not a trick — it is how a front end with a syntax of its
        // own works, and how a program that never travels is run.
        .target(
            name: "Warp"
        ),
        // What the words mean: which key names which shape, the spellings a
        // document may write instead, and the way back out. It takes the tree a
        // serialization hands over and answers with the language's own shapes.
        //
        // Optional, and the dependency graph is where that is said rather than
        // claimed. A program only travels as a document, so this is what a
        // program has to come through to leave one machine and arrive at another
        // — and a program that stays where it was built never comes through here
        // at all.
        .target(
            name: "WarpSyntax",
            dependencies: [
                "Warp"
            ]
        ),
        // A document written down, and read back. Warp's own bytes for carrying
        // one, and the same document laid out for eyes — `.wasm` and `.wat`,
        // one target because they are one job done twice.
        //
        // It depends on `Warp` and not on `WarpSyntax`, and that is the whole
        // point: a serialization carries a tree of data and never learns what
        // the tree means. So the wire does not move when the language does, and
        // an implementation in another language can speak it without also
        // implementing what a procedure is.
        .target(
            name: "WarpSerialization",
            dependencies: [
                "Warp"
            ]
        ),
        // One test target per target, and the dependencies are the point: a test
        // that cannot import the syntax can only be saying something about the
        // language. Where a behaviour is tested is then a fact anyone can read
        // off the imports, rather than a claim.
        //
        // It was a claim for a while. Writing a `Value` in Swift was awkward
        // enough that the syntax tests reached for the YAML front end to build
        // fixtures, and the language tests reached for the syntax — so a parser
        // change could fail a reader's test, and the linker had no test in its own
        // target at all. Each layer writes its own fixtures now, in the shape that
        // layer actually takes.
        .testTarget(
            name: "WarpTests",
            dependencies: [
                "Warp"
            ]
        ),
        .testTarget(
            name: "WarpSyntaxTests",
            dependencies: [
                "WarpSyntax"
            ]
        ),
        // The specification's cases, run against this implementation. It imports
        // what any caller imports and nothing more — a runner that could see
        // inside could pass by agreeing with the implementation rather than with
        // the specification, which is the one thing it must not do.
        .testTarget(
            name: "WarpConformanceTests",
            dependencies: [
                "Warp",
                "WarpSyntax",
                "WarpSerialization"
            ]
        ),
        // The front page's examples, run. It imports exactly what the page
        // tells a reader to import — a page whose examples do not compile is
        // worse than no page, and the way to know is to compile them.
        .testTarget(
            name: "WarpReadmeTests",
            dependencies: [
                "Warp",
                "WarpSyntax",
                "WarpSerialization"
            ]
        ),
        .testTarget(
            name: "WarpSerializationTests",
            dependencies: [
                "WarpSerialization"
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
