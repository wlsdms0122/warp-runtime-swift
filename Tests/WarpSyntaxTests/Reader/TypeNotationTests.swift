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
        #expect(try TypeReader.parse("Dictionary<Array<Int>>") == .dictionary(.array(.int)))
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

        // And. `?` wraps the whole spelling, so inside the brackets it is the
        // element that is nullable, and in front of it a modifier or an `&`
        // is still the whole type's.
        #expect(try TypeReader.parse("Array<Int?>") == .array(.nullable(.int)))
        #expect(try TypeReader.parse("const Procedure?") == .nullable(.procedure(nil, .const)))
        #expect(try TypeReader.parse("isolated Procedure?") == .nullable(.procedure(nil, .unstated, .isolated)))
        #expect(try TypeReader.parse("App.B & App.A?") == .nullable(.composition(["App.A", "App.B"])))
        #expect(try TypeReader.parse("inout Int?") == .inout(.nullable(.int)))
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
            error is ValidationError && "\(error)".contains("'Int' is no type's name")
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

    @Test("a signature bounds its type parameters once, in bounds")
    func aBoundIsDeclaredInTheSignature() throws {
        // Given / When. The slots name the parameter, and the signature says
        // what the name admits
        let sut = try loader.loadProcedure([
            "bounds": ["T": "Comparable"],
            "parameters": [["name": "of", "type": "some T"], ["name": "value", "type": "some T"]],
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

    @Test("a bound is the names of contracts, and a nested procedure type writes none")
    func aBoundBelongsToTheSignature() throws {
        // When / Then. A bound is a contract's name, never a type.
        #expect(throws: ValidationError.self) {
            try loader.loadProcedure([
                "bounds": ["T": "Array<Int>"],
                "parameters": [["name": "of", "type": "some T"]],
                "result": ["ref": "of"]
            ])
        }

        // And. A nested procedure type carries no bounds of its own. Its
        // parameters are the declaring signature's slots, and the declaring
        // signature owns their bounds. Two records binding one namespace would
        // be two claims about one thing.
        #expect(throws: ReadingError.self) {
            try loader.loadProcedure([
                "parameters": [
                    ["name": "by",
                        "type": [
                            "procedure": [
                                "bounds": ["T": "Comparable"],
                                "parameters": ["some T"],
                                "returns": "Bool"
                            ]
                        ]
                    ]
                ],
                "result": ["ref": "by"]
            ])
        }
    }

    @Test("a bound reaches the parameters a nested signature mentions")
    func aBoundReachesNestedMentions() throws {
        // Given / When. `some Element` sits under `Array<…>` and inside a
        // procedure type's own slot; both are this signature's mentions of one
        // name
        let sut = try loader.loadProcedure([
            "bounds": ["Element": "Comparable"],
            "parameters": [
                ["name": "by",
                    "type": [
                        "procedure": [
                            "parameters": ["some Element"],
                            "returns": "Bool"
                        ]
                    ]
                ], ["name": "of", "type": "Array<some Element>"]
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
            "types": ["Task": ["record": ["id": "String", "done": "Bool"]]],
            "procedures": [
                "entry": [
                    "parameters": [["name": "tasks", "type": "Array<Task>"]],
                    "body": [["let": "seen", "value": ["ref": "tasks"]]]
                ]
            ]
        ])

        // Then
        #expect(sut.types["Task"] == .record(["id": .string, "done": .bool]))
        #expect(
            sut.procedures["entry"]?.signature.parameter(named: "tasks")?.type
                == .array(.named("Task"))
        )
    }

    @Test("the record form holds only an element with no spelling of its own")
    func recordFormIsForNamelessElements() throws {
        // Given / When. An array of records has no string spelling, so the
        // record form is the one way to write it.
        let sut = try loader.loadDocument([
            "procedures": [
                "entry": [
                    "parameters": [["name": "rows", "type": ["array": ["record": ["id": "String"]]]]],
                    "body": [["let": "seen", "value": ["ref": "rows"]]]
                ]
            ]
        ])

        // Then
        #expect(
            sut.procedures["entry"]?.signature.parameter(named: "rows")?.type
                == .array(.record(["id": .string]))
        )

        // And. An element with a spelling is written `Array<String>`. A document
        // says it that one way, and the form around it is a second spelling
        #expect {
            try loader.load(
                [
                    "warp": .int(ModuleReader.version),
                    "imports": [],
                    "procedures": [
                        "entry": [
                            "parameters": [["name": "rows", "type": ["array": "String"]]],
                            "body": [["let": "seen", "value": ["ref": "rows"]]]
                        ]
                    ]
                ],
                identity: nil
            )
        } throws: { error in
            "\(error)".contains("The one way writes \"Array<String>\"")
        }
    }

    @Test("a declared type is enforced at the call boundary")
    func declaredTypeIsEnforced() async throws {
        // Given
        let sut = try loader.loadDocument([
            "types": ["Task": ["record": ["id": "String"]]],
            "procedures": [
                "entry": [
                    "parameters": [["name": "tasks", "type": "Array<Task>"]],
                    "body": [["let": "seen", "value": ["ref": "tasks"]]],
                    "result": ["record": ["result": ["ref": "seen"]]]
                ]
            ]
        ])

        // When / Then
        let good = try await run(sut, arguments: ["tasks": .array([.dictionary(["id": .string("a")])])])

        #expect(good["result"] == .array([.record(Record(name: "Task", ["id": .string("a")]))]))

        await #expect(throws: ArgumentError.self) {
            try await run(sut, arguments: ["tasks": .array([.dictionary(["id": .int(1)])])])
        }
    }

    // MARK: - Public
    // MARK: - Private
}
