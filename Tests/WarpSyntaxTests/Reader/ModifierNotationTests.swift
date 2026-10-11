//
//  ModifierNotationTests.swift
//  WarpSyntaxTests
//
//  Created by JSilver on 9/3/26.
//

import Foundation
import Testing
@testable import Warp
@testable import WarpSyntax

@Suite("The keywords a slot writes about itself")
struct ModifierNotationTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("a mark stands in front of the whole type", arguments: [
        ("inout Int", TypeExpression.inout(.int)),
        ("inout Int?", .inout(.nullable(.int))),
        ("var Array<Int>", .variable(.array(.int))),
        ("inout Procedure", .inout(.procedure(nil)))
    ])
    func everyMarkStandsInFrontOfTheWholeType(written: String, expected: TypeExpression) throws {
        // When / Then
        #expect(try TypeReader.parse(written) == expected)
    }

    @Test("every mark reads and writes back, whichever ones there are", arguments: SlotMark.allCases)
    func everyMarkRoundTrips(mark: SlotMark) throws {
        // Given. Both forms a marked type takes: a name, and a procedure
        // under its one key
        let named = mark.marking(.named("Handle"))
        let form = mark.marking(.procedure(ProcedureType(returns: .int)))

        // When
        let writtenName = try Writer().value(of: named)
        let writtenForm = try Writer().value(of: form)

        // Then
        #expect(writtenName == .string("\(mark.word) Handle"))
        #expect(try TypeReader.parse("\(mark.word) Handle") == named)
        #expect(SlotMark.marked(named) == mark)

        #expect(
            writtenForm == .dictionary([
                try Name("\(mark.word) procedure"): .dictionary(["returns": "Int"])
            ])
        )

        // And the form reads back where the mark may stand: `inout` in front
        // of a parameter, `var` on a declared type's field
        switch mark {
        case .inout:
            let read = try Loader().load([
                "warp": 1,
                "imports": [],
                "procedures": ["entry": ["parameters": [["name": "f", "type": writtenForm]]]]
            ])

            #expect(read.procedures["entry"]?.signature.parameter(named: "f")?.type == form)

        case .variable:
            let read = try Loader().load([
                "warp": 1,
                "imports": [],
                "procedures": ["entry": ["result": 1]],
                "types": ["Box": ["record": ["f": writtenForm]]]
            ])

            #expect(read.types["Box"] == .record(["f": form]))
        }
    }

    @Test(
        "a mark inside a mark is written as it is where a name carries it, and has no procedure form",
        arguments: SlotMark.allCases, SlotMark.allCases
    )
    func aMarkInsideAMarkIsWrittenAsItIs(mark: SlotMark, inside: SlotMark) throws {
        // Given
        let named = mark.marking(inside.marking(.named("Handle")))

        // When / Then. A name takes both in front of it, and reads back as it
        // was written
        #expect(try Writer().value(of: named) == .string("\(mark.word) \(inside.word) Handle"))
        #expect(try TypeReader.parse("\(mark.word) \(inside.word) Handle") == named)

        // And a procedure's key carries one
        #expect(throws: WritingError.self) {
            try Writer().value(of: mark.marking(inside.marking(.procedure(ProcedureType(returns: .int)))))
        }
    }

    @Test(
        "a mark inside a mark is refused where the document is read, whichever two they are",
        arguments: SlotMark.allCases, SlotMark.allCases
    )
    func aMarkInsideAMarkIsRefused(mark: SlotMark, inside: SlotMark) throws {
        // When / Then. Each mark stands where it may alone, and no slot takes
        // two
        #expect(throws: ValidationError.self) {
            try Loader().load([
                "warp": 1,
                "imports": [],
                "procedures": ["entry": ["result": 1]],
                "types": ["Box": ["record": ["f": .string("\(mark.word) \(inside.word) Int")]]]
            ])
        }

        #expect(throws: ValidationError.self) {
            try Loader().load([
                "warp": 1,
                "imports": [],
                "procedures": [
                    "entry": ["parameters": [["name": "f", "type": .string("\(mark.word) \(inside.word) Int")]]]
                ]
            ])
        }
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
        #expect(try TypeReader.parse("\(mark.word) Task?") == mark.marking(.nullable(.named("Task"))))
    }

    @Test(
        "a declared record's field is named whatever the document named it",
        arguments: ["procedure", "var procedure", "var inout procedure", "const isolated Procedure", "array", "record", "var inout x"]
    )
    func aRecordsFieldMayBeNamedLikeAForm(spelling: String) throws {
        // Given. A record is declared under `record`, so its field names are
        // never keys the reading takes as a form or a mark
        let declared = TypeDeclaration.record([try Name(spelling): .int])
        let module = try Module(types: ["App.T": declared], procedures: ["entry": Procedure(body: [], result: .literal(.int(1)))])

        // When
        let written = try Writer().value(of: module)
        let read = try Loader().load(written)

        // Then
        #expect(try Writer().value(of: declared) == .dictionary(["record": .dictionary([try Name(spelling): "Int"])]))
        #expect(read.types["App.T"] == declared)
    }

    @Test(
        "a name is written only where the reading takes the spelling back as it",
        arguments: ["var Task", "Array<Int>", "some T", "Int", "Task?"]
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
        // Given
        let type = TypeExpression.named("App.Task")

        // When / Then
        #expect(try Writer().value(of: type) == .string("App.Task"))
        #expect(try TypeReader.parse("App.Task") == type)
    }

    @Test("isolated is read in either order and written in one", arguments: [
        ("isolated Procedure", TypeExpression.procedure(nil, .unstated, .isolated), "isolated Procedure"),
        ("const isolated Procedure", .procedure(nil, .const, .isolated), "const isolated Procedure"),
        ("isolated const Procedure", .procedure(nil, .const, .isolated), "const isolated Procedure")
    ])
    func isolationIsReadEitherWay(written: String, expected: TypeExpression, canonical: String) throws {
        // When
        let parsed = try TypeReader.parse(written)

        // Then
        #expect(parsed == expected)
        #expect(try Writer().value(of: parsed) == .string(canonical))
    }

    @Test("a mark and a modifier on one procedure form survive the round trip")
    func aMarkAndAModifierRoundTrip() throws {
        // Given. A parameter typed `inout const Procedure<...>`, which the
        // writer spells as a form under one key
        let type = TypeExpression.inout(.procedure(ProcedureType(returns: .int), .const))

        // When
        let written = try Writer().value(of: type)
        let module = try Loader().load([
            "warp": 1,
            "imports": [],
            "procedures": ["entry": ["parameters": [["name": "f", "type": written]]]]
        ])

        // Then
        #expect(written == .dictionary(["inout const procedure": .dictionary(["returns": "Int"])]))
        #expect(module.procedures["entry"]?.signature.parameter(named: "f")?.type == type)
    }

    @Test("a modifier written twice is refused", arguments: [
        "const const Procedure", "isolated isolated Procedure"
    ])
    func aModifierWrittenTwiceIsRefused(written: String) {
        // When / Then
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
                    body: [Statement(binding: .constant("x"), expression: .record(["loop": .literal(.int(1))]))],
                    result: .reference([.name("x")])
                )
            ]
        )

        // When
        let written = try Writer(registry: loader.registry).value(of: module)
        let read = try loader.load(written)

        // Then. Written under `record`, and read back as the record it was
        guard case let .array(body)? = written.map?["procedures"]?.map?["entry"]?.map?["body"] else {
            Issue.record("the body was not written as an array")
            return
        }

        #expect(body.first?.map?["value"] == .dictionary(["record": .dictionary(["loop": 1])]))
        guard case let .record(fields)? = read.procedures["entry"]?.body.statements.first?.expression else {
            Issue.record("the record literal was not read back as one")
            return
        }

        #expect(fields["loop"]?.constantValue == .int(1))
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
            module.procedures["entry"]?.body.statements[1].binding
                == .assignment([.name("p"), .name("x")])
        )
        #expect(try Writer(registry: loader.registry).value(of: module) == written)
    }

    // MARK: - Public
    // MARK: - Private
}
