//
//  ActivationTests.swift
//  WarpTests
//
//  Created by JSilver on 10/23/26.
//

import Foundation
import Testing
@testable import Warp
import WarpTestSupport

@Suite("The types a running body holds")
struct ActivationTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("reads a type parameter of the body as what fills it, wherever in a type it stands")
    func readsAParameterAsWhatFillsIt() {
        // Given
        let sut = Activation(Self.frame, of: 0, types: ["T": .int, "U": .string], in: .empty)

        // When
        let read = sut.reading(
            .dictionary(key: .parameter(label: "U", bounds: []), value: .array(.parameter(label: "T", bounds: ["App.P"])))
        )

        // Then
        #expect(read == .dictionary(key: .string, value: .array(.int)))
    }

    @Test("leaves a type parameter nothing filled standing")
    func leavesAnUnfilledParameterStanding() {
        // Given
        let sut = Activation(Self.frame, of: 0, types: ["T": .int], in: .empty)

        // When
        let read = sut.reading(.array(.parameter(label: "V", bounds: [])))

        // Then
        #expect(read == .array(.parameter(label: "V", bounds: [])))
    }

    // MARK: - Public
    // MARK: - Private
    private static let frame = Frame(size: 0, parameters: [], variables: [], captures: [], names: [])
}
