//
//  VariableTests.swift
//  WarpTests
//
//  Created by JSilver on 8/17/26.
//

import Foundation
import Testing
@testable import Warp

// Variables, asked of the language rather than of a notation. Nothing here
// spells `var:` or `set:`. Those are how one front end writes a binding, and
// what is being tested is what a binding *is*.
@Suite
struct VariableTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("a write inside a block outlives the block")
    func assignmentOutlivesItsBlock() async throws {
        // Given. The one thing a constant binding cannot do
        let sut: [Statement] = [
            Statement(binding: .variable("verdict"), expression: .literal(.string("untouched"))),
            Statement(
                expression: .conditional(
                    .literal(.bool(true)),
                    then: [
                        Statement(binding: .assignment([.key("verdict")]), expression: .literal(.string("touched"))
                        )
                    ],
                    else: nil
                    )
            )
        ]

        // When
        let answer = try await answer(of: sut, result: reference("verdict"))

        // Then
        #expect(answer == .string("touched"))
    }

    @Test("a block that did not run writes nothing")
    func untakenBlockWritesNothing() async throws {
        // Given
        let sut: [Statement] = [
            Statement(binding: .variable("verdict"), expression: .literal(.string("untouched"))),
            Statement(
                expression: .conditional(
                    .literal(.bool(false)),
                    then: [
                        Statement(binding: .assignment([.key("verdict")]), expression: .literal(.string("touched"))
                        )
                    ],
                    else: nil
                    )
            )
        ]

        // When
        let answer = try await answer(of: sut, result: reference("verdict"))

        // Then
        #expect(answer == .string("untouched"))
    }

    @Test("a variable declared inside a block does not escape it")
    func declarationDoesNotEscape() {
        // Given. The box is shared; which names exist is not
        let sut: [Statement] = [
            Statement(
                expression: .conditional(
                    .literal(.bool(true)),
                    then: [
                        Statement(binding: .variable("inner"), expression: .literal(.int(1)))
                    ],
                    else: nil
                    )
            ),
            Statement(binding: .constant("read"), expression: reference("inner"))
        ]

        // When / Then
        #expect(!validates(body: sut))
    }

    @Test("a declaration inside a block shadows an outer variable instead of writing it")
    func declarationShadowsOuterVariable() async throws {
        // Given. A declaration always introduces, so the inner name has a box
        // of its own
        let sut: [Statement] = [
            Statement(binding: .variable("verdict"), expression: .literal(.string("outer"))),
            Statement(
                expression: .conditional(
                    .literal(.bool(true)),
                    then: [
                        Statement(binding: .variable("verdict"), expression: .literal(.string("inner"))
                        )
                    ],
                    else: nil
                    )
            )
        ]

        // When
        let answer = try await answer(of: sut, result: reference("verdict"))

        // Then
        #expect(answer == .string("outer"))
    }

    @Test("a variable reads back what was last written to it")
    func variableReadsBackLastWrite() async throws {
        // Given
        let sut: [Statement] = [
            Statement(binding: .variable("tally"), expression: .literal(.int(1))),
            Statement(binding: .assignment([.key("tally")]), expression: .literal(.int(2))),
            Statement(binding: .assignment([.key("tally")]), expression: .literal(.int(3)))
        ]

        // When
        let answer = try await answer(of: sut, result: reference("tally"))

        // Then
        #expect(answer == .int(3))
    }

    @Test("an assignment sees the value it is replacing")
    func assignmentReadsItsOwnPriorValue() async throws {
        // Given. The expression is settled before the write lands, which is
        // what makes an accumulator work at all
        let sut: [Statement] = [
            Statement(binding: .variable("text"), expression: .literal(.string("a"))),
            Statement(binding: .assignment([.key("text")]), expression: interpolated(literal("<"), spelling(reference("text")), literal(">"))
            )
        ]

        // When
        let answer = try await answer(of: sut, result: reference("text"))

        // Then
        #expect(answer == .string("<a>"))
    }

    @Test("writing a fixed name is refused")
    func writingConstantRefused() {
        // Given
        let sut: [Statement] = [
            Statement(binding: .constant("verdict"), expression: .literal(.string("first"))),
            Statement(binding: .assignment([.key("verdict")]), expression: .literal(.string("second")))
        ]

        // When / Then
        #expect(!validates(body: sut))
    }

    @Test("writing a name nothing declared is refused")
    func writingUndeclaredRefused() {
        // Given
        let sut = [
            Statement(binding: .assignment([.key("verdict")]), expression: .literal(.string("x")))
        ]

        // When / Then
        #expect(!validates(body: sut))
    }

    @Test("a name reintroduced as a constant stops being writable")
    func constantReintroductionRevokesWriting() {
        // Given. Shadowing runs both ways: an inner constant of the same name
        // is a different, fixed name, and the outer box is not reachable
        // through it
        let sut: [Statement] = [
            Statement(binding: .variable("verdict"), expression: .literal(.int(1))),
            Statement(binding: .constant("gate"), expression: .block(
                    Block(body: [
                        Statement(binding: .constant("verdict"), expression: .literal(.int(2))),
                        Statement(binding: .assignment([.key("verdict")]), expression: .literal(.int(3))
                        )
                    ])
                )
            )
        ]

        // When / Then
        #expect(!validates(body: sut))
    }

    @Test("a closure may write a variable it captured")
    func closureWritesWhatItCaptured() {
        // Given. A variable's box is one thing under one name everywhere the
        // name is visible, and the closure's body is one of those places
        let sut: [Statement] = [
            Statement(binding: .variable("tally"), expression: .literal(.int(0))),
            Statement(binding: .constant("later"), expression: .closure(
                    Procedure(
                        body: [
                            Statement(binding: .assignment([.key("tally")]), expression: .literal(.int(1))
                            )
                        ],
                        result: reference("tally")
                    )
                )
            )
        ]

        // When / Then
        #expect(validates(body: sut))
    }

    @Test("a closure owns the variables it declares")
    func closureOwnsItsVariables() async throws {
        // Given. What is refused is reaching outward, not variables
        let sut = [
            Statement(binding: .constant("both"), expression: .dispatch(
                    Dispatch(
                        receiver: .record([
                            "left": .closure(
                                Procedure(
                                    body: [
                                        Statement(binding: .variable("tally"), expression: .literal(.int(0))
                                        ),
                                        Statement(binding: .assignment([.key("tally")]), expression: .literal(.int(1))
                                        )
                                    ],
                                    result: reference("tally")
                                )
                            ),
                            "right": .closure(Procedure(body: [], result: .literal(.int(2))))
                        ]),
                        selector: "std.concurrent.all"
                    )
                )
            )
        ]

        // When. `all` answers `any` by its declaration, so the shape the author
        // expects is named before a dot reads it
        let answer = try await answer(
            of: sut + [
                Statement(binding: .constant("read"), expression: .cast(
                        reference("both"),
                        as: .record(["left": .int]),
                        optional: false
                    )
                )
            ],
            result: reference("read", "left")
        )

        // Then
        #expect(answer == .int(1))
    }

    @Test("what crosses loop rounds is the variable and nothing else")
    func loopCarriesOnlyVariables() async throws {
        // Given. The round writes a variable declared outside it and binds a
        // constant that must not survive the round
        let sut: [Statement] = [
            Statement(binding: .variable("latest"), expression: .literal(.int(0))),
            Statement(binding: .constant("gate"), expression: .loop(
                    while: differs(reference("round", "index"), .literal(.int(3))),
                    body: Block(body: [
                        Statement(binding: .constant("transient"), expression: reference("round", "index")),
                        Statement(binding: .assignment([.key("latest")]), expression: reference("transient"))
                    ]),
                    round: "round"
                )
            )
        ]

        // When
        let answer = try await answer(of: sut, result: reference("latest"))

        // Then. Rounds 0/1/2 ran, and only `latest` came out
        #expect(answer == .int(2))
        #expect(!validates(body: sut + [Statement(binding: .constant("read"), expression: reference("transient"))]))
    }
}
