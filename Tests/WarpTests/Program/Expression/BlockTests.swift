//
//  BlockTests.swift
//  WarpTests
//
//  Created by JSilver on 10/1/26.
//

import Foundation
import Testing
@testable import Warp

@Suite("A block")
struct BlockTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("a block's leave judgement is true of the block alone")
    func alwaysLeavesIsTrueOfTheBlockAlone() {
        // Given. A block no validator has seen: the property answers from the
        // block itself, so a leaving body counts whatever the result declares,
        // and wherever in the body the leave sits
        let leave = Expression.leave(.procedure(.literal(.int(1))))

        // When / Then
        #expect(Block(body: [Statement(expression: leave)], result: .literal(.int(2))).alwaysLeaves)
        #expect(Block(
            body: [Statement(expression: leave), Statement(binding: .constant("after"), expression: .literal(.int(3)))]
        ).alwaysLeaves)
        #expect(!Block(body: [], result: .literal(.int(1))).alwaysLeaves)
    }

    @Test("a block whose result is null holds no result, the way a document reads one")
    func aNullResultIsNoResult() {
        // Given / When
        let sut = Block(body: [], result: .literal(.null))

        // Then
        #expect(sut.result == nil)
    }

    // MARK: - Public
    // MARK: - Private
}
