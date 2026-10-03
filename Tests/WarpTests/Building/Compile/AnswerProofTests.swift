//
//  AnswerProofTests.swift
//  WarpTests
//
//  Created by JSilver on 10/3/26.
//

import Foundation
import Testing
@testable import Warp
import WarpStandard
import WarpTestSupport

// Whether a body answers as its declaration says is settled over the whole
// document, the way its constness is: a body proves it alone or leans on
// the declarations it calls, and which it leans on is read once every body
// is read, whatever order they were read in.
@Suite("What a body proves of its answers")
struct AnswerProofTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("a body answering what a declaration read after it answers is proven with it")
    func aBodyLeaningOnALaterOneIsProven() async throws {
        // Given. `app.a` is read before `app.z`, and answers what it answers
        let sut = try Module(
            procedures: [
                "app.a": generic(result: .call(Call(selector: "app.z", arguments: [.reference([.key("x")])]))),
                "app.z": generic(result: .reference([.key("x")]))
            ]
        )

        // When
        let image = try await Builder().build([sut] + Module.standard)

        // Then
        #expect(image["app.a"]?.answersAsDeclared == true)
        #expect(image["app.z"]?.answersAsDeclared == true)
    }

    @Test("a body answering what one answering `any` answers is not proven")
    func aBodyLeaningOnAnUnprovenOneIsNot() async throws {
        // Given. `app.z` answers a value of `any` for its own `some T`
        let sut = try Module(
            procedures: [
                "app.a": generic(result: .call(Call(selector: "app.z", arguments: [.reference([.key("x")]), .reference([.key("x")])]))),
                "app.z": Procedure(
                    signature: Signature(
                        parameters: [
                            Parameter(name: "x", type: .parameter(name: "T")),
                            Parameter(name: "junk", type: .any)
                        ],
                        returns: .parameter(name: "T")
                    ),
                    body: [],
                    result: .reference([.key("junk")])
                )
            ]
        )

        // When
        let image = try await Builder().build([sut] + Module.standard)

        // Then
        #expect(image["app.z"]?.answersAsDeclared == false)
        #expect(image["app.a"]?.answersAsDeclared == false)
    }

    @Test("a body leaning on itself keeps what nothing else took away")
    func aRecursiveBodyIsProven() async throws {
        // Given
        let sut = try Module(
            procedures: [
                "app.r": generic(result: .call(Call(selector: "app.r", arguments: [.reference([.key("x")])])))
            ]
        )

        // When
        let image = try await Builder().build([sut] + Module.standard)

        // Then
        #expect(image["app.r"]?.answersAsDeclared == true)
    }

    @Test("two bodies leaning on each other keep what nothing else took away")
    func twoBodiesLeaningOnEachOtherAreProven() async throws {
        // Given
        let sut = try Module(
            procedures: [
                "app.a": generic(result: .call(Call(selector: "app.b", arguments: [.reference([.key("x")])]))),
                "app.b": generic(result: .call(Call(selector: "app.a", arguments: [.reference([.key("x")])])))
            ]
        )

        // When
        let image = try await Builder().build([sut] + Module.standard)

        // Then
        #expect(image["app.a"]?.answersAsDeclared == true)
        #expect(image["app.b"]?.answersAsDeclared == true)
    }

    // MARK: - Public
    // MARK: - Private
    // A declaration taking and answering its own `some T`.
    private func generic(result: Warp.Expression) -> Procedure {
        Procedure(
            signature: Signature(
                parameters: [Parameter(name: "x", type: .parameter(name: "T"))],
                returns: .parameter(name: "T")
            ),
            body: [],
            result: result
        )
    }
}
