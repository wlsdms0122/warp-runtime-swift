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
    private let types = TypeTable.empty

    // MARK: - Initializer
    // MARK: - Test
    @Test("a host's door refuses an undeclared name with the path in front")
    func aDoorRefusesAnUndeclaredNameWithItsPath() {
        // When / Then
        #expect {
            try TypeExpression.named("Bank.Vault").settling(.int(1), at: "input 'x'", in: types)
        } throws: { error in
            "\(error)".contains("input 'x': declares type 'Bank.Vault', which nothing declares")
        }
        #expect(TypeExpression.named("Bank.Vault").accepts(.int, in: types))
    }

    @Test("a table built by hand whose names form a cycle answers instead of chasing them")
    func aCycleOfNamesIsRefusedNotChased() {
        // Given
        let circular = TypeTable(types: ["App.A": .named("App.B"), "App.B": .named("App.A"), "App.C": .int])

        // When / Then. The cycle is refused where it is met, and the row
        // beside it answers as itself
        #expect {
            try TypeExpression.named("App.A").settling(.int(1), at: "input", in: circular)
        } throws: { error in
            "\(error)".contains("input: declares type 'App.A', which names itself")
        }
        #expect(!TypeExpression.named("App.A").declaresNull(in: circular))
        #expect(TypeExpression.named("App.C").accepts(.int, in: circular))
        #expect(TypeExpression.nullable(.named("App.C")).declaresNull(in: circular))
    }

    // MARK: - Public
    // MARK: - Private
}
