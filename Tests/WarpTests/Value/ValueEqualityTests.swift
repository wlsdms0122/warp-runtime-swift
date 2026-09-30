//
//  ValueEqualityTests.swift
//  WarpTests
//
//  Created by JSilver on 10/1/26.
//

import Testing
@testable import Warp

@Suite("Two values are equal by what they hold")
struct ValueEqualityTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("an array holding a procedure is equal to nothing, itself included, the way the procedure is")
    func anArrayHoldingAProcedureIsNotEqualToItself() {
        // Given
        let procedure = Value.procedure(.assembled())
        let sut = Value.array([procedure])

        // When / Then
        #expect(procedure != procedure)
        #expect(sut != sut)
        #expect(sut != .array([procedure]))
    }

    @Test("a procedure is never equal to a procedure")
    func proceduresHaveNoEquality() throws {
        // Given. There is no honest answer, so the language does not offer one
        let sut = Value.procedure(
            Closure.assembled()
        )

        // Then
        #expect(sut != sut)
        #expect(sut.type == .procedure)
    }

    // MARK: - Public
    // MARK: - Private
}
