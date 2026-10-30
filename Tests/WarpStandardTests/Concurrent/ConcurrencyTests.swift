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

// Running at once is vocabulary, not grammar. `Standard.Concurrent` takes isolated
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
    @Test("allKeyed returns what a dictionary's closures return, under the dictionary's keys")
    func allKeyedReturnsADictionary() async throws {
        // Given
        let sut = Statement(binding: .constant("both"), expression: .call(
                Call(
                    selector: "Standard.Concurrent.allKeyed",
                    arguments: [
                        dictionary([
                            "left": .closure(Procedure(signature: Signature(returns: .int, isolation: .isolated), body: [returning(.literal(.int(1)))])),
                            "right": .closure(Procedure(signature: Signature(returns: .int, isolation: .isolated), body: [returning(.literal(.int(2)))]))
                        ])
                    ]
                )
            )
        )

        // When
        let returned = try await returned(of: [sut], returning: reference("both"))

        // Then
        #expect(returned == .dictionary(["left": .int(1), "right": .int(2)]))
    }

    @Test("all returns what an array's closures return, in the array's order")
    func allReturnsAnArrayInOrder() async throws {
        // Given
        let sut = Statement(binding: .constant("all"), expression: .call(
                Call(
                    selector: "Standard.Concurrent.all",
                    arguments: [
                        .array([
                            .closure(Procedure(signature: Signature(returns: .int, isolation: .isolated), body: [returning(.literal(.int(1)))])),
                            .closure(Procedure(signature: Signature(returns: .int, isolation: .isolated), body: [returning(.literal(.int(2)))])),
                            .closure(Procedure(signature: Signature(returns: .int, isolation: .isolated), body: [returning(.literal(.int(3)))]))
                        ])
                    ]
                )
            )
        )

        // When
        let returned = try await returned(of: [sut], returning: reference("all"))

        // Then. Arrival order decided nothing
        #expect(returned == .array([.int(1), .int(2), .int(3)]))
    }

    @Test("map walks a collection and returns in the collection's order")
    func mapReturnsInOrder() async throws {
        // Given
        let sut = Statement(binding: .constant("kept"), expression: .call(
                Call(
                    selector: "Standard.Concurrent.map",
                    arguments: [
                        .literal(.array([.int(1), .int(2), .int(3)])),
                        .closure(
                            Procedure(
                                signature: Signature(
                                    parameters: [
                                        Parameter(name: "item", type: .any),
                                        Parameter(name: "index", type: .any)
                                    ],
                                    returns: .any,
                                    isolation: .isolated
                                ),
                                body: [returning(reference("item"))]
                            )
                        )
                    ]
                )
            )
        )

        // When
        let returned = try await returned(of: [sut], returning: reference("kept"))

        // Then
        #expect(returned == .array([.int(1), .int(2), .int(3)]))
    }

    @Test("a closure a walk calls declares as many parameters as the walk hands over")
    func mapHandsOverEveryName() async throws {
        // Given. `Standard.Concurrent.map` hands over the item and its index, and
        // this closure declares one parameter. A value nothing can receive is
        // not one to hand over quietly
        let sut = Statement(binding: .constant("placed"), expression: .call(
                Call(
                    selector: "Standard.Concurrent.map",
                    arguments: [
                        .literal(.array([.string("a"), .string("b")])),
                        .closure(
                            Procedure(
                                signature: Signature(
                                    parameters: [Parameter(name: "index", type: .any)],
                                    returns: .any,
                                    isolation: .isolated
                                ),
                                body: [returning(reference("index"))]
                            )
                        )
                    ]
                )
            )
        )

        // When / Then
        await #expect {
            try await returned(of: [sut], returning: reference("placed"))
        } throws: { error in
            error is BuildError
                && "\(error)".contains("holds isolated (Any) -> Any where isolated (")
        }
    }

    @Test("a null element is an element, not a missing argument")
    func mapCarriesNullElements() async throws {
        // Given. The sequential walk hands a null element straight to its body,
        // and running the same walk at once must not turn that into "nothing
        // was given": what a procedure offers is what arrived
        let sut = Statement(binding: .constant("kept"), expression: .call(
                Call(
                    selector: "Standard.Concurrent.map",
                    arguments: [
                        .literal(.array([.int(1), .null, .int(3)])),
                        .closure(
                            Procedure(
                                signature: Signature(
                                    parameters: [
                                        Parameter(name: "item", type: .any),
                                        Parameter(name: "index", type: .any)
                                    ],
                                    returns: .any,
                                    isolation: .isolated
                                ),
                                body: [returning(reference("item"))]
                            )
                        )
                    ]
                )
            )
        )

        // When
        let returned = try await returned(of: [sut], returning: reference("kept"))

        // Then
        #expect(returned == .array([.int(1), .null, .int(3)]))
    }

    @Test("a map over nothing returns an empty array, rather than failing")
    func mapOverNothingReturnsEmpty() async throws {
        // Given
        let sut = Statement(binding: .constant("none"), expression: .call(
                Call(
                    selector: "Standard.Concurrent.map",
                    arguments: [
                        .literal(.array([])),
                        .closure(
                            Procedure(
                                signature: Signature(
                                    parameters: [Parameter(name: "item", type: .any), Parameter(name: "index", type: .int)],
                                    returns: .any,
                                    isolation: .isolated
                                ),
                                body: [returning(reference("item"))]
                            )
                        )
                    ]
                )
            )
        )

        // When
        let returned = try await returned(of: [sut], returning: reference("none"))

        // Then
        #expect(returned == .array([]))
    }

    @Test("first returns one piece, and the failures beside it do not count")
    func firstReturnsTheSuccess() async throws {
        // Given. One closure cannot succeed, and a first only needs one that
        // can
        let sut = Statement(binding: .constant("either"), expression: .call(
                Call(
                    selector: "Standard.Concurrent.first",
                    arguments: [
                        .array([
                            .closure(
                                Procedure(
                                    signature: Signature(failing: .these(["aborted"]), isolation: .isolated),
                                    body: [Statement(expression: aborting(literal("doomed")))]
                                )
                            ),
                            .closure(Procedure(signature: Signature(returns: .any, isolation: .isolated), body: [returning(.literal(.string("answered")))]))
                        ])
                    ]
                )
            )
        )

        // When
        let returned = try await returned(
            of: [sut],
            returning: reference("either")
        )

        // Then
        #expect(returned == .string("answered"))
    }

    @Test("first asks the pieces still running to stop")
    func firstCancelsTheRest() async throws {
        // Given. One piece returns at once, the other waits far longer than the
        // test does. Returning from the procedure awaits every sibling, so without
        // the ask this would take the sibling's time, not the winner's.
        let waiting = CancellationWatch()
        let sut = Statement(binding: .constant("either"), expression: .call(
                Call(
                    selector: "Standard.Concurrent.first",
                    arguments: [
                        .array([
                            .closure(Procedure(signature: Signature(returns: .any, isolation: .isolated), body: [returning(.literal(.string("answered")))])),
                            .closure(
                                Procedure(
                                    signature: Signature(returns: .any, isolation: .isolated),
                                    body: [
                                        Statement(binding: .constant("slow"), expression: .call(Call(selector: "App.wait"))
                                        ),
                                        returning(reference("slow"))
                                    ]
                                )
                            )
                        ])
                    ]
                )
            )
        )

        // When
        let returned = try await returned(
            of: [sut],
            returning: reference("either"),
            vocabulary: Module.standard + [
                try Module(
                    procedures: [
                        "App.wait": Procedure(
                            signature: Signature(isolation: .isolated),
                            implementation: .effect(WaitEffect(watch: waiting))
                        )
                    ]
                )
            ]
        )

        // Then. Every piece has ended by the time `first` returns, so a piece
        // that started was asked to stop. One the ask reached before it
        // started never runs.
        let started = await waiting.hasStarted
        let cancelled = await waiting.wasCancelled

        #expect(returned == .string("answered"))
        #expect(!started || cancelled)
    }

    @Test("a first nothing wins fails like all does")
    func firstWithoutASuccessFails() async throws {
        // Given
        let sut = Statement(binding: .constant("either"), expression: .call(
                Call(
                    selector: "Standard.Concurrent.first",
                    arguments: [
                        .array([
                            .closure(
                                Procedure(
                                    signature: Signature(returns: .int, failing: .these(["aborted"]), isolation: .isolated),
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
            try await returned(of: [sut], returning: reference("either"))
        }
    }

    @Test("all reports every failure, keyed by the piece that failed")
    func allReportsEveryFailure() async throws {
        // Given. Two pieces fail. Which failures a catch reads must be every
        // one of them, whichever finished first.
        let doomed = Warp.Expression.closure(
            Procedure(
                signature: Signature(failing: .these(["aborted"]), isolation: .isolated),
                body: [Statement(expression: aborting(literal("doomed")))]
            )
        )
        let sut = Statement(binding: .constant("both"), expression: .call(
                Call(selector: "Standard.Concurrent.allKeyed", arguments: [dictionary(["first": doomed, "second": doomed])])
            )
        )

        // When / Then
        await #expect {
            try await returned(of: [sut], returning: reference("both"))
        } throws: { error in
            guard let failed = error as? ConcurrentFailed else { return false }

            return failed.failures.keys == [.string("first"), .string("second")]
        }
    }

    @Test("a piece that is not a closure is refused at the build, the list judged part by part")
    func aValueAmongTheClosuresIsRefused() async throws {
        // Given
        let sut = Statement(binding: .constant("both"), expression: .call(
                Call(
                    selector: "Standard.Concurrent.all",
                    arguments: [
                        .array([
                            .closure(Procedure(signature: Signature(returns: .int, isolation: .isolated), body: [returning(.literal(.int(1)))])),
                            .literal(.int(2))
                        ])
                    ]
                )
            )
        )

        // When / Then
        await #expect {
            try await returned(of: [sut], returning: reference("both"))
        } throws: { error in
            "\(error)" == "procedures.entry.body.both[0].call.arguments[0][1]: sending 'Standard.Concurrent.all'"
                + " with pieces[1], which holds Int where isolated () throws -> Any is declared"
        }
    }

    @Test("map refuses material read as `Any`")
    func mapRefusesMaterialReadAsAny() async throws {
        // Given. The material arrives as `Any`, which a slot of a type takes
        // only through a cast, so the build refuses it
        let sut = Statement(binding: .constant("walked"), expression: .call(
                Call(
                    selector: "Standard.Concurrent.map",
                    arguments: [
                        reference("subject"),
                        .closure(
                            Procedure(
                                signature: Signature(
                                    parameters: [Parameter(name: "item", type: .any), Parameter(name: "index", type: .int)],
                                    returns: .any,
                                    isolation: .isolated
                                ),
                                body: [returning(reference("item"))]
                            )
                        )
                    ]
                )
            )
        )

        // When / Then
        await #expect {
            try await returned(
                of: [sut],
                returning: reference("walked"),
                arguments: ["subject": .string("not a collection")],
                signature: Signature(parameters: [Parameter(name: "subject", type: .any)], returns: .any, failing: .anything)
            )
        } throws: { error in
            error is BuildError && "\(error)".contains("with array, which holds Any where")
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
                        returns: .array(.int),
                        failing: .these(["concurrent_failed"])
                    ),
                    body: [
                        returning(.call(Call(
                            selector: "Standard.Concurrent.map",
                            arguments: [
                                .call(Call(selector: "Standard.Collection.reversed", arguments: [reference("items")])),
                                .closure(Procedure(
                                    signature: Signature(
                                        parameters: [
                                            Parameter(name: "item", type: .int),
                                            Parameter(name: "index", type: .int)
                                        ],
                                        returns: .int,
                                        isolation: .isolated
                                    ),
                                    body: [returning(reference("item"))]
                                ))
                            ]
                        )))
                    ]
                )
            ]
        )

        // When
        let returned = try await run(sut, arguments: ["items": .array([.int(1), .int(2)])])

        // Then
        #expect(returned == .array([.int(2), .int(1)]))
    }

    // MARK: - Public
    // MARK: - Private
}
