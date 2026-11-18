//
//  AddingTests.swift
//  WarpTests
//
//  Created by JSilver on 11/15/26.
//

import Foundation
import Testing
@testable import Warp

@Suite("A collection one element is added to")
struct AddingTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("an array handed over is written into in place")
    func writesIntoAnArrayHandedOver() throws {
        // Given
        var elements: [Value] = [.int(1)]
        elements.reserveCapacity(4)
        let storage = Self.storage(of: elements)
        let sut = Value.array(consume elements)

        // When
        let added = (consume sut).adding(.int(300), atFront: false)

        // Then
        guard case let .array(result) = added else {
            Issue.record("expected an array, got \(String(describing: added))")
            return
        }

        #expect(result == [.int(1), .int(300)])
        #expect(Self.storage(of: result) == storage)
    }

    @Test("bytes handed over a byte are written into in place")
    func writesIntoBytesHandedOver() throws {
        // Given
        var bytes: [UInt8] = [1]
        bytes.reserveCapacity(4)
        let storage = Self.storage(of: bytes)
        let sut = Value.bytes(consume bytes)

        // When
        let added = (consume sut).adding(.int(2), atFront: false)

        // Then
        guard case let .bytes(result) = added else {
            Issue.record("expected bytes, got \(String(describing: added))")
            return
        }

        #expect(result == [1, 2])
        #expect(Self.storage(of: result) == storage)
    }

    @Test("bytes added what is not a byte are an array")
    func bytesAddedANonByteAreAnArray() {
        // Given
        let sut = Value.bytes([1, 2])

        // When / Then
        #expect(sut.adding(.int(300), atFront: true) == .array([.int(300), .int(1), .int(2)]))
        #expect(sut.adding(.string("a"), atFront: false) == .array([.int(1), .int(2), .string("a")]))
    }

    // MARK: - Public
    // MARK: - Private
    private static func storage<Element>(of elements: [Element]) -> UnsafeRawPointer? {
        elements.withUnsafeBufferPointer { buffer in buffer.baseAddress.map(UnsafeRawPointer.init) }
    }
}
