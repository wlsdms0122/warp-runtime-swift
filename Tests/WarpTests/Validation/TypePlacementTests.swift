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

// Where each word a type writes may stand, and the head of a write: facts of
// a module's text, held at the load by the Validator for every module.
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

    @Test("a document writes only the variables it declares")
    func aDocumentWritesOnlyItsOwnVariables() {
        // Given. One write of `total`
        let write = Statement(binding: .assignment([.key("total")]), expression: .literal(.int(1)))

        // When / Then. Taken at the load of the document declaring
        // `total`, and refused at the load of one that does not
        #expect(throws: Never.self) {
            try Module(
                variables: ["total": .literal(.int(0))],
                procedures: ["App.poke": Procedure(body: [write])]
            )
        }
        #expect {
            try Module(procedures: ["Other.poke": Procedure(body: [write])])
        } throws: { error in
            error is ValidationError && "\(error)".contains("assigns 'total', which is not visible here")
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
            error is ValidationError && "\(error)".contains("only a field of a declared type is written through")
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
            error is ValidationError && "\(error)".contains("only a field of a declared type is written through")
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

    // MARK: - Public
    // MARK: - Private
}
