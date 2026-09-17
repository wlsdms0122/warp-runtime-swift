//
//  NestingBoundTests.swift
//  WarpSyntaxTests
//
//  Created by JSilver
//

import Testing
@testable import Warp
@testable import WarpStandard
@testable import WarpSyntax

// A document nested as deep as the wire admits is a document, and reading,
// building and running one on an ordinary stack is what an implementation
// owes it. Two shapes: a call inside a call, which is the deepest thing a
// program ordinarily writes, and a closure inside a closure, which spends the
// most per level.
@Suite("A document nested as deep as the wire admits")
struct NestingBoundTests {
    enum Shape {
        case call
        case closure

        // How many levels of this shape fit under the bound.
        var levels: Int {
            switch self {
            case .call: 61
            case .closure: 24
            }
        }

        // The whole document, `deep` levels of the shape around a literal one.
        func document(deep: Int) -> Value {
            let expression: Value
            let imports: Value

            switch self {
            case .call:
                imports = ["std.math.plus"]
                expression = (0 ..< deep).reduce(["value": .int(1)]) { inner, _ in
                    ["call": ["procedure": "std.math.plus", "of": inner, "arguments": ["value": ["value": .int(1)]]]]
                }

            case .closure:
                imports = ["std.logic.select"]
                expression = (0 ..< deep).reduce(["value": .int(1)]) { inner, _ in
                    [
                        "call": [
                            "procedure": "std.logic.select",
                            "of": ["value": .bool(true)],
                            "arguments": [
                                "then": ["closure": ["result": inner]],
                                "else": ["closure": ["result": ["value": .int(0)]]]
                            ]
                        ]
                    ]
                }
            }

            return ["warp": .int(1), "imports": imports, "procedures": ["entry": ["result": expression]]]
        }

        func answer(deep: Int) -> Value {
            switch self {
            case .call: .int(1 + deep)
            case .closure: .int(1)
            }
        }
    }

    // MARK: - Test
    @Test("is read, built and run", arguments: [Shape.call, .closure])
    func isReadBuiltAndRun(_ shape: Shape) async throws {
        // Given. A document the wire admits, one level short of one it refuses
        // on the way out and at the door alike.
        let document = shape.document(deep: shape.levels)
        let deeper = shape.document(deep: shape.levels + 1)

        _ = try BinaryEncoding.data(from: document)
        #expect(throws: (any Error).self) { try BinaryEncoding.data(from: deeper) }
        #expect(throws: (any Error).self) { try Loader().load(deeper, identity: nil) }

        // When. Read, built and run.
        let module = try Loader().load(document, identity: nil)
        let image = try await Builder().build([module] + Module.standard, entry: "entry")

        // Then. It answers.
        #expect(try await Executor().run(image) == shape.answer(deep: shape.levels))
    }
}
