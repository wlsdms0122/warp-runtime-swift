//
//  VariableTests.swift
//  WarpTests
//
//  Created by JSilver on 8/17/26.
//

import Foundation
import Testing
@testable import Warp
import WarpTestSupport

@Suite("A variable as it runs")
struct VariableTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("a variable reads back what was last written to it")
    func variableReadsBackLastWrite() async throws {
        // Given
        let sut: Body = [
            Statement(binding: .variable("tally"), expression: .literal(.int(1))),
            Statement(binding: .assignment([.name("tally")]), expression: .literal(.int(2))),
            Statement(binding: .assignment([.name("tally")]), expression: .literal(.int(3)))
        ]

        // When
        let answer = try await answer(of: sut, returning: reference("tally"))

        // Then
        #expect(answer == .int(3))
    }

    @Test("an assignment sees the value it is replacing")
    func assignmentReadsItsOwnPriorValue() async throws {
        // Given. The expression is evaluated before the write lands, which is
        // what makes an accumulator work at all
        let sut: Body = [
            Statement(binding: .variable("text"), expression: .literal(.string("a"))),
            Statement(binding: .assignment([.name("text")]), expression: interpolated(literal("<"), spelling(reference("text")), literal(">")))
        ]

        // When
        let answer = try await answer(of: sut, returning: reference("text"))

        // Then
        #expect(answer == .string("<a>"))
    }

    @Test("a closure owns the variables it declares")
    func closureOwnsItsVariables() async throws {
        // Given. What is refused is reaching outward, not variables
        let sut: Body = [
            Statement(binding: .constant("both"), expression: .call(
                    Call(
                        selector: "Standard.Concurrent.allKeyed",
                        arguments: [
                            map([
                                "left": .closure(
                                    Procedure(
                                        signature: Signature(returns: .int, isolation: .isolated),
                                        body: [
                                            Statement(binding: .variable("tally"), expression: .literal(.int(0))),
                                            Statement(binding: .assignment([.name("tally")]), expression: .literal(.int(1))),
                                            returning(reference("tally"))
                                        ]
                                    )
                                ),
                                "right": .closure(Procedure(signature: Signature(returns: .int, isolation: .isolated), body: [returning(.literal(.int(2)))]))
                            ])
                        ]
                    )
                )
            )
        ]

        // When. The pieces' answers are read as the map they are
        let answer = try await answer(of: sut, returning: .reference([.name("both"), .index("left")]))

        // Then
        #expect(answer == .int(1))
    }

    @Test("what crosses loop rounds is the variable and nothing else")
    func loopCarriesOnlyVariables() async throws {
        // Given. The round writes a variable declared outside it and binds a
        // constant that must not survive the round
        let sut: Body = [
            Statement(binding: .variable("latest"), expression: .literal(.int(0))),
            Statement(binding: .constant("gate"), expression: .loop(
                    while: differs(reference("gate", "index"), .literal(.int(3))),
                    body: [
                        Statement(binding: .constant("transient"), expression: reference("gate", "index")),
                        Statement(binding: .assignment([.name("latest")]), expression: reference("transient"))
                    ]
                )
            )
        ]

        // When
        let answer = try await answer(of: sut, returning: reference("latest"))

        // Then. Rounds 0/1/2 ran, and only `latest` came out
        #expect(answer == .int(2))
        #expect(!validates(body: Body(sut.statements + [Statement(binding: .constant("read"), expression: reference("transient"))])))
    }

    // MARK: - Public
    // MARK: - Private
}
