//
//  StandardTests.swift
//  WarpStandardTests
//
//  Created by JSilver on 8/17/26.
//

import Foundation
import Testing
import Warp
@testable import WarpStandard
import WarpTestSupport

// The procedures that ship in bundles, and the fact that they are bundles: a host
// takes the ones its programs have use for, and a name from a bundle it left out
// does not resolve.
@Suite("The standard vocabulary")
struct StandardTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("every bundle written in Swift loads as a module from outside does")
    func everyBundleChecks() throws {
        // Given. The bundles stand without the load's judgement
        let bundles = Module.standard.filter(\.builtin)

        // When / Then
        #expect(bundles.count == 7)

        for bundle in bundles {
            _ = try Module(bundle.draft, builtin: true)
        }
    }

    @Test("a procedure this package calls derived has a body here")
    func everyDerivedProcedureIsWritten() throws {
        // Given. `derived` is what the modules that are not builtin declare,
        // read off the module and not off its procedures. This reads the
        // procedures: a name it holds with a native implementation is a claim
        // the package does not keep
        let written = Set(
            Module.standard
                .flatMap(\.procedures)
                .compactMap { name, procedure -> Name? in
                    guard case .body = procedure.implementation else { return nil }

                    return name
                }
        )

        // When / Then
        #expect(Module.derived.subtracting(written).isEmpty)
    }

    @Test("a bundle left out is a bundle whose names do not resolve")
    func aBundleLeftOutDoesNotResolve() async throws {
        // Given. A program that only counts, linked without the bundle that
        // declares counting
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    body: [
                        Statement(binding: .constant("many"), expression: .call(Call(
                            selector: "Standard.Collection.count",
                            arguments: [.literal(.array([.int(1)]))]
                        ))
                        )
                    ]
                )
            ]
        )

        // When / Then
        await #expect(throws: BuildError.self) {
            try await Builder().build([sut] + Module.math + Module.text + Module.sharedGround)
        }

        await #expect(throws: Never.self) {
            try await Builder().build([sut] + Module.collection + Module.logic + Module.math + Module.sharedGround)
        }
    }

    @Test("a bundle written in Warp alone links with nothing beside it")
    func aWrittenBundleStandsAlone() async throws {
        // Given. `unwrapped` is written from `unwrap`, which the language
        // holds, so the Optional bundle sends to no other bundle and has no
        // builtin half
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(returns: .int),
                    body: [
                        returning(.call(Call(
                            selector: "Standard.Optional.unwrapped",
                            arguments: [
                                .literal(.null),
                                .closure(Procedure(
                                    signature: Signature(returns: .int, constness: .const, isolation: .isolated),
                                    body: [returning(.literal(.int(7)))]
                                ))
                            ]
                        )))
                    ]
                )
            ]
        )

        // When
        let returned = try await run(sut, vocabulary: Module.optional)

        // Then
        #expect(Module.optional.allSatisfy { module in !module.builtin })
        #expect(returned == .int(7))
    }

    @Test("what a procedure returns is declared, so the build reads it")
    func standardReturnTypesAreDeclared() async throws {
        // Given. `count` declares that it returns an int, and `split` declares
        // that it is sent a string
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(parameters: [Parameter(name: "items", type: .array(.string))]),
                    body: [
                        Statement(binding: .constant("many"), expression: .call(Call(
                            selector: "Standard.Collection.count",
                            arguments: [reference("items")]
                        ))
                        ),
                        Statement(binding: .constant("said"), expression: .call(Call(
                            selector: "Standard.Text.split",
                            arguments: [reference("many"), .literal(.string(","))]
                        ))
                        )
                    ]
                )
            ]
        )

        // When / Then
        await #expect(throws: BuildError.self) {
            try await Builder().build([sut] + Module.standard)
        }
    }

    @Test("a bundle mentioning the shared contracts needs Standard in the link")
    func aBundleNeedsStandardInTheLink() async throws {
        // Given. Collection's procedures mention `Collection` and
        // `Comparable`, which only the shared ground declares
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(returns: .array(.int)),
                    body: [
                        returning(.call(Call(
                            selector: "Standard.Collection.sorted",
                            arguments: [.literal(.array([.int(2), .int(1)]))]
                        )))
                    ]
                )
            ]
        )

        // When / Then, without the shared ground the contract name resolves to
        // nothing, and the declaration that mentions it is refused
        await #expect {
            try await Builder().build([sut] + Module.collection)
        } throws: { error in
            error is BuildError && "\(error)".contains("which no module in this link declares")
        }

        await #expect(throws: Never.self) {
            try await Builder().build([sut] + Module.collection + Module.logic + Module.math + Module.sharedGround)
        }
    }

    // MARK: - Public
    // MARK: - Private
}
