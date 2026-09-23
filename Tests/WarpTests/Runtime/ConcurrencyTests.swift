//
//  ConcurrencyTests.swift
//  WarpTests
//
//  Created by JSilver on 8/18/26.
//

import Foundation
import Testing
@testable import Warp
import WarpStandard

// Running at once is vocabulary, not grammar. A closure is the one body that is
// safe to run beside another (it captured values and writes no name it did not
// declare) so `std.concurrent` takes closures, and a caller that leaves the
// bundle out of the link has granted no concurrency at all.
@Suite("Running at once")
struct ConcurrencyTests {
    // MARK: - Property
    // MARK: - Lifecycle
    // MARK: - Test
    @Test("all answers a record's closures under the record's keys")
    func allAnswersARecord() async throws {
        // Given
        let sut = Statement(binding: .constant("both"), expression: .call(
                Call(
                    receiver: .record([
                        "left": .closure(Procedure(body: [], result: .literal(.int(1)))),
                        "right": .closure(Procedure(body: [], result: .literal(.int(2))))
                    ]),
                    selector: "std.concurrent.all"
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
                    receiver: .array([
                        .closure(Procedure(body: [], result: .literal(.int(1)))),
                        .closure(Procedure(body: [], result: .literal(.int(2)))),
                        .closure(Procedure(body: [], result: .literal(.int(3))))
                    ]),
                    selector: "std.concurrent.all"
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
        // Given. The concurrent reading of what `each` walks
        let sut = Statement(binding: .constant("kept"), expression: .call(
                Call(
                    receiver: .literal(.array([.int(1), .int(2), .int(3)])),
                    selector: "std.concurrent.map",
                    arguments: [
                        "by": .closure(
                            Procedure(
                                signature: Signature(
                                    parameters: [
                                        "index": Parameter(type: .any),
                                        "item": Parameter(type: .any)
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

    @Test("a closure a walk calls declares every name the walk hands over")
    func mapHandsOverEveryName() async throws {
        // Given. `std.concurrent.map` hands over `item` and `index`, and this
        // closure declares only the second. A name nothing can receive is not
        // one to hand over quietly
        let sut = Statement(binding: .constant("placed"), expression: .call(
                Call(
                    receiver: .literal(.array([.string("a"), .string("b")])),
                    selector: "std.concurrent.map",
                    arguments: [
                        "by": .closure(
                            Procedure(
                                signature: Signature(
                                    parameters: ["index": Parameter(type: .any)]
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
            error is BuildError && "\(error)".contains("where isolated procedure<(index: int, item: string)")
        }
    }

    @Test("a null element is an element, not a missing argument")
    func mapCarriesNullElements() async throws {
        // Given. The sequential walk hands a null element straight to its body,
        // and running the same walk at once must not turn that into "nothing
        // was given": what a procedure offers is what arrived
        let sut = Statement(binding: .constant("kept"), expression: .call(
                Call(
                    receiver: .literal(.array([.int(1), .null, .int(3)])),
                    selector: "std.concurrent.map",
                    arguments: [
                        "by": .closure(
                            Procedure(
                                signature: Signature(
                                    parameters: [
                                        "index": Parameter(type: .any),
                                        "item": Parameter(type: .any)
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
                    receiver: .literal(.array([])),
                    selector: "std.concurrent.map",
                    arguments: [
                        "by": .closure(
                            Procedure(
                                signature: Signature(
                                    parameters: ["item": Parameter(type: .any), "index": Parameter(type: .int)]
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
                    receiver: .array([
                        .closure(
                            Procedure(
                                body: [
                                    Statement(binding: .constant("doomed"), expression: .call(
                                            Call(
                                                selector: "app.fail",
                                                arguments: ["recoverable": .literal(.bool(true))]
                                            )
                                        )
                                    )
                                ],
                                result: reference("doomed")
                            )
                        ),
                        .closure(Procedure(body: [], result: .literal(.string("answered"))))
                    ]),
                    selector: "std.concurrent.first"
                )
            )
        )

        // When
        let answer = try await answer(
            of: [sut],
            result: reference("either"),
            vocabulary: Module.standard + [.failing]
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
                    receiver: .array([
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
                    ]),
                    selector: "std.concurrent.first"
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

        // Then
        #expect(answer == .string("answered"))
        #expect(await waiting.wasCancelled)
    }

    @Test("a first nothing wins fails like all does")
    func firstWithoutASuccessFails() async throws {
        // Given
        let sut = Statement(binding: .constant("either"), expression: .call(
                Call(
                    receiver: .array([
                        .closure(
                            Procedure(
                                body: [
                                    Statement(binding: .constant("doomed"), expression: .call(
                                            Call(
                                                selector: "app.fail",
                                                arguments: ["recoverable": .literal(.bool(true))]
                                            )
                                        )
                                    )
                                ],
                                result: reference("doomed")
                            )
                        )
                    ]),
                    selector: "std.concurrent.first"
                )
            )
        )

        // When / Then
        await #expect(throws: ConcurrentFailed.self) {
            try await answer(
                of: [sut],
                result: reference("either"),
                vocabulary: Module.standard + [.failing]
            )
        }
    }

    @Test("all reports every failure, keyed by the piece that failed")
    func allReportsEveryFailure() async throws {
        // Given. Two pieces fail. Which failures a rescue reads must be every
        // one of them, whichever finished first.
        let doomed = Warp.Expression.closure(
            Procedure(
                body: [
                    Statement(binding: .constant("doomed"), expression: .call(
                            Call(
                                selector: "app.fail",
                                arguments: ["recoverable": .literal(.bool(true))]
                            )
                        )
                    )
                ],
                result: reference("doomed")
            )
        )
        let sut = Statement(binding: .constant("both"), expression: .call(
                Call(
                    receiver: .record(["first": doomed, "second": doomed]),
                    selector: "std.concurrent.all"
                )
            )
        )

        // When / Then
        await #expect {
            try await answer(
                of: [sut],
                result: reference("both"),
                vocabulary: Module.standard + [.failing]
            )
        } throws: { error in
            guard let failed = error as? ConcurrentFailed else { return false }

            return failed.failures.keys.sorted() == ["first", "second"]
        }
    }

    @Test("a piece that is not a closure is refused, named by where it sat")
    func aValueAmongTheClosuresIsRefused() async throws {
        // Given
        let sut = Statement(binding: .constant("both"), expression: .call(
                Call(
                    receiver: .array([
                        .closure(Procedure(body: [], result: .literal(.int(1)))),
                        .literal(.int(2))
                    ]),
                    selector: "std.concurrent.all"
                )
            )
        )

        // When / Then
        await #expect {
            try await answer(of: [sut], result: reference("both"))
        } throws: { error in
            "\(error)".contains("the receiver of 'std.concurrent.all'[1]: expected isolated procedure, got int")
        }
    }

    @Test("map refuses material that is not a collection")
    func mapRefusesUnfitMaterial() async throws {
        // Given. The material arrives as `any`, so only the run can judge it,
        // and the boundary every procedure shares is what judges it
        let sut = Statement(binding: .constant("walked"), expression: .call(
                Call(
                    receiver: reference("subject"),
                    selector: "std.concurrent.map",
                    arguments: [
                        "by": .closure(
                            Procedure(
                                signature: Signature(
                                    parameters: ["item": Parameter(type: .any), "index": Parameter(type: .int)]
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
                signature: Signature(parameters: ["subject": Parameter(type: .any)])
            )
        } throws: { error in
            "\(error)".contains("expected array") && "\(error)".contains("got string")
        }
    }

}

// MARK: - A piece that outlives the answer

private actor CancellationWatch {
    // MARK: - Property
    private(set) var wasCancelled = false

    // MARK: - Initializer
    // MARK: - Public
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
