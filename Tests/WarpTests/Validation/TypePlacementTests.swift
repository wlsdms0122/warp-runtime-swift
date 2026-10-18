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
                types: ["Weird": .alias(.parameter(name: "T"))],
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
                    "Callback": .alias(.procedure(ProcedureType(
                        parameters: [.parameter(name: "T")],
                        failing: .anything
                    )))
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
                types: ["Box": .struct(["held": .inout(.int)])],
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
            error is ValidationError && "\(error)".contains("`var` is written on a field of the struct a type in `types` declares")
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

    @Test("a ? and a slot mark stand on a procedure type as on any type", arguments: [
        TypeExpression.nullable(.procedure(ProcedureType(returns: .int, failing: .anything))),
        .nullable(.array(.procedure(ProcedureType(returns: .int, failing: .anything)))),
        .inout(.array(.procedure(ProcedureType(returns: .int, failing: .anything)))),
        .inout(.procedure(ProcedureType(returns: .int, failing: .anything)))
    ])
    func aMarkOnAProcedureTypeStands(type: TypeExpression) throws {
        // When / Then. Every type has a spelling, so a module made in Swift
        // writes these as a document does
        #expect(throws: Never.self) {
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
        }
    }

    @Test("var stands on a field of the struct a declared type is, and nowhere inside an alias", arguments: [
        TypeExpression.variable(.int),
        .array(.variable(.int)),
        .dictionary(key: .string, value: .variable(.int))
    ])
    func aVarInsideADeclaredTypeIsRefused(type: TypeExpression) throws {
        // When / Then. A field is a declared struct's, and nothing else is
        // written through
        #expect {
            try Module(types: ["App.T": .alias(type)])
        } throws: { error in
            error is ValidationError && "\(error)".contains("`var` is written on a field of the struct")
        }

        // And on the declared struct's own field it stands
        #expect(throws: Never.self) {
            try Module(types: ["App.T": .struct(["a": .variable(.int)])])
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

    // MARK: - Public
    // MARK: - Private
}
