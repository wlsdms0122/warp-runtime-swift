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

@Suite("The words a slot writes about itself")
struct ModifierNotationTests {
    @Test("inout and var stand in front of the whole type", arguments: [
        ("inout int", TypeExpression.inout(.int)),
        ("inout int?", .inout(.nullable(.int))),
        ("var array<int>", .variable(.array(.int))),
        ("inout procedure", .inout(.procedure(nil)))
    ])
    func slotWordsWrapTheWholeType(written: String, expected: TypeExpression) throws {
        #expect(try TypeReader.parse(written) == expected)
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

    @Test("a slot word and a modifier on one procedure form survive the round trip")
    func slotWordAndModifierRoundTrip() throws {
        // Given — a parameter typed `inout pure procedure<...>`, which the writer
        // spells as a form under one key
        let type = TypeExpression.inout(.procedure(Signature(returns: .int), .pure))

        // When
        let written = try Writer().value(of: type)
        let module = try Loader().load([
            "warp": 2,
            "imports": [],
            "procedures": ["entry": ["parameters": ["f": ["type": written]], "result": Value.null]]
        ])

        // Then
        #expect(written == .object(["inout pure procedure": .object(["returns": "int"])]))
        #expect(module.procedures["entry"]?.signature.parameters["f"]?.type == type)
    }

    @Test("a word written twice is refused", arguments: [
        "inout inout int", "var var int", "pure pure procedure", "isolated isolated procedure"
    ])
    func aWordWrittenTwiceIsRefused(written: String) {
        #expect(throws: TypeFormError.self) {
            try TypeReader.parse(written)
        }
    }

    @Test("a record field named like a construct is data on the way out and back")
    func aFieldNamedLikeAConstructStaysData() throws {
        // Given — a statement whose value is a record literal with one field
        // spelled like a construct key
        let loader = Loader()
        let module = try Module(
            imports: [],
            procedures: [
                "entry": Procedure(
                    body: [Statement(binding: .constant("x"), expression: .literal(.object(["loop": .int(1)])))],
                    result: .reference([.key("x")])
                )
            ]
        )

        // When
        let written = try Writer(registry: loader.registry).value(of: module)
        let read = try loader.load(written)

        // Then — quoted under `value`, and read back as the record it was
        guard case let .array(body)? = written["procedures"]?["entry"]?["body"] else {
            Issue.record("the body was not written as an array")
            return
        }

        #expect(body.first?["value"] == .object(["value": .object(["loop": 1])]))
        #expect(read.procedures["entry"]?.body.first?.expression.constantValue == .object(["loop": .int(1)]))
    }

    @Test("a module's var and a set path survive the round trip")
    func moduleVariableAndSetPathRoundTrip() throws {
        // Given
        let loader = Loader()
        let written: Value = [
            "warp": 2,
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
