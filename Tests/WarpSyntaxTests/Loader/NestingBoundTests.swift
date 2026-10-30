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
// owes it. Three constructs: a call inside a call, which is the deepest thing a
// program ordinarily writes, a closure inside a closure, which spends the
// most per level, and an array inside an array, which opens the most levels
// for the containers it writes. A type and a path are one string in the
// tree, and their levels count on from the containers around it.
@Suite("A document nested as deep as the wire admits")
struct NestingBoundTests {
    enum Construct {
        case call
        case closure
        case array

        // MARK: - Property
        // How many containers a level of this construct opens. A level of a
        // call opens three, the last its list of arguments, where the next
        // level and the other argument both stand; a level of a closure opens
        // eight, its body, statement and `return` among them, and one of an
        // array one.
        var opened: Int {
            switch self {
            case .call: 3
            case .closure: 8
            case .array: 1
            }
        }

        // How many levels of this construct fit under the bound. Around them
        // the document opens six containers, the entry's body, statement and
        // `return` among them, and the reference at the bottom one.
        var levels: Int {
            (Value.nestingBound - 7) / opened
        }

        // MARK: - Initializer
        // MARK: - Public
        // How many containers stand around the path at the bottom of `deep`
        // levels.
        func foot(deep: Int) -> Int {
            7 + opened * deep
        }

        // The whole document, `deep` levels of the construct around a reference
        // reading one, by the path `read`.
        func document(deep: Int, reading read: String = "one") -> Value {
            let expression: Value
            let imports: Value
            let entry: Value

            switch self {
            case .call:
                imports = ["Standard.Numeric.plus"]
                expression = (0 ..< deep).reduce(["ref": .string(read)]) { inner, _ in
                    ["call": ["procedure": "Standard.Numeric.plus", "arguments": [inner, ["ref": "one"]]]]
                }
                entry = ["access": "public", "returns": "Int", "body": [["value": ["return": expression]]]]

            case .closure:
                imports = ["Standard.Logic.select"]
                expression = (0 ..< deep).reduce(["ref": .string(read)]) { inner, _ in
                    [
                        "call": [
                            "procedure": "Standard.Logic.select",
                            "arguments": [
                                ["ref": "yes"],
                                ["closure": ["returns": "Int", "const": true, "isolated": true, "body": [["value": ["return": inner]]]]],
                                ["closure": ["returns": "Int", "const": true, "isolated": true, "body": [["value": ["return": ["ref": "zero"]]]]]]
                            ]
                        ]
                    ]
                }
                entry = ["access": "public", "returns": "Int", "body": [["value": ["return": expression]]]]

            case .array:
                imports = []
                expression = (0 ..< deep).reduce(["ref": .string(read)]) { inner, _ in [inner] }
                entry = ["access": "public", "returns": "Any", "body": [["value": ["return": expression]]]]
            }

            return [
                "warp": .int(1),
                "imports": imports,
                "const": ["one": .int(1), "zero": .int(0), "yes": .bool(true), "ones": [.int(1), .int(1)]],
                "procedures": ["entry": entry]
            ]
        }

        func returned(deep: Int) -> Value {
            switch self {
            case .call: .int(1 + deep)
            case .closure: .int(1)
            case .array: (0 ..< deep).reduce(.int(1)) { inner, _ in [inner] }
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
        // How many containers stand around the spelling's string: the
        // document, `procedures` and the procedure, and then the body, the
        // statement, the `return` and the reference, or the list of
        // parameters and the parameter.
        var place: Int {
            self == .path ? 7 : 5
        }

        // MARK: - Initializer
        // MARK: - Public
        // The spelling, `levels` types or paths inside it.
        func written(levels: Int) -> String {
            switch self {
            case .path: wrapped(levels, "a[", "zero", "]")
            case .array: wrapped(levels, "Array<", "Int", ">")
            case .dictionary: wrapped(levels, "Dictionary<Int, ", "Int", ">")
            case .named: wrapped(levels, "App.Box<", "Int", ">")
            case .parameters: wrapped(levels, "(", "Int", ") -> Int")
            case .returns: String(repeating: "() -> ", count: levels) + "Int"
            case .modified: wrapped(levels, "const (", "Int", ") -> Int")
            }
        }

        // A document reading the path, or declaring a procedure that takes
        // the type, beside an entry returning 0.
        func document(levels: Int) -> Value {
            let written = Value.string(written(levels: levels))

            guard self != .path else {
                return [
                    "warp": .int(1),
                    "imports": [],
                    "const": ["a": [.int(0)], "zero": .int(0)],
                    "procedures": ["entry": ["access": "public", "returns": "Int", "body": [["value": ["return": ["ref": written]]]]]]
                ]
            }

            return [
                "warp": .int(1),
                "imports": [],
                "types": ["App.Box": ["struct": ["held": "some T"], "typeParameters": ["T"]]],
                "procedures": [
                    "entry": ["access": "public", "returns": "Int", "body": [["value": ["return": .int(0)]]]],
                    "App.take": ["parameters": [["name": "taken", "type": written]], "returns": "Int", "body": [["value": ["return": .int(0)]]]]
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
    @Test("is read, built and run", arguments: [Construct.call, .closure, .array])
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
            try Loader().load(deeper)
        } throws: { error in
            "\(error)".contains("nests deeper than a document may")
        }

        // When. Read, built and run.
        let module = try Loader().load(document)
        let image = try await Builder().build([module] + Module.standard)

        // Then. It returns, and its object is written and read back.
        #expect(try await Executor().run(image) == construct.returned(deep: construct.levels))
        try await objectReadsBack(module, beside: Module.standard)
    }

    @Test("a type or a path as deep as a document may is read, built and run", arguments: Spelling.allCases)
    func aSpellingAsDeepAsTheBound(_ spelling: Spelling) async throws {
        // Given. A spelling the load takes, one level short of one it refuses.
        let document = spelling.document(levels: Value.nestingBound - spelling.place)
        let deeper = spelling.document(levels: Value.nestingBound - spelling.place + 1)

        #expect {
            try Loader().load(deeper)
        } throws: { error in
            "\(error)".contains("nests deeper than a document may")
        }
        #expect(try TextEncoding().value(from: try TextEncoding().text(from: document)) == document)

        // When. Read, built and run.
        let module = try Loader().load(document)
        let image = try await Builder().build([module])

        // Then. It returns, and its object is written and read back.
        #expect(try await Executor().run(image) == .int(0))
        try await objectReadsBack(module, beside: [])
    }

    @Test("a path at the bottom of a deep document nests as deep as the rest allows", arguments: [Construct.call, .closure, .array])
    func aPathAtTheBottomOfADeepDocument(_ construct: Construct) async throws {
        // Given. Half the construct's levels, and under them a path as deep as
        // the containers around it leave room for, and one deeper.
        let deep = construct.levels / 2
        let levels = Value.nestingBound - construct.foot(deep: deep)
        let path = { (levels: Int) in
            String(repeating: "ones[", count: levels) + "zero" + String(repeating: "]", count: levels)
        }
        let document = construct.document(deep: deep, reading: path(levels))
        let deeper = construct.document(deep: deep, reading: path(levels + 1))

        #expect {
            try Loader().load(deeper)
        } throws: { error in
            "\(error)".contains("nests deeper than a document may")
        }
        #expect(try TextEncoding().value(from: try TextEncoding().text(from: document)) == document)

        // When. Read, built and run.
        let module = try Loader().load(document)
        let image = try await Builder().build([module] + Module.standard)

        // Then. It returns what the path's one does.
        #expect(try await Executor().run(image) == construct.returned(deep: deep))
    }

    @Test("a type aliases unfold to the bound is written in an object, and one past it writes none")
    func aTypeUnfoldedToTheBound() async throws {
        // Given. Aliases each standing for an array of the one before, and a
        // cast to the last: a string one level deep that lowers as deep as
        // the aliases are many.
        let document = { (aliases: Int) -> Value in
            var types: [Name: Value] = [Name(normal: "App.A0"): "Int"]

            for alias in 1 ... aliases {
                types[Name(normal: "App.A\(alias)")] = .string("Array<App.A\(alias - 1)>")
            }

            return [
                "warp": 1,
                "imports": [],
                "types": .dictionary(Value.Dictionary(types)),
                "procedures": [
                    "entry": [
                        "access": "public",
                        "parameters": [["name": "p"]],
                        "returns": "Any",
                        "failing": ["cast_refused"],
                        "body": [["value": ["return": ["as": ["of": ["ref": "p"], "type": .string("App.A\(aliases)")]]]]]
                    ]
                ]
            ]
        }

        // When. Built with the cast's type lowered to the bound, and one
        // level past it.
        let module = try Loader().load(document(Value.nestingBound - 1))
        let past = try await Builder().compile([try Loader().load(document(Value.nestingBound))])

        // Then. The one is written and read back; the other has no object.
        try await objectReadsBack(module, beside: [])
        #expect(throws: ObjectUnwritable.self) { try past[0].object() }
    }

    // MARK: - Public
    // MARK: - Private
    // The document's object written as bytes and read back: an object nests
    // no deeper for a document nesting deeper.
    private func objectReadsBack(_ module: Module, beside standing: [Module]) async throws {
        let compiled = try await Builder(fingerprinting: Fingerprint.of).compile([module] + standing)
        let bytes = try BinaryEncoding().data(from: try compiled[0].object())

        _ = try Compiled(written: try BinaryEncoding().value(from: bytes), of: compiled[0].identity)
    }
}
