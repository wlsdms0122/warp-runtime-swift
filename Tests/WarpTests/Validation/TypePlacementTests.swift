//
//  TypePlacementTests.swift
//  WarpTests
//
//  Created by JSilver on 10/9/26.
//

import Foundation
import Testing
@testable import Warp
import WarpTestSupport

// Where each word a type writes may stand: facts of a module's text, held at
// the load by the Validator for every module.
@Suite("Every word a type writes stands where it may, held at the load")
struct TypePlacementTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("a type parameter hidden in a declared type refuses at the load")
    func aParameterInADeclaredTypeRefusesAtTheLoad() throws {
        // When / Then. A declared type has no call to fill a parameter
        #expect {
            try Module(
                types: ["Weird": .parameter(name: "T")],
                procedures: [
                    "keep": Procedure(
                        signature: Signature(
                            parameters: [Parameter(name: "value", type: .named("Weird"))]
                        ),
                        body: [],
                        result: reference("value")
                    ),
                    entryName: Procedure(
                        access: .public,
                        signature: Signature(),
                        body: [],
                        result: .literal(.int(1))
                    )
                ]
            )
        } throws: { error in
            error is ValidationError && "\(error)".contains("A type parameter lives in a signature")
        }
    }

    @Test("a parameter behind a procedure type in a declared type refuses too")
    func aParameterInADeclaredProcedureTypeRefusesAtTheLoad() throws {
        // When / Then. A declared type is not a filling site however deep the
        // parameter hides
        #expect {
            try Module(
                types: [
                    "Callback": .procedure(ProcedureType(
                        parameters: [.parameter(name: "T")]
                    ))
                ],
                procedures: [
                    entryName: Procedure(
                        access: .public,
                        signature: Signature(),
                        body: [],
                        result: .literal(.int(1))
                    )
                ]
            )
        } throws: { error in
            error is ValidationError && "\(error)".contains("A type parameter lives in a signature")
        }
    }

    @Test("a name declaring a type parameter is refused, because no call fills a name")
    func aDeclaredTypeParameterIsRefused() throws {
        // When / Then
        #expect {
            try Module(
                procedures: [
                    entryName: Procedure(
                        access: .public,
                        body: [
                            Statement(binding: .constant("held", declared: .parameter(name: "T")), expression: .literal(.int(1)))
                        ],
                        result: reference("held")
                    )
                ]
            )
        } throws: { error in
            error is ValidationError && "\(error)".contains("writes `some T`, and nothing here is filled by a call")
        }
    }

    @Test("inout is written on a parameter and nowhere else")
    func inoutOutsideAParameterRefuses() throws {
        // When / Then. A declared type with an inout field
        #expect {
            try Module(
                imports: [],
                types: ["Box": .record(["held": .inout(.int)])],
                procedures: [entryName: Procedure(access: .public, body: [], result: .literal(.null))]
            )
        } throws: { error in
            error is ValidationError && "\(error)".contains("only a parameter is handed a variable in place")
        }
    }

    @Test("var is written on a declared type's field and nowhere else")
    func varOutsideADeclaredFieldRefuses() throws {
        // When / Then. A parameter typed var
        #expect {
            try Module(
                imports: [],
                procedures: [
                    entryName: Procedure(
                        access: .public,
                        signature: Signature(parameters: [Parameter(name: "count", type: .variable(.int))]),
                        body: [],
                        result: .literal(.null)
                    )
                ]
            )
        } throws: { error in
            error is ValidationError && "\(error)".contains("`var` is written on a field of the record a type in `types` declares")
        }
    }

    @Test("var is not written on a field of a record a name or a module variable says it holds")
    func varOnAHeldRecordFieldRefuses() throws {
        // Given. A record type written inline declares no type, so it has no
        // field a path writes through
        let held = TypeExpression.record(["a": .variable(.int)])

        // When / Then
        #expect {
            try Module(
                procedures: [
                    entryName: Procedure(
                        access: .public,
                        body: [Statement(binding: .constant("x", declared: held), expression: .record(["a": .literal(.int(1))]))],
                        result: .literal(.null)
                    )
                ]
            )
        } throws: { error in
            error is ValidationError && "\(error)".contains("`var` is written on a field of the record a type in `types` declares")
        }

        #expect {
            try Module(
                variables: ["x": ModuleVariable(.record(["a": .literal(.int(1))]), declared: held)],
                procedures: [entryName: Procedure(access: .public, body: [], result: .literal(.null))]
            )
        } throws: { error in
            error is ValidationError && "\(error)".contains("variables.x.fields.a: writes `var Int`")
        }
    }

    @Test("a ? that says nothing new is refused where it is written", arguments: [
        TypeExpression.nullable(.nullable(.int)), .nullable(.null), .nullable(.any), .nullable(.never),
        .nullable(.parameter(name: "T"))
    ])
    func aNeedlessQuestionMarkIsRefused(type: TypeExpression) throws {
        // When / Then. Twice says it once too often; what already admits null
        // gains nothing; never admits nothing; a parameter stands for the whole
        // filled type
        #expect {
            try Module(
                procedures: [
                    entryName: Procedure(
                        access: .public,
                        signature: Signature(parameters: [Parameter(name: "x", type: type)]),
                        body: [],
                        result: .literal(.null)
                    )
                ]
            )
        } throws: { error in
            error is ValidationError && "\(error)".hasPrefix("procedures.entry.parameters[0]: ")
                && "\(error)".contains("a `?` says nothing")
        }
    }

    @Test("a ? and a slot mark stand only where a type is written as a spelling", arguments: [
        (TypeExpression.nullable(.record(["a": .int])), "a `?` trails a type's spelling"),
        (.nullable(.procedure(ProcedureType(returns: .int))), "a `?` trails a type's spelling"),
        (.nullable(.array(.record(["a": .int]))), "a `?` trails a type's spelling"),
        (.inout(.record(["a": .int])), "a mark stands in front of a type's spelling"),
        (.inout(.array(.procedure(ProcedureType(returns: .int)))), "a mark stands in front of a type's spelling")
    ])
    func aMarkWithNoSpellingIsRefused(type: TypeExpression, refusal: String) throws {
        // When / Then. An inline record and a written signature are mappings
        // under one key, with nothing for a `?` to trail or a mark to stand
        // before; a module made in Swift is held to it where it is made
        #expect {
            try Module(
                procedures: [
                    entryName: Procedure(
                        access: .public,
                        signature: Signature(parameters: [Parameter(name: "x", type: type)]),
                        body: [],
                        result: .literal(.null)
                    )
                ]
            )
        } throws: { error in
            error is ValidationError && "\(error)".hasPrefix("procedures.entry.parameters[0]: ")
                && "\(error)".contains(refusal)
        }

        // And a mark on a procedure type's key, and a `?` on a spelling, stand
        let marked = TypeExpression.inout(.procedure(ProcedureType(returns: .int)))

        #expect(throws: Never.self) {
            try Module(
                types: ["App.R": .record(["a": .variable(.nullable(.array(.int)))])],
                procedures: [
                    entryName: Procedure(
                        access: .public,
                        signature: Signature(parameters: [Parameter(name: "x", type: marked)]),
                        body: [],
                        result: .literal(.null)
                    )
                ]
            )
        }
    }

    @Test("var stands on a field of the record a declared type is, and on no record inside it", arguments: [
        TypeExpression.array(.record(["a": .variable(.int)])),
        .record(["b": .record(["c": .variable(.int)])]),
        .dictionary(.record(["a": .variable(.int)]))
    ])
    func aVarInsideADeclaredTypeIsRefused(type: TypeExpression) throws {
        // When / Then. An inline record's fields are written through as they
        // are, so `var` there says nothing
        #expect {
            try Module(types: ["App.T": type], procedures: [:])
        } throws: { error in
            error is ValidationError && "\(error)".contains("`var` is written on a field of the record")
        }

        // And on the declared record's own field it stands
        #expect(throws: Never.self) {
            try Module(types: ["App.T": .record(["a": .variable(.int)])], procedures: [:])
        }
    }

    @Test("a composition joins two contracts or more, however the module was made", arguments: [
        TypeExpression.composition([]), .composition(["App.A"])
    ])
    func aCompositionOfFewerThanTwoIsRefused(type: TypeExpression) throws {
        // When / Then. One contract is written by its name
        #expect {
            try Module(
                procedures: [
                    entryName: Procedure(
                        access: .public,
                        signature: Signature(parameters: [Parameter(name: "x", type: type)]),
                        body: [],
                        result: .literal(.null)
                    )
                ]
            )
        } throws: { error in
            error is ValidationError && "\(error)".contains("`&` joins two contracts or more")
        }
    }

    @Test("a type read out of a body is no declaration anybody can write")
    func aProjectionIsRefusedWhereADeclarationGoes() throws {
        // When / Then. A declaration assembled in the host claiming what only
        // a walk produces: a declaration says what a call fills, and nothing
        // fills a path only one body can read
        #expect {
            try Module(
                procedures: [
                    entryName: Procedure(
                        access: .public,
                        signature: Signature(
                            parameters: [Parameter(name: "of", type: .projection(of: "T", path: [.key("inner")]))]
                        ),
                        body: [],
                        result: .literal(.null)
                    )
                ]
            )
        } throws: { error in
            error is ValidationError && "\(error)".hasPrefix("procedures.entry.parameters[0]: ")
                && "\(error)".contains("read out of a body")
        }
    }

    // MARK: - Public
    // MARK: - Private
}
