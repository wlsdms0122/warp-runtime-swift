//
//  NestingBoundTests.swift
//  WarpSyntaxTests
//
//  Created by JSilver on 9/17/26.
//

import Foundation
import Testing
@testable import Warp
@testable import WarpSyntax
@testable import WarpStandard

// A document nested as deep as the wire admits is a document, and reading,
// building and running one on an ordinary stack is what an implementation
// owes it. Two constructs: a call inside a call, which is the deepest thing a
// program ordinarily writes, and a closure inside a closure, which spends the
// most per level. A type and a path are one text in the tree and nest inside
// it as deep as a document may, each spelling walked on its own.
@Suite("A document nested as deep as the wire admits")
struct NestingBoundTests {
    enum Construct {
        case call
        case closure

        // MARK: - Property
        // How many levels of this construct fit under the bound. A level of a
        // call opens three containers, the last its list of arguments, where
        // the next level and the other argument both stand; a level of a
        // closure opens five. Around them the document opens three and the
        // reference at the bottom one.
        var levels: Int {
            switch self {
            case .call: (Value.nestingBound - 4) / 3
            case .closure: (Value.nestingBound - 4) / 5
            }
        }

        // MARK: - Initializer
        // MARK: - Public
        // The whole document, `deep` levels of the construct around a reference to
        // a constant one.
        func document(deep: Int) -> Value {
            let expression: Value
            let imports: Value
            let entry: Value

            switch self {
            case .call:
                imports = ["Standard.Numeric.plus"]
                expression = (0 ..< deep).reduce(["ref": "one"]) { inner, _ in
                    ["call": ["procedure": "Standard.Numeric.plus", "arguments": [inner, ["ref": "one"]]]]
                }
                entry = ["access": "public", "returns": "Int", "result": expression]

            case .closure:
                imports = ["Standard.Logic.select"]
                expression = (0 ..< deep).reduce(["ref": "one"]) { inner, _ in
                    [
                        "call": [
                            "procedure": "Standard.Logic.select",
                            "arguments": [
                                ["ref": "yes"],
                                ["closure": ["returns": "Int", "const": true, "isolated": true, "result": inner]],
                                ["closure": ["returns": "Int", "const": true, "isolated": true, "result": ["ref": "zero"]]]
                            ]
                        ]
                    ]
                }
                entry = ["access": "public", "returns": "Int", "result": expression]
            }

            return [
                "warp": .int(1),
                "imports": imports,
                "const": ["one": .int(1), "zero": .int(0), "yes": .bool(true)],
                "procedures": ["entry": entry]
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

    enum Spelling: CaseIterable {
        case path
        case array
        case dictionary
        case named
        case parameters
        case returns
        case modified

        // MARK: - Property
        // MARK: - Initializer
        // MARK: - Public
        // The spelling, `deep` types or paths deep.
        func written(deep: Int) -> String {
            switch self {
            case .path: wrapped(deep - 1, "a[", "zero", "]")
            case .array: wrapped(deep - 1, "Array<", "Int", ">")
            case .dictionary: wrapped(deep - 1, "Dictionary<Int, ", "Int", ">")
            case .named: wrapped(deep - 1, "App.Box<", "Int", ">")
            case .parameters: wrapped(deep - 1, "(", "Int", ") -> Int")
            case .returns: String(repeating: "() -> ", count: deep - 1) + "Int"
            case .modified: wrapped(deep - 1, "const (", "Int", ") -> Int")
            }
        }

        // A document reading the path, or declaring a procedure that takes
        // the type, beside an entry answering 0.
        func document(deep: Int) -> Value {
            let written = Value.string(written(deep: deep))

            guard self != .path else {
                return [
                    "warp": .int(1),
                    "imports": [],
                    "const": ["a": [.int(0)], "zero": .int(0)],
                    "procedures": ["entry": ["access": "public", "returns": "Int", "result": ["ref": written]]]
                ]
            }

            return [
                "warp": .int(1),
                "imports": [],
                "types": ["App.Box": ["struct": ["held": "some T"], "typeParameters": ["T"]]],
                "procedures": [
                    "entry": ["access": "public", "returns": "Int", "result": .int(0)],
                    "App.take": ["parameters": [["name": "taken", "type": written]], "returns": "Int", "result": .int(0)]
                ]
            ]
        }

        // MARK: - Private
        private func wrapped(_ count: Int, _ open: String, _ inner: String, _ close: String) -> String {
            String(repeating: open, count: count) + inner + String(repeating: close, count: count)
        }
    }

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("is read, built and run", arguments: [Construct.call, .closure])
    func isReadBuiltAndRun(_ construct: Construct) async throws {
        // Given. A document the wire admits, one level short of one it refuses
        // on the way out and at the door alike.
        let document = construct.document(deep: construct.levels)
        let deeper = construct.document(deep: construct.levels + 1)

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
            "\(error)".contains("nesting deeper than \(Value.nestingBound) containers")
        }

        // When. Read, built and run.
        let module = try Loader().load(document, identity: nil)
        let image = try await Builder().build([module] + Module.standard)

        // Then. It answers.
        #expect(try await Executor().run(image) == construct.answer(deep: construct.levels))
    }

    @Test("a type or a path as deep as a document may is read, built and run", arguments: Spelling.allCases)
    func aSpellingAsDeepAsTheBound(_ spelling: Spelling) async throws {
        // Given. A spelling the load takes, one level short of one it refuses.
        let document = spelling.document(deep: Value.nestingBound)
        let deeper = spelling.document(deep: Value.nestingBound + 1)

        #expect {
            try Loader().load(deeper, identity: nil)
        } throws: { error in
            "\(error)".contains("nests deeper than \(Value.nestingBound)")
        }
        #expect(try TextEncoding().value(from: try TextEncoding().text(from: document)) == document)

        // When. Read, built and run.
        let module = try Loader().load(document, identity: nil)
        let image = try await Builder().build([module])

        // Then. It answers.
        #expect(try await Executor().run(image) == .int(0))
    }

    // MARK: - Public
    // MARK: - Private
}
