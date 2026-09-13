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
    @Test("inout and var stand in front of the whole type", arguments: [
        ("inout int", TypeExpression.inout(.int)),
        ("inout int?", .inout(.nullable(.int))),
        ("var array<int>", .variable(.array(.int))),
        ("inout procedure", .inout(.procedure(nil))),
        ("consuming Handle", .consuming(.named("Handle"))),
        ("borrowing Handle", .borrowing(.named("Handle")))
    ])
    func slotKeywordsWrapTheWholeType(written: String, expected: TypeExpression) throws {
        #expect(try TypeReader.parse(written) == expected)
    }

    @Test("every mark reads and writes back, whichever ones there are", arguments: SlotMark.allCases)
    func everyMarkRoundTrips(mark: SlotMark) throws {
        // Given. The reading, the writing and the document's vocabulary all
        // come off one list, so a mark added to it is asked these questions
        // without anyone remembering to ask
        let type = mark.marking(.named("Handle"))

        // When
        let written = try Writer().value(of: type)

        // Then
        #expect(try TypeReader.parse("\(mark.rawValue) Handle") == type)
        #expect(written == .string("\(mark.rawValue) Handle"))
        #expect(type.slotMark == mark)
    }

    @Test("a mark inside a mark is refused, whichever two they are", arguments: SlotMark.allCases)
    func aMarkInsideAMarkIsRefused(mark: SlotMark) throws {
        for inside in SlotMark.allCases {
            #expect(throws: TypeFormError.self) {
                try TypeReader.parse("\(mark.rawValue) \(inside.rawValue) Handle")
            }
        }
    }

    @Test("isolated is read in either order and written in one", arguments: [
        ("isolated procedure", TypeExpression.procedure(nil, .unstated, .isolated), "isolated procedure"),
        ("pure isolated procedure", .procedure(nil, .pure, .isolated), "pure isolated procedure"),
        ("isolated pure procedure", .procedure(nil, .pure, .isolated), "pure isolated procedure")
    ])
    func isolationIsReadEitherWay(written: String, expected: TypeExpression, canonical: String) throws {
        let parsed = try TypeReader.parse(written)

        #expect(parsed == expected)
        #expect(try Writer().value(of: parsed) == .string(canonical))
    }

    @Test("a slot keyword and a modifier on one procedure form survive the round trip")
    func slotKeywordAndModifierRoundTrip() throws {
        // Given. A parameter typed `inout pure procedure<...>`, which the
        // writer spells as a form under one key
        let type = TypeExpression.inout(.procedure(Signature(returns: .int), .pure))

        // When
        let written = try Writer().value(of: type)
        let module = try Loader().load([
            "warp": 1,
            "imports": [],
            "procedures": ["entry": ["parameters": ["f": ["type": written]], "result": Value.null]]
        ])

        // Then
        #expect(written == .dictionary(["inout pure procedure": .dictionary(["returns": "int"])]))
        #expect(module.procedures["entry"]?.signature.parameters["f"]?.type == type)
    }

    @Test("a procedure written twice is refused", arguments: [
        "inout inout int", "var var int", "pure pure procedure", "isolated isolated procedure",
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
                    body: [Statement(binding: .constant("x"), expression: .literal(.dictionary(["loop": .int(1)])))],
                    result: .reference([.key("x")])
                )
            ]
        )

        // When
        let written = try Writer(registry: loader.registry).value(of: module)
        let read = try loader.load(written)

        // Then. Quoted under `value`, and read back as the record it was
        guard case let .array(body)? = written["procedures"]?["entry"]?["body"] else {
            Issue.record("the body was not written as an array")
            return
        }

        #expect(body.first?["value"] == .dictionary(["value": .dictionary(["loop": 1])]))
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
                        ["var": "p", "value": ["x": 1]],
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
        #expect(module.variables["total"]?.constantValue == .int(0))
        #expect(
            module.procedures["entry"]?.body[1].binding
                == .assignment([.key("p"), .key("x")])
        )
        #expect(try Writer(registry: loader.registry).value(of: module) == written)
    }
}
