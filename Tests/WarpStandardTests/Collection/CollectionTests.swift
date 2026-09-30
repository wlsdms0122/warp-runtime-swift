//
//  CollectionTests.swift
//  WarpStandardTests
//
//  Created by JSilver on 10/1/26.
//

import Foundation
import Testing
import Warp
import WarpStandard

@Suite("What std.collection answers")
struct CollectionTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("a procedure takes a procedure the author wrote and runs it")
    func aWalkTakesAProcedure() async throws {
        // Given. Map, filter and reduce are declarations rather than
        // constructs. Nothing in the grammar knows they exist
        let doubling = Procedure(
            signature: Signature(parameters: [Parameter(name: "item", type: .int)], returns: .int),
            body: [],
            result: .call(Call(selector: "std.math.times", arguments: [reference("item"), .literal(.int(2))]))
        )
        let odd = Procedure(
            signature: Signature(parameters: [Parameter(name: "item", type: .int)], returns: .bool),
            body: [
                Statement(binding: .constant("left"), expression: .call(Call(
                    selector: "std.math.remainder",
                    arguments: [reference("item"), .literal(.int(2))]
                ))
                )
            ],
            result: equals(reference("left"), .literal(.int(1)))
        )
        let adding = Procedure(
            signature: Signature(
                parameters: [
                    Parameter(name: "carried", type: .int),
                    Parameter(name: "item", type: .int)
                ],
                returns: .int
            ),
            body: [],
            result: .call(Call(selector: "std.math.plus", arguments: [reference("carried"), reference("item")]))
        )

        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(parameters: [Parameter(name: "ns", type: .array(.int))]),
                    body: [
                        Statement(binding: .constant("doubled"), expression: .call(Call(
                            selector: "std.collection.map",
                            arguments: [reference("ns"), .closure(doubling)]
                        ))
                        ),
                        Statement(binding: .constant("kept"), expression: .call(Call(
                            selector: "std.collection.filter",
                            arguments: [reference("ns"), .closure(odd)]
                        ))
                        ),
                        Statement(binding: .constant("total"), expression: .call(Call(
                            selector: "std.collection.reduce",
                            arguments: [reference("ns"), .literal(.int(0)), .closure(adding)]
                        ))
                        )
                    ],
                    result: .record([
                        "doubled": reference("doubled"),
                        "kept": reference("kept"),
                        "total": reference("total")
                    ])
                )
            ]
        )

        // When
        let answer = try await run(
            sut,
            arguments: ["ns": .array([.int(1), .int(2), .int(3)])]
        )

        // Then
        #expect(
            answer == .dictionary([
                "doubled": .array([.int(2), .int(4), .int(6)]),
                "kept": .array([.int(1), .int(3)]),
                "total": .int(6)
            ])
        )
    }

    @Test("a body a walk calls declares every name the walk hands over")
    func aWalkRequiresWhatItHandsOver() async throws {
        // Given. `reduce` hands over `carried` and `item`. Counting reads only
        // the first and declares both: a name is written where it arrives,
        // whether or not the body goes on to read it
        let counting = Procedure(
            signature: Signature(
                parameters: [Parameter(name: "carried", type: .int), Parameter(name: "item", type: .int)],
                returns: .int
            ),
            body: [],
            result: .call(Call(selector: "std.math.plus", arguments: [reference("carried"), .literal(.int(1))]))
        )
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(parameters: [Parameter(name: "ns", type: .array(.int))]),
                    body: [],
                    result: .call(Call(
                        selector: "std.collection.reduce",
                        arguments: [reference("ns"), .literal(.int(0)), .closure(counting)]
                    ))
                )
            ]
        )

        // When
        let answer = try await run(
            sut,
            arguments: ["ns": .array([.int(7), .int(8), .int(9)])]
        )

        // Then
        #expect(answer == .int(3))
    }

    @Test("a walk refuses a procedure that reaches outside")
    func aWalkRefusesAProcedureThatRuns() async throws {
        // Given. `map` declares `const procedure`, so a body that shouts is
        // refused at the build
        let loud = Procedure(
            signature: Signature(parameters: [Parameter(name: "item", type: .string)]),
            body: [],
            result: .call(Call(selector: "app.shout", arguments: [reference("item")]))
        )
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(parameters: [Parameter(name: "names", type: .array(.string))]),
                    body: [],
                    result: .call(Call(selector: "std.collection.map", arguments: [reference("names"), .closure(loud)]))
                )
            ]
        )

        // When / Then
        await #expect(throws: BuildError.self) {
            try await Builder().build([sut, .shouting] + Module.standard)
        }
    }

    @Test("a walk hands a null element over as the element it is")
    func aWalkCarriesNullElements() async throws {
        // Given. `map` offers each element to the procedure it was given, and
        // an element that is null was still an element of the collection
        let sut = Warp.Expression.call(
            Call(
                selector: "std.collection.map",
                arguments: [
                    .literal(.array([.int(1), .null])),
                    .closure(
                        Procedure(
                            signature: Signature(
                                parameters: [Parameter(name: "item", type: .any)]
                            ),
                            body: [],
                            result: reference("item")
                        )
                    )
                ]
            )
        )

        // When
        let answer = try await answer(
            of: [Statement(binding: .constant("probe"), expression: sut)],
            result: reference("probe")
        )

        // Then
        #expect(answer == .array([.int(1), .null]))
    }

    @Test("an array grows and shrinks, which is a length the text did not write")
    func anArrayIsBuiltRatherThanSpelled() async throws {
        // Given. A body walking a grid: the head moves and wraps, the trail
        // takes it on and lets its own end go. Nothing here is a length the
        // author could have counted.
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            Parameter(name: "head", type: .int),
                            Parameter(name: "side", type: .int),
                            Parameter(name: "trail", type: .array(.int))
                        ]
                    ),
                    body: [
                        Statement(binding: .constant("stepped"), expression: .call(Call(
                            selector: "std.math.plus",
                            arguments: [reference("head"), .literal(.int(1))]
                        ))
                        ),
                        Statement(binding: .constant("wrapped"), expression: .call(Call(
                            selector: "std.math.remainder",
                            arguments: [reference("stepped"), reference("side")]
                        ))
                        ),
                        Statement(binding: .constant("grown"), expression: .call(Call(
                            selector: "std.collection.prepending",
                            arguments: [reference("trail"), reference("wrapped")]
                        ))
                        ),
                        Statement(binding: .constant("moved"), expression: .call(Call(
                            selector: "std.collection.dropLast",
                            arguments: [reference("grown")]
                        ))
                        )
                    ],
                    result: .record([
                        "grown": reference("grown"),
                        "moved": reference("moved")
                    ])
                )
            ]
        )

        // When. The head sits at the last column, so stepping wraps it to 0
        let answer = try await run(
            sut,
            arguments: [
                "head": .int(3),
                "side": .int(4),
                "trail": .array([.int(3), .int(2), .int(1)])
            ]
        )

        // Then
        #expect(
            answer == .dictionary([
                "grown": .array([.int(0), .int(3), .int(2), .int(1)]),
                "moved": .array([.int(0), .int(3), .int(2)])
            ])
        )
    }

    @Test("a dictionary is walked and rebuilt without naming its fields")
    func aDictionaryIsDataRatherThanAType() async throws {
        // Given
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(parameters: [Parameter(name: "counts", type: .dictionary(.int))]),
                    body: [
                        Statement(binding: .constant("named"), expression: .call(Call(
                            selector: "std.collection.keys",
                            arguments: [reference("counts")]
                        ))
                        ),
                        Statement(binding: .constant("held"), expression: .call(Call(
                            selector: "std.collection.values",
                            arguments: [reference("counts")]
                        ))
                        ),
                        Statement(binding: .constant("changed"), expression: .call(Call(
                            selector: "std.collection.setting",
                            arguments: [reference("counts"), .literal(.string("b")), .literal(.int(9))]
                        ))
                        )
                    ],
                    result: .record([
                        "changed": reference("changed"),
                        "held": reference("held"),
                        "named": reference("named")
                    ])
                )
            ]
        )

        // When
        let answer = try await run(
            sut,
            arguments: ["counts": .dictionary(["a": .int(1), "b": .int(2)])]
        )

        // Then
        #expect(
            answer == .dictionary([
                "named": .array([.string("a"), .string("b")]),
                "held": .array([.int(1), .int(2)]),
                "changed": .dictionary(["a": .int(1), "b": .int(9)])
            ])
        )
    }

    @Test("what orders with nothing is not sorted around")
    func aFractionThatIsNotANumberRefusesToSort() async {
        // Given. NaN answers no comparison, so any placement of it would be an
        // order sorted could not answer for; refused, the way a mixed array is,
        // rather than placed arbitrarily
        await #expect {
            try await run(
                Procedure(
                    signature: Signature(returns: .array(.double)),
                    body: [],
                    result: .call(
                        Call(
                            selector: "std.collection.sorted",
                            arguments: [.literal(.array([.double(1.5), .double(.nan)]))]
                        )
                    )
                )
            )
        } throws: { error in
            "\(error)".contains("which have no order")
        }
    }

    // MARK: - Public
    // MARK: - Private
}
