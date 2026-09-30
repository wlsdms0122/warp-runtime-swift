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

        // MARK: - Property
        // How many levels of this shape fit under the bound. A level of a
        // call opens three containers, the last its list of arguments, where
        // the next level and the other argument both stand; a level of a
        // closure opens five. Around them the document opens three and the
        // reference at the bottom one.
        var levels: Int {
            switch self {
            case .call: (Envelope.nesting - 4) / 3
            case .closure: (Envelope.nesting - 4) / 5
            }
        }

        // MARK: - Initializer
        // MARK: - Public
        // The whole document, `deep` levels of the shape around a reference to
        // a constant one.
        func document(deep: Int) -> Value {
            let expression: Value
            let imports: Value

            switch self {
            case .call:
                imports = ["std.math.plus"]
                expression = (0 ..< deep).reduce(["ref": "one"]) { inner, _ in
                    ["call": ["procedure": "std.math.plus", "arguments": [inner, ["ref": "one"]]]]
                }

            case .closure:
                imports = ["std.logic.select"]
                expression = (0 ..< deep).reduce(["ref": "one"]) { inner, _ in
                    [
                        "call": [
                            "procedure": "std.logic.select",
                            "arguments": [
                                ["ref": "yes"],
                                ["closure": ["result": inner]],
                                ["closure": ["result": ["ref": "zero"]]]
                            ]
                        ]
                    ]
                }
            }

            return [
                "warp": .int(1),
                "imports": imports,
                "const": ["one": .int(1), "zero": .int(0), "yes": .bool(true)],
                "procedures": ["entry": ["access": "public", "result": expression]]
            ]
        }

        func answer(deep: Int) -> Value {
            switch self {
            case .call: .int(1 + deep)
            case .closure: .int(1)
            }
        }

        // MARK: - Private
    }

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("is read, built and run", arguments: [Shape.call, .closure])
    func isReadBuiltAndRun(_ shape: Shape) async throws {
        // Given. A document the wire admits, one level short of one it refuses
        // on the way out and at the door alike.
        let document = shape.document(deep: shape.levels)
        let deeper = shape.document(deep: shape.levels + 1)

        _ = try BinaryEncoding().data(from: document)
        #expect {
            try BinaryEncoding().data(from: deeper)
        } throws: { error in
            "\(error)".contains("nests deeper than a document may")
        }
        #expect {
            try TextEncoding().text(from: deeper)
        } throws: { error in
            "\(error)".contains("nests deeper than a document may")
        }
        #expect {
            try Loader().load(deeper, identity: nil)
        } throws: { error in
            "\(error)".contains("nesting deeper than \(Envelope.nesting) containers")
        }

        // When. Read, built and run.
        let module = try Loader().load(document, identity: nil)
        let image = try await Builder().build([module] + Module.standard)

        // Then. It answers.
        #expect(try await Executor().run(image) == shape.answer(deep: shape.levels))
    }

    // MARK: - Public
    // MARK: - Private
}
