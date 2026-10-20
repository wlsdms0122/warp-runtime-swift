//
//  TypeNotationTests.swift
//  WarpSyntaxTests
//
//  Created by JSilver on 8/17/26.
//

import Foundation
import Testing
@testable import Warp
@testable import WarpSyntax
import WarpTestSupport

@Suite("How a document spells a type")
struct TypeNotationTests {
    // MARK: - Property
    private let loader = Loader.testing

    // MARK: - Initializer
    // MARK: - Test
    @Test("a built-in reads as its own name, applied or not")
    func builtinsParse() throws {
        // When / Then
        #expect(try TypeReader.parse("String") == .string)
        #expect(try TypeReader.parse("Array<Any>") == .array(.any))
        #expect(try TypeReader.parse("Array") == .named("Array"))
        #expect(try TypeReader.parse("Array<String>") == .array(.string))
        #expect(try TypeReader.parse("Dictionary<String, Array<Int>>") == .dictionary(key: .string, value: .array(.int)))
        #expect(try TypeReader.parse("Procedure") == .procedure(nil))
        #expect(try TypeReader.parse("Never") == .never)
    }

    @Test("a slot asks for constness by writing it in front")
    func constnessIsWrittenAndRead() throws {
        // Given / When / Then
        #expect(try TypeReader.parse("const Procedure") == .procedure(nil, .const))
        #expect(try TypeReader.parse("Procedure") == .procedure(nil, .unstated))

        // Only a procedure answers without running, so only a procedure is
        // written const.
        #expect(throws: TypeFormError.self) { try TypeReader.parse("const String") }
    }

    @Test("a type parameter is written some, and is not a declared name")
    func typeParametersAreWrittenAndRead() throws {
        // Given / When / Then
        #expect(try TypeReader.parse("some Element") == .parameter(name: "Element"))
        #expect(try TypeReader.parse("Array<some Element>") == .array(.parameter(name: "Element")))

        // A bare name is looked up in the table of declared types; only `some`
        // says the call decides.
        #expect(try TypeReader.parse("Element") == .named("Element"))

        #expect(throws: TypeFormError.self) { try TypeReader.parse("some ") }
    }

    @Test("a trailing ? reads as the nullable of the whole spelling")
    func nullableParses() throws {
        // When / Then
        #expect(try TypeReader.parse("Int?") == .nullable(.int))
        #expect(try TypeReader.parse("String?") == .nullable(.string))
        #expect(try TypeReader.parse("Array<Int>?") == .nullable(.array(.int)))
        #expect(try TypeReader.parse("Task?") == .nullable(.named("Task")))

        // And. `?` wraps the whole spelling before it, so inside the brackets
        // it is the element that is nullable, and in front of it an `&` or a
        // mark is still the whole type's.
        #expect(try TypeReader.parse("Array<Int?>") == .array(.nullable(.int)))
        #expect(try TypeReader.parse("App.B & App.A?") == .nullable(.composition(["App.A", "App.B"])))
        #expect(try TypeReader.parse("inout Int?") == .inout(.nullable(.int)))

        // And. After `->` stands a procedure's answer, so a `?` there is the
        // answer's, and parentheses group, so one after them is the whole
        // procedure's, as one after a modifier is. They group before a `?`
        // and nowhere else.
        let answer = ProcedureType(parameters: [.int], returns: .nullable(.int), failing: .these([]))
        let whole = ProcedureType(parameters: [.int], returns: .int, failing: .these([]))

        #expect(try TypeReader.parse("(Int) -> Int?") == .procedure(answer))
        #expect(try TypeReader.parse("((Int) -> Int)?") == .nullable(.procedure(whole)))
        #expect(try TypeReader.parse("(const Procedure)?") == .nullable(.procedure(nil, .const)))
        #expect(try TypeReader.parse("(isolated Procedure)?") == .nullable(.procedure(nil, .unstated, .isolated)))
        #expect(throws: TypeFormError.self) { try TypeReader.parse("const Procedure?") }
        #expect(try TypeReader.parse("(Int)?") == .nullable(.int))
        #expect(throws: TypeFormError.self) { try TypeReader.parse("((Int) -> Int)") }
        #expect(throws: TypeFormError.self) { try TypeReader.parse("(((Int) -> Int))?") }
    }

    @Test("names joined with & read as the set of them, and write back in name order")
    func compositionsParse() throws {
        // When / Then
        #expect(try TypeReader.parse("App.B & App.A") == .composition(["App.A", "App.B"]))
        #expect(try TypeReader.parse("Array<App.A & App.B>") == .array(.composition(["App.A", "App.B"])))
        #expect(try Writer().value(of: .composition(["App.A", "App.B"])) == .string("App.A & App.B"))
        #expect(try TypeReader.parse("App.A & App.A") == .named("App.A"))

        // And. Each part is read as a name, and which names a contract may
        // be called is the load's
        #expect(try TypeReader.parse("App.A & Int") == .composition(["App.A", "Int"]))
        #expect {
            try Loader().load([
                "warp": 1,
                "imports": ["App.A"],
                "procedures": ["entry": ["parameters": [["name": "x", "type": "App.A & Int"]]]]
            ])
        } throws: { error in
            error is ValidationError && "\(error)".contains("'Int' is no name a module gives a type or a contract")
        }

        // And. A document writes the set one way, in name order, and a name
        // written twice is one name, which `&` does not join
        for (written, imports, one) in [
            ("App.B & App.A", ["App.A", "App.B"], "App.A & App.B"),
            ("App.A & App.A", ["App.A"], "App.A")
        ] as [(String, Value, String)] {
            #expect {
                try Loader().load([
                    "warp": 1,
                    "imports": imports,
                    "procedures": ["entry": ["parameters": [["name": "x", "type": .string(written)]]]]
                ])
            } throws: { error in
                "\(error)".contains("says each thing one way") && "\(error)".contains("The one way writes \"\(one)\"")
            }
        }
    }

    @Test("a signature bounds a type parameter beside the first naming its slots write")
    func aBoundIsDeclaredInTheSignature() throws {
        // Given / When. The first slot naming the parameter says what the name
        // admits, and the others name it
        let sut = try loader.loadProcedure([
            "parameters": [["name": "of", "type": "some T: Comparable"], ["name": "value", "type": "some T"]],
            "returns": "some T",
            "result": ["ref": "of"]
        ], importing: ["Comparable"])

        // Then. The signature holds the bound, and every slot names the
        // parameter
        let signature = sut.procedures[entryName]?.signature

        #expect(signature?.bounds == ["T": ["Comparable"]])
        #expect(signature?.parameter(named: "of")?.type == .parameter(name: "T"))
        #expect(signature?.parameter(named: "value")?.type == .parameter(name: "T"))
        #expect(signature?.returns == .parameter(name: "T"))
    }

    @Test("a bound is the names of contracts")
    func aBoundBelongsToTheSignature() throws {
        // When / Then. A bound is a contract's name, never a type.
        #expect(throws: ValidationError.self) {
            try loader.loadProcedure([
                "parameters": [["name": "of", "type": "some T: Array<Int>"]],
                "result": ["ref": "of"]
            ])
        }
    }

    @Test("a bound reaches the parameters a nested signature mentions")
    func aBoundReachesNestedMentions() throws {
        // Given / When. `some Element` sits under `Array<…>` and inside a
        // procedure type's own slot; both are this signature's mentions of one
        // name
        let sut = try loader.loadProcedure([
            "parameters": [
                ["name": "by", "type": "(some Element: Comparable) -> Bool"],
                ["name": "of", "type": "Array<some Element>"]
            ],
            "result": ["ref": "of"]
        ], importing: ["Comparable"])

        // Then
        let signature = sut.procedures[entryName]?.signature

        #expect(signature?.bounds == ["Element": ["Comparable"]])
        #expect(signature?.parameter(named: "of")?.type == .array(.parameter(name: "Element")))

        guard case let .procedure(.some(inner), _, _) = signature?.parameter(named: "by")?.type else {
            Issue.record("the procedure type did not survive reading")

            return
        }

        #expect(inner.parameters.first == .parameter(name: "Element"))
    }

    @Test("a name nothing builds in is a declared type")
    func unknownNameIsNamed() throws {
        // When / Then
        #expect(try TypeReader.parse("Task") == .named("Task"))
    }

    @Test("a type written inside another is a level deeper, counted on from the containers around the type's string")
    func aTypeNestsToTheBound() throws {
        // Given
        let nested = { (levels: Int, open: String, inner: String, close: String) in
            String(repeating: open, count: levels) + inner + String(repeating: close, count: levels)
        }
        let around = 100
        let steps = Array(repeating: Place.Step.index(0), count: around)

        // When / Then. A modifier and the parentheses grouping a type add no
        // level
        #expect(try TypeReader.parse(nested(Value.nestingBound, "Array<", "Int", ">")).rendered
            == nested(Value.nestingBound, "Array<", "Int", ">"))
        #expect(try TypeReader.parse(nested(Value.nestingBound, "const (", "Int", ") -> Int")).rendered
            == nested(Value.nestingBound, "const (", "Int", ") -> Int"))
        #expect(throws: TypeFormError.self) { try TypeReader.parse(nested(Value.nestingBound + 1, "Array<", "Int", ">")) }
        #expect(throws: TypeFormError.self) { try TypeReader.parse(nested(Value.nestingBound + 1, "(", "Int", ")?")) }
        #expect(try TypeReader.parse(nested(Value.nestingBound - around, "Array<", "Int", ">"), at: steps).rendered
            == nested(Value.nestingBound - around, "Array<", "Int", ">"))
        #expect(throws: TypeFormError.self) {
            try TypeReader.parse(nested(Value.nestingBound - around + 1, "Array<", "Int", ">"), at: steps)
        }
    }

    @Test("an unbalanced argument is an author mistake, caught while reading")
    func unbalancedArgumentRejected() {
        // When / Then
        #expect(throws: TypeFormError.self) { try TypeReader.parse("Array<String") }
        #expect(throws: TypeFormError.self) { try TypeReader.parse("String>") }
        #expect(throws: TypeFormError.self) { try TypeReader.parse("String<Int>") }
    }

    @Test("a module declares types its procedures name")
    func moduleDeclaresTypes() throws {
        // Given / When
        let sut = try loader.loadDocument([
            "types": ["Task": ["struct": ["id": "String", "done": "Bool"]]],
            "procedures": [
                "entry": [
                    "parameters": [["name": "tasks", "type": "Array<Task>"]],
                    "body": [["let": "seen", "value": ["ref": "tasks"]]]
                ]
            ]
        ])

        // Then
        #expect(sut.types["Task"] == .struct(["id": .string, "done": .bool]))
        #expect(
            sut.procedures["entry"]?.signature.parameter(named: "tasks")?.type
                == .array(.named("Task"))
        )
    }

    @Test("a list or a map of procedures is written by its spelling, and a mapping is no type")
    func procedureElementsAreSpelled() throws {
        // Given / When
        let sut = try loader.loadDocument([
            "procedures": [
                "entry": [
                    "parameters": [
                        ["name": "rows", "type": "Array<() -> Int>"],
                        ["name": "steps", "type": "Dictionary<String, (Int) throws -> Int>"]
                    ],
                    "body": [["let": "seen", "value": ["ref": "rows"]]]
                ]
            ]
        ])

        // Then
        let signature = sut.procedures["entry"]?.signature

        #expect(signature?.parameter(named: "rows")?.type == .array(.procedure(ProcedureType(returns: .int, failing: .these([])))))
        #expect(
            signature?.parameter(named: "steps")?.type
                == .dictionary(key: .string, value: .procedure(ProcedureType(parameters: [.int], returns: .int, failing: .anything)))
        )

        // And. A type is a string, so a mapping where one is written is no type
        #expect(throws: ReadingError.self) {
            try loader.loadDocument([
                "procedures": [
                    "entry": [
                        "parameters": [["name": "rows", "type": ["array": "String"]]],
                        "body": [["let": "seen", "value": ["ref": "rows"]]]
                    ]
                ]
            ])
        }

        // And. The spelling writes two types, and one is no map
        #expect(throws: TypeFormError.self) { try TypeReader.parse("Dictionary<Int>") }
        #expect(throws: TypeFormError.self) { try TypeReader.parse("Array<Int, Int>") }
        #expect(try TypeReader.parse("Dictionary<Int?, Array<String>>") == .dictionary(key: .nullable(.int), value: .array(.string)))
    }

    @Test("a declared type is enforced at the entry's door")
    func declaredTypeIsEnforced() async throws {
        // Given
        let sut = try loader.loadDocument([
            "types": ["Task": ["struct": ["id": "String"]]],
            "procedures": [
                "entry": [
                    "returns": "Any",
                    "parameters": [["name": "tasks", "type": "Array<Task>"]],
                    "body": [["let": "seen", "value": ["ref": "tasks"]]],
                    "result": ["dictionary": [["result", ["ref": "seen"]]]]
                ]
            ]
        ])

        // When / Then
        let good = try await run(sut, arguments: ["tasks": .array([.struct(Struct(name: "Task", ["id": .string("a")]))])])

        #expect(good.map?["result"] == .array([.struct(Struct(name: "Task", ["id": .string("a")]))]))

        await #expect(throws: ArgumentError.self) {
            try await run(sut, arguments: ["tasks": .array([.struct(Struct(name: "Task", ["id": .int(1)]))])])
        }
    }

    // MARK: - Public
    // MARK: - Private
}
