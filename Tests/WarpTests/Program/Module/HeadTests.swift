//
//  HeadTests.swift
//  WarpTests
//
//  Created by JSilver on 10/22/26.
//

import Foundation
import Testing
@testable import Warp

@Suite("What a claim under a head is about")
struct HeadTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("a head's type parameter renamed renames the base an associated type stands on")
    func renamingReachesTheBaseOfAnAssociatedType() throws {
        // Given
        let sut = Head("App.Box", arguments: [
            .parameter(name: "T"),
            .associatedType(AssociatedType(base: "T", members: ["Item", "Key"]))
        ])

        // When
        let claimed = try #require(sut.claimed)

        // Then
        #expect(claimed.type == .named("App.Box", arguments: [
            .parameter(name: "Self.T"),
            .associatedType(AssociatedType(base: "Self.T", members: ["Item", "Key"]))
        ]))
    }

    @Test("a head applying the Optional is spelled by its `?`, a bounded parameter in parentheses")
    func optionalHeadIsSpelledByItsQuestionMark() {
        // Given
        let sut = Head(TypeSpelling.optional, arguments: [.parameter(name: "W")], bounds: ["W": ["Hashable"]])

        // When
        let spelling = sut.spelling

        // Then
        #expect(spelling == "(some W: Hashable)?")
        #expect(Head(TypeSpelling.optional, arguments: [.parameter(name: "W")]).spelling == "some W?")
    }

    @Test("a claim under an Optional's head is about the Optional of what the head applies it to")
    func optionalHeadClaimsTheOptional() throws {
        // Given
        let sut = Head(TypeSpelling.optional, arguments: [.parameter(name: "W")])

        // When
        let claimed = try #require(sut.claimed)

        // Then
        #expect(claimed.type == .optional(.parameter(name: "Self.W")))
        #expect(sut.mentions.isEmpty)
    }

    // MARK: - Public
    // MARK: - Private
}
