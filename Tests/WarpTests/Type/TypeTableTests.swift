//
//  TypeTableTests.swift
//  WarpTests
//
//  Created by JSilver on 10/1/26.
//

import Foundation
import Testing
@testable import Warp

@Suite("A type table a host asks")
struct TypeTableTests {
    // MARK: - Property
    private let types = TypeTable(
        types: [:],
        constraints: [
            "app.Ordered": [.int, .double, .string]
        ]
    )

    // MARK: - Initializer
    // MARK: - Test
    @Test("a host's door refuses an undeclared name with the path in front")
    func aDoorRefusesAnUndeclaredNameWithItsPath() {
        // When / Then
        #expect {
            try TypeExpression.named("bank.Vault").settling(.int(1), at: "input 'x'", in: types)
        } throws: { error in
            "\(error)".contains("input 'x': declares type 'bank.Vault', which nothing declares")
        }
        #expect(TypeExpression.named("bank.Vault").accepts(.int, in: types))
    }

    @Test("a host asks a constraint about a value through the document's table")
    func aHostAsksMembershipOfAValue() {
        // When / Then
        #expect(types.admits(constraint: "app.Ordered", value: .int(1)) == true)
        #expect(types.admits(constraint: "app.Ordered", value: .bool(true)) == false)
        #expect(types.admits(constraint: "app.Nobody", value: .int(1)) == nil)
    }

    @Test("a table built by hand whose names form a cycle answers instead of chasing them")
    func aCycleOfNamesIsRefusedNotChased() {
        // Given
        let circular = TypeTable(types: ["app.A": .named("app.B"), "app.B": .named("app.A"), "app.C": .int])

        // When / Then. The cycle is refused where it is met, and the row
        // beside it answers as itself
        #expect {
            try TypeExpression.named("app.A").settling(.int(1), at: "input", in: circular)
        } throws: { error in
            "\(error)".contains("input: declares type 'app.A', which names itself")
        }
        #expect(!TypeExpression.named("app.A").declaresNull(in: circular))
        #expect(TypeExpression.named("app.C").accepts(.int, in: circular))
        #expect(TypeExpression.nullable(.named("app.C")).declaresNull(in: circular))
    }

    @Test("a reading naming an undeclared constraint passes membership, since nothing is proven of it")
    func anUndeclaredReadingPassesMembership() {
        // Given
        let reading = TypeExpression.parameter(name: "T", constraints: ["app.Nobody"])

        // When / Then
        #expect(types.admits(constraint: "app.Ordered", reading: reading) == true)
    }

    @Test("a hand-built table ends its own membership recursion")
    func aHandBuiltTableTerminates() throws {
        // Given. A table nothing linked, holding the declaration the build would
        // have refused; the table answers rather than chasing it
        let sut = TypeTable(
            constraints: ["Loop": [.parameter(name: "S", constraints: ["Loop"])]]
        )

        // When / Then
        #expect(
            sut.admits(
                constraint: "Loop",
                reading: .parameter(name: "T", constraints: ["Loop"])
            ) == true
        )
        let table = sut.loweredTypes
        let loop = try #require(table.constraintRow(named: "Loop"))

        // A value asked of the same membership again is the question come
        // back, which takes nothing
        #expect(table.admits(constraint: loop, value: .int(1), asking: .nothing) == false)
    }

    // MARK: - Public
    // MARK: - Private
}
