//
//  StandardTests.swift
//  WarpStandardTests
//
//  Created by JSilver on 8/17/26.
//

import Foundation
import Testing
import Warp
import WarpStandard

// The procedures that ship in bundles, and the fact that they are bundles: a caller
// takes the ones its programs have use for, and a name from a bundle it left out
// does not resolve.
@Suite("The standard vocabulary")
struct StandardTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("every bundle written in Swift checks at the door a module from outside takes")
    func everyBundleChecks() throws {
        // Given. The bundles stand without the check
        let bundles = Module.standard.filter(\.builtin)

        // Then
        #expect(bundles.count == 7)

        for bundle in bundles {
            _ = try Module(bundle.draft, builtin: true)
        }
    }

    @Test("every procedure that ships is builtin or written in Warp")
    func everyProcedureIsPlaced() throws {
        // Given. What the bundles declare, and how the one list cuts them
        let shipped = Set(Module.standard.flatMap(\.procedures.keys))

        // Then. A name in `builtin` that nothing declares is a list gone stale
        #expect(Module.builtin.subtracting(shipped).isEmpty)
        #expect(Module.builtin.count == 25)
        #expect(Module.builtin.union(Module.derived) == shipped)
    }

    @Test("a procedure this package calls derived has a body here")
    func everyDerivedProcedureIsWritten() throws {
        // Given. `derived` is what is left over, so it says a procedure is
        // written in Warp without looking. This is the looking: a name it
        // claims and a native implementation is a claim the package does not
        // keep
        let written = Set(
            Module.standard
                .flatMap(\.procedures)
                .compactMap { name, procedure -> Name? in
                    guard case .body = procedure.implementation else { return nil }

                    return name
                }
        )

        // Then
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
                            selector: "std.collection.count",
                            arguments: [.literal(.array([.int(1)]))]
                        ))
                        )
                    ]
                )
            ]
        )

        // When / Then
        await #expect(throws: BuildError.self) {
            try await Builder().build([sut] + Module.math + Module.text + Module.foundation)
        }

        await #expect(throws: Never.self) {
            try await Builder().build([sut] + Module.collection + Module.logic + Module.math + Module.foundation)
        }
    }

    @Test("what a procedure answers is declared, so the build reads it")
    func standardAnswersAreDeclared() async throws {
        // Given. `count` declares that it answers an int, and `split` declares
        // that it is sent a string
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(parameters: [Parameter(name: "items", type: .array(.string))]),
                    body: [
                        Statement(binding: .constant("many"), expression: .call(Call(
                            selector: "std.collection.count",
                            arguments: [reference("items")]
                        ))
                        ),
                        Statement(binding: .constant("said"), expression: .call(Call(
                            selector: "std.text.split",
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

    // MARK: - Public
    // MARK: - Private
}
