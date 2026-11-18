//
//  ValueRepresentableTests.swift
//  WarpTests
//

import Foundation
import Testing
@testable import Warp

@Suite("Swift types standing for the language's")
struct ValueRepresentableTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Lifecycle
    // MARK: - Test
    @Test("each one is written as the type its value reads as")
    func types() {
        // Given
        // When
        // Then
        #expect(String.type == .string)
        #expect([Int].type == .array(.int))
        #expect([String: Double].type == .dictionary(key: .string, value: .double))
        #expect(Bool??.type == .optional(.optional(.bool)))
    }

    @Test("a value written out reads back as what it was")
    func roundTrip() throws {
        // Given
        let sut: [String: [Int?]] = ["one": [1, nil], "two": []]

        // When
        let read = try [String: [Int?]](try sut.value)

        // Then
        #expect(read == sut)
    }

    @Test("an Optional of an Optional keeps the none it holds apart from its own")
    func nestedOptional() throws {
        // Given
        let sut: Int?? = .some(.none)

        // When
        let written = try sut.value
        let read = try Int??(written)

        // Then
        #expect(written != .null)
        #expect(read == .some(.none))
        #expect(try Int??(.null) == .none)
    }

    @Test("a list reads in either spelling")
    func bytes() throws {
        // Given
        let sut = Value.bytes([1, 2, 255])

        // When
        let read = try [Int](sut)

        // Then
        #expect(read == [1, 2, 255])
    }

    @Test("a value of another type is refused")
    func refusesAnotherType() {
        // Given
        let sut = Value.int(1)

        // When
        // Then
        #expect(throws: ValueRefused.self) { try String(sut) }
    }

    // MARK: - Private
}
