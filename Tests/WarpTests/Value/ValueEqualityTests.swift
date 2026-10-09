//
//  ValueEqualityTests.swift
//  WarpTests
//
//  Created by JSilver on 10/1/26.
//

import Foundation
import Testing
@testable import Warp
import WarpTestSupport

@Suite("Two values are equal by what they hold")
struct ValueEqualityTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("an array holding a procedure is equal to nothing, itself included, the way the procedure is")
    func anArrayHoldingAProcedureIsNotEqualToItself() async throws {
        // Given
        let procedure = try await procedureValue()
        let sut = Value.array([procedure])

        // When / Then
        #expect(procedure != procedure)
        #expect(sut != sut)
        #expect(sut != .array([procedure]))
    }

    @Test("a fraction that is not a number is equal to nothing, itself included")
    func notANumberIsNotEqualToItself() {
        // Given
        let sut = Value.double(.nan)

        // When / Then
        #expect(sut != sut)
        #expect(Value.array([sut]) != .array([sut]))
    }

    @Test("a procedure is never equal to a procedure")
    func proceduresHaveNoEquality() async throws {
        // Given / When. There is no honest answer, so the language does not
        // offer one
        let sut = try await procedureValue()

        // Then
        #expect(sut != sut)
        #expect(sut.nominal == TypeSpelling.procedure)
    }

    // MARK: - Public
    // MARK: - Private
}
