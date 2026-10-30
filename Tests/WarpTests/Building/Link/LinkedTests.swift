//
//  LinkedTests.swift
//  WarpTests
//
//  Created by JSilver on 10/23/26.
//

import Foundation
import Testing
@testable import Warp
import WarpTestSupport

@Suite("A row as a link holds it")
struct LinkedTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("names its type parameters in the order its slots and then its return type first name them")
    func typeParametersStandInTheOrderFirstNamed() {
        // Given
        let signature = Signature(
            parameters: [
                Parameter(name: "list", type: .array(.parameter(name: "U"))),
                Parameter(name: "item", type: .parameter(name: "T")),
                Parameter(name: "more", type: .array(.parameter(name: "U")))
            ],
            returns: .dictionary(key: .parameter(name: "V"), value: .parameter(name: "T"))
        )

        // When
        let sut = Self.row(signed: signature)

        // Then
        #expect(sut.typeParameters == ["U", "T", "V"])
    }

    @Test("refuses a call handing another count of types than it names type parameters")
    func refusesAnotherCountOfTypes() {
        // Given
        let sut = Self.row(signed: Signature(parameters: [Parameter(name: "item", type: .parameter(name: "T"))]))

        // When / Then
        #expect(throws: BuildError.self) {
            try sut.refuseCall(standing: 1, handing: 0, at: Place(in: .assembled))
        }
        #expect(throws: Never.self) {
            try sut.refuseCall(standing: 1, handing: 1, at: Place(in: .assembled))
        }
    }

    @Test("holds a call through a contract to its count of arguments alone")
    func holdsADispatchToItsArgumentsAlone() {
        // Given. A row a dispatch reaches is handed what fills its type
        // parameters off the types the dispatch writes, so its laid call
        // hands none of its own
        let sut = Self.row(signed: Signature(parameters: [Parameter(name: "item", type: .parameter(name: "T"))]))

        // When / Then
        #expect(throws: Never.self) {
            try sut.refuseCall(standing: 1, at: Place(in: .assembled))
        }
        #expect(throws: BuildError.self) {
            try sut.refuseCall(standing: 2, at: Place(in: .assembled))
        }
    }

    // MARK: - Public
    // MARK: - Private
    // A row with a body that does nothing, under this signature.
    private static func row(signed signature: Signature) -> Linked {
        Linked(
            label: "App.f",
            origin: 0,
            signature: signature,
            access: .internal,
            implementation: .body(
                LoweredBody(instructions: []),
                Frame(
                    size: signature.parameters.count,
                    parameters: Array(signature.parameters.indices),
                    variables: [],
                    captures: [],
                    names: signature.parameters.map(\.name)
                )
            ),
            foldable: true,
            in: TypeTable.empty.loweredTypes
        )
    }
}
