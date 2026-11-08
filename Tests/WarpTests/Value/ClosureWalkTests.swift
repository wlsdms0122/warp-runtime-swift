//
//  ClosureWalkTests.swift
//  WarpTests
//
//  Created by JSilver on 9/17/26.
//

import Foundation
import Testing
@testable import Warp
import WarpTestSupport

@Suite("A value names the closures it holds")
struct ClosureWalkTests {
    // MARK: - Property
    // A closure needs a row to stand on; any row does, since only the walk
    // over the value is asked.
    private var row: Linked {
        get async throws {
            try await Builder().build(
                [try Module(procedures: [entryName: Procedure(access: .public, body: [])])] + Module.standard
            )[entryName]!
        }
    }

    // MARK: - Initializer
    // MARK: - Test
    @Test("every closure is named, what a closure captured by copy included")
    func everyClosureIsNamed() async throws {
        // Given. A closure capturing one by copy and one through a hold,
        // inside an array
        let row = try await row
        let copied = Closure(writer: Closure.Writer(document: .compiled(Compiled.Token()), declaration: .procedure("w")), nth: 9, resolution: .resolved(row, types: [:]), captured: [])
        let held = Closure(writer: Closure.Writer(document: .compiled(Compiled.Token()), declaration: .procedure("w")), nth: 11, resolution: .resolved(row, types: [:]), captured: [])
        let capturing = Closure(
            writer: Closure.Writer(document: .compiled(Compiled.Token()), declaration: .procedure("w")),
            nth: 7,
            resolution: .resolved(row, types: [:]),
            captured: [
                (slot: 0, cell: .value(.procedure(copied))),
                (slot: 1, cell: .hold(Handle("box", .procedure(held))))
            ]
        )
        let sut: Value = .array([.int(1), .procedure(capturing)])

        // When
        var rows: [Int] = []
        sut.closures { closure in rows.append(closure.nth) }

        // Then. The hold is the run's box, and what it holds is not the value's
        #expect(Set(rows) == [7, 9])
        #expect(capturing.tookAHold && !copied.tookAHold)
    }

    @Test("holding one is decided at the first, and is false for a value without any")
    func holdingIsDecidedAtTheFirst() async throws {
        // Given
        let row = try await row
        let inner = Closure(writer: Closure.Writer(document: .compiled(Compiled.Token()), declaration: .procedure("w")), nth: 9, resolution: .resolved(row, types: [:]), captured: [])
        let sut: Value = .struct(
            Struct(name: "App.R", ["a": .int(1), "b": .array([.procedure(inner)])])
        )

        // When
        var visited = 0
        let holds = sut.holdsClosure { _ in
            visited += 1

            return true
        }

        // Then
        #expect(holds && visited == 1)
        #expect(sut.holdsProcedure)
        #expect(!sut.holdsClosure(where: \.tookAHold))
        #expect(!Value.array([.int(1), .string("x")]).holdsProcedure)
    }

    // MARK: - Public
    // MARK: - Private
}
