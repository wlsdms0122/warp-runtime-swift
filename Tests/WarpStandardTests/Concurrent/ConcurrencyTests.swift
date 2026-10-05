//
//  ConcurrencyTests.swift
//  WarpStandardTests
//
//  Created by JSilver on 8/18/26.
//

import Foundation
import Testing
import Warp
import WarpStandard
import WarpTestSupport

// Running at once is vocabulary, not grammar. `std.concurrent` takes isolated
// closures, and a host that leaves the bundle out of the link has granted no
// concurrency at all.
@Suite("Running at once")
struct ConcurrencyTests {
    private actor CancellationWatch {
        // MARK: - Property
        private(set) var hasStarted = false
        private(set) var wasCancelled = false

        // MARK: - Initializer
        // MARK: - Public
        func start() {
            hasStarted = true
        }

        func record() {
            wasCancelled = true
        }

        // MARK: - Private
    }

    private struct WaitEffect: Effect {
        typealias Parameters = NoParameters

        // MARK: - Property
        let watch: CancellationWatch

        // MARK: - Initializer
        // MARK: - Public
        func run(_ invocation: Invocation<Self>) async throws -> Value {
            await watch.start()

            do {
                try await Task.sleep(for: .seconds(30))
            } catch {
                await watch.record()

                throw error
            }

            return .null
        }

        // MARK: - Private
    }

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("all answers a record's closures under the record's keys")
    func allAnswersARecord() async throws {
        // Given
        let sut = Statement(binding: .constant("both"), expression: .call(
                Call(
                    selector: "std.concurrent.all",
                    arguments: [
                        .record([
                            "left": .closure(Procedure(body: [], result: .literal(.int(1)))),
                            "right": .closure(Procedure(body: [], result: .literal(.int(2))))
                        ])
                    ]
                )
            )
        )

        // When
        let answer = try await answer(of: [sut], result: reference("both"))

        // Then
        #expect(answer == .dictionary(["left": .int(1), "right": .int(2)]))
    }

    @Test("all answers an array's closures in the array's order")
    func allAnswersAnArrayInOrder() async throws {
        // Given
        let sut = Statement(binding: .constant("all"), expression: .call(
                Call(
                    selector: "std.concurrent.all",
                    arguments: [
                        .array([
                            .closure(Procedure(body: [], result: .literal(.int(1)))),
                            .closure(Procedure(body: [], result: .literal(.int(2)))),
                            .closure(Procedure(body: [], result: .literal(.int(3))))
                        ])
                    ]
                )
            )
        )

        // When
        let answer = try await answer(of: [sut], result: reference("all"))

        // Then. Arrival order decided nothing
        #expect(answer == .array([.int(1), .int(2), .int(3)]))
    }

    @Test("map walks a collection and answers in the collection's order")
    func mapAnswersInOrder() async throws {
        // Given
        let sut = Statement(binding: .constant("kept"), expression: .call(
                Call(
                    selector: "std.concurrent.map",
                    arguments: [
                        .literal(.array([.int(1), .int(2), .int(3)])),
                        .closure(
                            Procedure(
                                signature: Signature(
                                    parameters: [
                                        Parameter(name: "item", type: .any),
                                        Parameter(name: "index", type: .any)
                                    ]
                                ),
                                body: [],
                                result: reference("item")
                            )
                        )
                    ]
                )
            )
        )

        // When
        let answer = try await answer(of: [sut], result: reference("kept"))

        // Then
        #expect(answer == .array([.int(1), .int(2), .int(3)]))
    }

    @Test("a closure a walk calls declares as many parameters as the walk hands over")
    func mapHandsOverEveryName() async throws {
        // Given. `std.concurrent.map` hands over the item and its index, and
        // this closure declares one parameter. A value nothing can receive is
        // not one to hand over quietly
        let sut = Statement(binding: .constant("placed"), expression: .call(
                Call(
                    selector: "std.concurrent.map",
                    arguments: [
                        .literal(.array([.string("a"), .string("b")])),
                        .closure(
                            Procedure(
                                signature: Signature(
                                    parameters: [Parameter(name: "index", type: .any)]
                                ),
                                body: [],
                                result: reference("index")
                            )
                        )
                    ]
                )
            )
        )

        // When / Then
        await #expect {
            try await answer(of: [sut], result: reference("placed"))
        } throws: { error in
            error is BuildError
                && "\(error)".contains("holds const isolated procedure<(any) -> any> where isolated procedure<(")
        }
    }

    @Test("a null element is an element, not a missing argument")
    func mapCarriesNullElements() async throws {
        // Given. The sequential walk hands a null element straight to its body,
        // and running the same walk at once must not turn that into "nothing
        // was given": what a procedure offers is what arrived
        let sut = Statement(binding: .constant("kept"), expression: .call(
                Call(
                    selector: "std.concurrent.map",
                    arguments: [
                        .literal(.array([.int(1), .null, .int(3)])),
                        .closure(
                            Procedure(
                                signature: Signature(
                                    parameters: [
                                        Parameter(name: "item", type: .any),
                                        Parameter(name: "index", type: .any)
                                    ]
                                ),
                                body: [],
                                result: reference("item")
                            )
                        )
                    ]
                )
            )
        )

        // When
        let answer = try await answer(of: [sut], result: reference("kept"))

        // Then
        #expect(answer == .array([.int(1), .null, .int(3)]))
    }

    @Test("a map over nothing answers nothing, rather than failing")
    func mapOverNothingAnswersEmpty() async throws {
        // Given
        let sut = Statement(binding: .constant("none"), expression: .call(
                Call(
                    selector: "std.concurrent.map",
                    arguments: [
                        .literal(.array([])),
                        .closure(
                            Procedure(
                                signature: Signature(
                                    parameters: [Parameter(name: "item", type: .any), Parameter(name: "index", type: .int)]
                                ),
                                body: [],
                                result: reference("item")
                            )
                        )
                    ]
                )
            )
        )

        // When
        let answer = try await answer(of: [sut], result: reference("none"))

        // Then
        #expect(answer == .array([]))
    }

    @Test("first answers one piece, and the failures beside it do not count")
    func firstAnswersTheSuccess() async throws {
        // Given. One closure cannot succeed, and a first only needs one that
        // can
        let sut = Statement(binding: .constant("either"), expression: .call(
                Call(
                    selector: "std.concurrent.first",
                    arguments: [
                        .array([
                            .closure(
                                Procedure(
                                    body: [Statement(expression: aborting(literal("doomed")))]
                                )
                            ),
                            .closure(Procedure(body: [], result: .literal(.string("answered"))))
                        ])
                    ]
                )
            )
        )

        // When
        let answer = try await answer(
            of: [sut],
            result: reference("either")
        )

        // Then
        #expect(answer == .string("answered"))
    }

    @Test("first asks the pieces still running to stop")
    func firstCancelsTheRest() async throws {
        // Given. One piece answers at once, the other waits far longer than the
        // test does. Returning from the procedure awaits every sibling, so without
        // the ask this would take the sibling's time, not the winner's.
        let waiting = CancellationWatch()
        let sut = Statement(binding: .constant("either"), expression: .call(
                Call(
                    selector: "std.concurrent.first",
                    arguments: [
                        .array([
                            .closure(Procedure(body: [], result: .literal(.string("answered")))),
                            .closure(
                                Procedure(
                                    body: [
                                        Statement(binding: .constant("slow"), expression: .call(Call(selector: "app.wait"))
                                        )
                                    ],
                                    result: reference("slow")
                                )
                            )
                        ])
                    ]
                )
            )
        )

        // When
        let answer = try await answer(
            of: [sut],
            result: reference("either"),
            vocabulary: Module.standard + [
                try Module(
                    procedures: [
                        "app.wait": Procedure(implementation: .effect(WaitEffect(watch: waiting)))
                    ]
                )
            ]
        )

        // Then. Every piece has ended by the time `first` answers, so a piece
        // that started was asked to stop. One the ask reached before it
        // started never runs.
        let started = await waiting.hasStarted
        let cancelled = await waiting.wasCancelled

        #expect(answer == .string("answered"))
        #expect(!started || cancelled)
    }

    @Test("a first nothing wins fails like all does")
    func firstWithoutASuccessFails() async throws {
        // Given
        let sut = Statement(binding: .constant("either"), expression: .call(
                Call(
                    selector: "std.concurrent.first",
                    arguments: [
                        .array([
                            .closure(
                                Procedure(
                                    body: [Statement(expression: aborting(literal("doomed")))]
                                )
                            )
                        ])
                    ]
                )
            )
        )

        // When / Then
        await #expect(throws: ConcurrentFailed.self) {
            try await answer(of: [sut], result: reference("either"))
        }
    }

    @Test("all reports every failure, keyed by the piece that failed")
    func allReportsEveryFailure() async throws {
        // Given. Two pieces fail. Which failures a rescue reads must be every
        // one of them, whichever finished first.
        let doomed = Warp.Expression.closure(
            Procedure(body: [Statement(expression: aborting(literal("doomed")))])
        )
        let sut = Statement(binding: .constant("both"), expression: .call(
                Call(selector: "std.concurrent.all", arguments: [.record(["first": doomed, "second": doomed])])
            )
        )

        // When / Then
        await #expect {
            try await answer(of: [sut], result: reference("both"))
        } throws: { error in
            guard let failed = error as? ConcurrentFailed else { return false }

            return failed.failures.keys.sorted() == ["first", "second"]
        }
    }

    @Test("a piece that is not a closure is refused at the build, the list judged part by part")
    func aValueAmongTheClosuresIsRefused() async throws {
        // Given
        let sut = Statement(binding: .constant("both"), expression: .call(
                Call(
                    selector: "std.concurrent.all",
                    arguments: [
                        .array([
                            .closure(Procedure(body: [], result: .literal(.int(1)))),
                            .literal(.int(2))
                        ])
                    ]
                )
            )
        )

        // When / Then
        await #expect {
            try await answer(of: [sut], result: reference("both"))
        } throws: { error in
            "\(error)".contains("with pieces, which holds [const isolated procedure<() -> any>, int] where std.concurrent.Pieces is declared")
        }
    }

    @Test("map refuses material that is not a collection")
    func mapRefusesUnfitMaterial() async throws {
        // Given. The material arrives as `any`, so only the run can judge it,
        // and the boundary every procedure shares is what judges it
        let sut = Statement(binding: .constant("walked"), expression: .call(
                Call(
                    selector: "std.concurrent.map",
                    arguments: [
                        reference("subject"),
                        .closure(
                            Procedure(
                                signature: Signature(
                                    parameters: [Parameter(name: "item", type: .any), Parameter(name: "index", type: .int)]
                                ),
                                body: [],
                                result: reference("item")
                            )
                        )
                    ]
                )
            )
        )

        // When / Then
        await #expect {
            try await answer(
                of: [sut],
                result: reference("walked"),
                arguments: ["subject": .string("not a collection")],
                signature: Signature(parameters: [Parameter(name: "subject", type: .any)])
            )
        } throws: { error in
            "\(error)".contains("expected array") && "\(error)".contains("got string")
        }
    }

    @Test("an effect reads the first argument it was handed")
    func anEffectReadsItsFirstArgument() async throws {
        // Given. A native procedure reads its first argument through its
        // invocation.
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [Parameter(name: "items", type: .array(.int))],
                        returns: .array(.int)
                    ),
                    body: [],
                    result: .call(Call(
                        selector: "std.concurrent.map",
                        arguments: [
                            .call(Call(selector: "std.collection.reversed", arguments: [reference("items")])),
                            .closure(Procedure(
                                signature: Signature(
                                    parameters: [
                                        Parameter(name: "item", type: .int),
                                        Parameter(name: "index", type: .int)
                                    ],
                                    returns: .int
                                ),
                                body: [],
                                result: reference("item")
                            ))
                        ]
                    ))
                )
            ]
        )

        // When
        let answered = try await run(sut, arguments: ["items": .array([.int(1), .int(2)])])

        // Then
        #expect(answered == .array([.int(2), .int(1)]))
    }

    // MARK: - Public
    // MARK: - Private
}
