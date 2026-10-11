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
    // MARK: - Initializer
    // MARK: - Test
    @Test("a table naming a type nothing declares refuses as a document declaring it does")
    func aTableNamingNothingRefuses() {
        // When / Then
        #expect {
            try TypeTable(types: ["Bank.Account": .record(["vault": .named("Bank.Vault")])])
        } throws: { error in
            "\(error)".contains("names type 'Bank.Vault', which no module in this link declares")
        }
    }

    @Test("a table whose names come back to themselves refuses as a document declaring them does")
    func aCycleOfNamesRefuses() {
        // When / Then. Through `?` and a structure as well, and a chain that
        // ends stands
        for types: [Name: TypeExpression] in [
            ["App.A": .named("App.B"), "App.B": .named("App.A"), "App.C": .int],
            ["App.M": .nullable(.named("App.M"))],
            ["App.L": .dictionary(key: .string, value: .named("App.L"))]
        ] {
            #expect {
                try TypeTable(types: types)
            } throws: { error in
                "\(error)".contains("names itself through what it stands for")
            }
        }
        #expect(throws: Never.self) {
            try TypeTable(types: ["App.T": .nullable(.named("App.Leaf")), "App.Leaf": .int])
        }
    }

    @Test("a name a table does not declare stands for no type, so no value is one")
    func aNameTheTableDoesNotDeclareIsNoType() throws {
        // Given
        let types = try TypeTable(types: ["App.Whole": .int])

        // When / Then
        #expect(!TypeExpression.named("Bank.Vault").accepts(.int, in: types))
        #expect(TypeExpression.int.accepts(.named("Bank.Vault"), in: types))
        #expect(!TypeExpression.named("Bank.Vault").declaresNull(in: types))
        #expect {
            try TypeExpression.named("Bank.Vault").settling(.int(1), at: "input 'x'", in: types)
        } throws: { error in
            "\(error)".contains("input 'x': declares Never, and nothing is ever that")
        }
    }

    // MARK: - Public
    // MARK: - Private
}
