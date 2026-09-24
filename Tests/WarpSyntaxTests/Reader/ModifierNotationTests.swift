//
//  ModifierNotationTests.swift
//  WarpSyntax
//
//  Created by JSilver on 9/3/26.
//

import Foundation
import Testing
import Warp
@testable import WarpSyntax

@Suite("The procedures a slot writes about itself")
struct ModifierNotationTests {
    @Test("a mark stands in front of the whole type", arguments: [
        ("inout int", TypeExpression.inout(.int)),
        ("inout int?", .inout(.nullable(.int))),
        ("var array<int>", .variable(.array(.int))),
        ("inout procedure", .inout(.procedure(nil))),
        ("consuming Handle", .consuming(.named("Handle"))),
        ("borrowing Handle", .borrowing(.named("Handle")))
    ])
    func everyMarkStandsInFrontOfTheWholeType(written: String, expected: TypeExpression) throws {
        #expect(try TypeReader.parse(written) == expected)
    }

    @Test("every mark reads and writes back, whichever ones there are", arguments: SlotMark.allCases)
    func everyMarkRoundTrips(mark: SlotMark) async throws {
        // Given. The reading, the writing and the document's vocabulary all
        // come off one list, so a mark added to it is asked these questions
        // without anyone remembering to ask. Both forms a marked type takes:
        // a name, and a procedure under its one key
        let named = mark.marking(.named("Handle"))
        let form = mark.marking(.procedure(ProcedureType(returns: .int)))

        // When
        let writtenName = try Writer().value(of: named)
        let writtenForm = try Writer().value(of: form)

        // Then
        #expect(writtenName == .string("\(mark.rawValue) Handle"))
        #expect(try TypeReader.parse("\(mark.rawValue) Handle") == named)
        #expect(SlotMark.marked(named) == mark)

        #expect(
            writtenForm == .dictionary([
                try Name("\(mark.rawValue) procedure"): .dictionary(["returns": "int"])
            ])
        )

        let read = try await Loader().load([
            "warp": 1,
            "imports": [],
            "procedures": ["entry": ["parameters": [["name": "f", "type": writtenForm]], "result": Value.null]]
        ])

        #expect(read.procedures["entry"]?.signature.parameter(named: "f")?.type == form)
    }

    @Test(
        "a mark is not written inside a mark either",
        arguments: SlotMark.allCases, SlotMark.allCases
    )
    func aMarkIsNotWrittenInsideAMark(mark: SlotMark, inside: SlotMark) throws {
        // Given. What the reading refuses the writing refuses too, in both the
        // forms a marked type is written in
        #expect(throws: WritingError.self) {
            try Writer().value(of: mark.marking(inside.marking(.named("Handle"))))
        }

        #expect(throws: WritingError.self) {
            try Writer().value(of: mark.marking(inside.marking(.procedure(nil))))
        }
    }

    @Test(
        "a mark inside a mark is refused, whichever two they are",
        arguments: SlotMark.allCases, SlotMark.allCases
    )
    func aMarkInsideAMarkIsRefused(mark: SlotMark, inside: SlotMark) throws {
        #expect(throws: TypeFormError.self) {
            try TypeReader.parse("\(mark.rawValue) \(inside.rawValue) Handle")
        }
    }

    @Test(
        "a key carrying two marks is a field's name, whichever two they are",
        arguments: SlotMark.allCases, SlotMark.allCases
    )
    func aKeyCarryingTwoMarksIsAFieldName(mark: SlotMark, inside: SlotMark) async throws {
        // Given. A slot writes one mark, so a key carrying two is not a
        // procedure form's, and a key that is not one is a field's name like
        // any other. The writing never makes one: a marked type holding a
        // marked type is refused before it gets here
        let key = try Name("\(mark.rawValue) \(inside.rawValue) procedure")
        let type = TypeExpression.record([key: .record(["returns": .int])])

        // When
        let written = try Writer().value(of: type)
        let read = try await Loader().load([
            "warp": 1,
            "imports": [],
            "procedures": [
                "entry": ["parameters": [["name": "f", "type": written]], "result": Value.null]
            ]
        ])

        // Then
        #expect(read.procedures["entry"]?.signature.parameter(named: "f")?.type == type)
    }

    @Test("a marked type is not written under a `?`", arguments: SlotMark.allCases)
    func aMarkIsNotWrittenUnderADoubt(mark: SlotMark) throws {
        // Given. `var Task?` reads as a `var` of a nullable, so a nullable of a
        // `var` has no spelling of its own: writing it would hand two types one
        // spelling and bring only one of them back
        let type = TypeExpression.nullable(mark.marking(.named("Task")))

        // When / Then
        #expect(throws: WritingError.self) {
            try Writer().value(of: type)
        }

        // And the same spelling read back is the mark outside the doubt
        #expect(try TypeReader.parse("\(mark.rawValue) Task?") == mark.marking(.nullable(.named("Task"))))
    }

    @Test("a record's field is named whatever the document named it")
    func aFieldNamedLikeTwoMarksIsStillAField() async throws {
        // Given. The rule about two marks is a procedure form's, and a key is
        // only that form's once what is under the marks says `procedure`.
        // Anything else is a field name, and the writer writes one back
        let type = TypeExpression.record([try Name("var inout x"): .int])

        // When
        let written = try Writer().value(of: type)
        let read = try await Loader().load([
            "warp": 1,
            "imports": [],
            "procedures": ["entry": ["parameters": [["name": "f", "type": written]], "result": Value.null]]
        ])

        // Then
        #expect(read.procedures["entry"]?.signature.parameter(named: "f")?.type == type)
    }

    @Test(
        "a record's only field may be named for a key the reading takes another way",
        arguments: ["procedure", "var procedure", "const isolated procedure", "linear", "array", "record"]
    )
    func aRecordsOnlyFieldMayBeNamedLikeAForm(spelling: String) async throws {
        // Given. A record type is written under `record`, so its field names
        // are never keys the reading takes as a form
        let type = TypeExpression.record([try Name(spelling): .int])

        // When
        let written = try Writer().value(of: type)
        let read = try await Loader().load([
            "warp": 1,
            "imports": [],
            "procedures": ["entry": ["parameters": [["name": "f", "type": written]], "result": Value.null]]
        ])

        // Then
        #expect(written == .dictionary(["record": .dictionary([try Name(spelling): "int"])]))
        #expect(read.procedures["entry"]?.signature.parameter(named: "f")?.type == type)
    }

    @Test(
        "a name is written only where the reading takes the spelling back as it",
        arguments: ["var Task", "array<int>", "some T", "int", "Task?"]
    )
    func aNameTheReadingTakesOtherwiseIsNotWritten(spelling: String) throws {
        // Given. A name is written as itself, so a spelling the reading makes
        // anything else of is a name no document can say
        let type = TypeExpression.named(try Name(spelling))

        // When / Then
        #expect(throws: WritingError.self) {
            try Writer().value(of: type)
        }
    }

    @Test("a plain name is written as itself and read back as itself")
    func aPlainNameRoundTrips() throws {
        let type = TypeExpression.named("app.Task")

        #expect(try Writer().value(of: type) == .string("app.Task"))
        #expect(try TypeReader.parse("app.Task") == type)
    }

    @Test("isolated is read in either order and written in one", arguments: [
        ("isolated procedure", TypeExpression.procedure(nil, .unstated, .isolated), "isolated procedure"),
        ("const isolated procedure", .procedure(nil, .const, .isolated), "const isolated procedure"),
        ("isolated const procedure", .procedure(nil, .const, .isolated), "const isolated procedure")
    ])
    func isolationIsReadEitherWay(written: String, expected: TypeExpression, canonical: String) throws {
        let parsed = try TypeReader.parse(written)

        #expect(parsed == expected)
        #expect(try Writer().value(of: parsed) == .string(canonical))
    }

    @Test("a mark and a modifier on one procedure form survive the round trip")
    func aMarkAndAModifierRoundTrip() async throws {
        // Given. A parameter typed `inout const procedure<...>`, which the
        // writer spells as a form under one key
        let type = TypeExpression.inout(.procedure(ProcedureType(returns: .int), .const))

        // When
        let written = try Writer().value(of: type)
        let module = try await Loader().load([
            "warp": 1,
            "imports": [],
            "procedures": ["entry": ["parameters": [["name": "f", "type": written]], "result": Value.null]]
        ])

        // Then
        #expect(written == .dictionary(["inout const procedure": .dictionary(["returns": "int"])]))
        #expect(module.procedures["entry"]?.signature.parameter(named: "f")?.type == type)
    }

    @Test("a procedure written twice is refused", arguments: [
        "inout inout int", "var var int", "const const procedure", "isolated isolated procedure",
        "consuming consuming Handle", "consuming borrowing Handle", "borrowing inout Handle"
    ])
    func aModifierWrittenTwiceIsRefused(written: String) {
        #expect(throws: TypeFormError.self) {
            try TypeReader.parse(written)
        }
    }

    @Test("a record field named like a construct is data on the way out and back")
    func aFieldNamedLikeAConstructStaysData() throws {
        // Given. A statement whose value is a record literal with one field
        // spelled like a construct key
        let loader = Loader()
        let module = try Module(
            imports: [],
            procedures: [
                "entry": Procedure(
                    access: .public,
                    body: [Statement(binding: .constant("x"), expression: .literal(.dictionary(["loop": .int(1)])))],
                    result: .reference([.key("x")])
                )
            ]
        )

        // When
        let written = try Writer(registry: loader.registry).value(of: module)
        let read = try loader.load(written)

        // Then. Written under `record`, and read back as the record it was
        guard case let .array(body)? = written["procedures"]?["entry"]?["body"] else {
            Issue.record("the body was not written as an array")
            return
        }

        #expect(body.first?["value"] == .dictionary(["record": .dictionary(["loop": 1])]))
        #expect(read.procedures["entry"]?.body.first?.expression.constantValue == .dictionary(["loop": .int(1)]))
    }

    @Test("a module's var and a set path survive the round trip")
    func moduleVariableAndSetPathRoundTrip() throws {
        // Given
        let loader = Loader()
        let written: Value = [
            "warp": 1,
            "imports": [],
            "var": ["total": 0],
            "procedures": [
                "entry": [
                    "body": [
                        ["var": "p", "value": ["record": ["x": 1]]],
                        ["set": "p.x", "value": 2],
                        ["set": "total", "value": ["ref": "p.x"]]
                    ],
                    "result": ["ref": "total"]
                ]
            ]
        ]

        // When
        let module = try loader.load(written)

        // Then
        #expect(module.variables["total"]?.start.constantValue == .int(0))
        #expect(
            module.procedures["entry"]?.body[1].binding
                == .assignment([.key("p"), .key("x")])
        )
        #expect(try Writer(registry: loader.registry).value(of: module) == written)
    }
}
