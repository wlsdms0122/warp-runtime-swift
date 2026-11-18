//
//  BodyTests.swift
//  WarpTests
//
//  Created by JSilver on 10/21/26.
//

import Foundation
import Testing
@testable import Warp

@Suite("A body")
struct BodyTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("a body's leave judgement is true of the body alone")
    func alwaysLeavesIsTrueOfTheBodyAlone() {
        // Given. A body no validator has seen: the property is read off the
        // body itself, wherever in it the leave sits
        let leave = Statement(expression: .leave(.procedure(.literal(.int(1)))))
        let after = Statement(binding: .constant("after"), expression: .literal(.int(3)))

        // When
        let ending: Body = [leave]
        let followed: Body = [leave, after]
        let empty: Body = []

        // Then
        #expect(ending.alwaysLeaves)
        #expect(followed.alwaysLeaves)
        #expect(!empty.alwaysLeaves)
    }

    // MARK: - Public
    // MARK: - Private
}
