//
//  BoundaryTests.swift
//  WarpTests
//
//  Created by JSilver on 8/20/26.
//

import Foundation
import Testing
@testable import Warp
import WarpStandard

@Suite("The standard vocabulary at its edges")
struct BoundaryTests {
    // MARK: - Property
    private let builder = Builder()

    // MARK: - Initializer
    // MARK: - Test
    @Test("a type parameter read as anything is anything")
    func anyIsTheLoosestReading() async throws {
        // Given. A list of anything, added to twice with two kinds of value.
        // `accepts` cannot order `any` against a type, since everything takes
        // `any` and `any` takes everything, so asking which is looser answers
        // yes both ways and whichever was read first would win. Reading it
        // first is what a first argument does, and that made a list of
        // anything into a list of whatever went in first.
        let module = try Module(
            procedures: [
                "entry": Procedure(
                    access: .public,
                    signature: Signature(parameters: [Parameter(name: "xs", type: .array(.any))]),
                    body: [
                        Statement(binding: .constant("one"), expression: .call(
                                Call(
                                    selector: "std.collection.appending",
                                    arguments: [.reference([.key("xs")]), .literal(.int(1))]
                                )
                            )
                        )
                    ],
                    result: .call(
                        Call(
                            selector: "std.collection.appending",
                            arguments: [.reference([.key("one")]), .literal(.string("a"))]
                        )
                    )
                )
            ]
        )

        // When / Then
        await #expect(throws: Never.self) {
            try await builder.build([module] + Module.standard)
        }
    }

    @Test("a name a module declared and the type it stands for are one reading")
    func aDeclaredNameIsNotADisagreement() async throws {
        // Given. The parameter is read as `Tree` by the list and as the record
        // the call wrote. They are the same type, and calling them a
        // disagreement was asking the question without the table that answers
        // it. The same table the rest of the link uses.
        let module = try Module(
            types: ["Tree": .record(["a": .int])],
            procedures: [
                "entry": Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [Parameter(name: "trees", type: .array(.named("Tree")))]
                    ),
                    body: [],
                    result: .call(
                        Call(
                            selector: "std.collection.appending",
                            arguments: [.reference([.key("trees")]), .record(["a": .literal(.int(1))])]
                        )
                    )
                )
            ]
        )

        // When / Then
        await #expect(throws: Never.self) {
            try await builder.build([module] + Module.standard)
        }
    }

    @Test("a type parameter read loosely and tightly holds the loose reading")
    func aWiderReadingHolds() async throws {
        // Given. A list of numbers and a whole number are not a disagreement.
        // One reading takes the other, so the one that holds both is the
        // answer, and refusing here would refuse a program with nothing wrong
        // with it.
        let module = try Module(
            procedures: [
                "entry": Procedure(
                    access: .public,
                    signature: Signature(parameters: [Parameter(name: "counts", type: .array(.named("std.Numeric")))]),
                    body: [],
                    result: .call(
                        Call(
                            selector: "std.collection.appending",
                            arguments: [.reference([.key("counts")]), .literal(.int(1))]
                        )
                    )
                )
            ]
        )

        // When / Then
        await #expect(throws: Never.self) {
            try await builder.build([module] + Module.standard)
        }
    }

    // MARK: - Public
    // MARK: - Private
}
