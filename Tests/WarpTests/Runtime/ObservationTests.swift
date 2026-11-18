//
//  ObservationTests.swift
//  WarpTests
//
//  Created by JSilver on 8/18/26.
//

import Foundation
import Testing
@testable import Warp
import WarpStandard
import WarpTestSupport

// What a host is told while a run happens: the language's only outward
// account of a run in progress.
@Suite("What a run reports while it runs")
struct ObservationTests {
    private enum ObservedEvent: Equatable {
        case started(String)
        case completed(String, Value)
        case failed(String)
        case caught(String)
    }

    private actor RecordingObserver: ExecutionObserver {
        // MARK: - Property
        private(set) var events: [ObservedEvent] = []

        // MARK: - Initializer
        // MARK: - Public
        func statementStarted(at trace: Trace) {
            events.append(.started(trace.rendered))
        }

        func statementCompleted(at trace: Trace, result: Value) {
            events.append(.completed(trace.rendered, result))
        }

        func statementFailed(at trace: Trace, error: any Error) {
            events.append(.failed(trace.rendered))
        }

        func failureCaught(name: String?, error: any Error) {
            events.append(.caught(name ?? ""))
        }

        // MARK: - Private
    }

    // MARK: - Property
    private let builder = Builder()

    // MARK: - Initializer
    // MARK: - Test
    @Test("every statement is announced before it runs and again with its value")
    func statementsAreAnnounced() async throws {
        // Given
        let observer = RecordingObserver()
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(returns: .int),
                    body: [
                        Statement(binding: .constant("first"), expression: .literal(.int(1))),
                        Statement(binding: .constant("second"), expression: .literal(.int(2))),
                        returning(reference("second"))
                    ]
                )
            ]
        )

        // When
        let image = try await builder.build([sut] + Module.standard)

        _ = try await Executor(observer: observer).run(image)

        // Then
        #expect(await observer.events == [
            .started("first"),
            .completed("first", .int(1)),
            .started("second"),
            .completed("second", .int(2)),
            .started("[2]")
        ])
    }

    @Test("a statement inside a body is announced under the place it ran in")
    func nestedStatementsAreAnnounced() async throws {
        // Given. Observation follows the run, not the top level of the text
        let observer = RecordingObserver()
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(returns: .int),
                    body: [
                        Statement(binding: .constant("outer"), expression: .loop(
                                while: .literal(.bool(true)),
                                body: [
                                    Statement(binding: .constant("inner"), expression: .literal(.int(7))),
                                    Statement(expression: .leave(.loop(nil)))
                                ]
                            )
                        ),
                        returning(.literal(.int(1)))
                    ]
                )
            ]
        )

        // When
        let image = try await builder.build([sut] + Module.standard)

        _ = try await Executor(observer: observer).run(image)

        // Then
        #expect(await observer.events.contains(.started("outer[0].inner")))
        #expect(await observer.events.contains(.completed("outer[0].inner", .int(7))))
    }

    @Test("the same statement run twice is announced as two different places")
    func roundsAreToldApart() async throws {
        // Given. The text says `step` once, and the run reaches it once a round
        let observer = RecordingObserver()
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    body: [
                        Statement(binding: .constant("round"), expression: .loop(
                                while: .call(
                                    Call(
                                        selector: "Standard.Comparable.lessThan",
                                        arguments: [reference("round", "index"), .literal(.int(2))]
                                    )
                                ),
                                body: [
                                    Statement(binding: .constant("step"), expression: reference("round", "index"))
                                ]
                            )
                        )
                    ]
                )
            ]
        )

        // When
        let image = try await builder.build([sut] + Module.standard)

        _ = try await Executor(observer: observer).run(image)

        // Then
        #expect(await observer.events.contains(.completed("round[0].step", .int(0))))
        #expect(await observer.events.contains(.completed("round[1].step", .int(1))))
    }

    @Test("a piece of a fan-out is announced under which piece it is")
    func piecesAreToldApart() async throws {
        // Given. `Standard.Concurrent.map` is written in Warp, so the walk that
        // builds the pieces stands in the path too, and so does the closure
        // of its own it runs each piece in. What tells the pieces apart is
        // the number the fan-out put on each
        let observer = RecordingObserver()
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(failing: .these(["concurrent_failed"])),
                    body: [
                        Statement(binding: .constant("both"), expression: .call(
                                Call(
                                    selector: "Standard.Concurrent.map",
                                    arguments: [
                                        .literal(.array([.int(1), .int(2)])),
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
                                                body: [
                                                    Statement(binding: .constant("step"), expression: reference("item")),
                                                    returning(reference("step"))
                                                ]
                                            )
                                        )
                                    ]
                                )
                            )
                        )
                    ]
                )
            ]
        )

        // When
        let image = try await builder.build([sut] + Module.standard)

        _ = try await Executor(observer: observer).run(image)

        // Then. What stands between the piece's number and the closure is the
        // library's own
        let events = await observer.events

        #expect(completed(piece: 0, with: .int(1), in: events))
        #expect(completed(piece: 1, with: .int(2), in: events))
    }

    @Test("a call into a body keeps the statement that called it")
    func aCallPushesRatherThanReplaces() async throws {
        // Given. A place is how the run got here, not where it ended up
        let observer = RecordingObserver()
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    body: [
                        Statement(binding: .constant("said"), expression: .call(Call(selector: "helper")))
                    ]
                ),
                "helper": Procedure(
                    signature: Signature(returns: .int),
                    body: [
                        Statement(binding: .constant("inner"), expression: .literal(.int(7))),
                        returning(reference("inner"))
                    ]
                )
            ]
        )

        // When
        let image = try await builder.build([sut] + Module.standard)

        _ = try await Executor(observer: observer).run(image)

        // Then
        #expect(await observer.events.contains(.completed("said.helper.inner", .int(7))))
    }

    @Test("a refusal carries the place it happened, not the one it passed through")
    func aRefusalCarriesItsInnermostPlace() async throws {
        // Given. The mistake is inside the body, two statements deep
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(failing: .these(["aborted"])),
                    body: [
                        // Nameless on both sides. `helper` declares no return type
                        // and its body never finishes, so the build reads the
                        // call as `Never` too, and a statement that never
                        // finishes takes no name, so the place is its position.
                        Statement(
                            expression: .call(Call(selector: "helper"))
                        )
                    ]
                ),
                "helper": Procedure(
                    signature: Signature(failing: .these(["aborted"])),
                    body: [
                        Statement(
                            expression: aborting(literal("no"))
                        )
                    ]
                )
            ]
        )

        // When
        let image = try await builder.build([sut] + Module.standard)

        // Then
        let error = await #expect(throws: Aborted.self) {
            try await Executor().run(image)
        }

        #expect(error?.trace?.rendered == "[0].helper.[0]")
        #expect(error.map { error in "\(error)" } == "[0].helper.[0]: no")
    }

    @Test("a refusal inside a closure says which of its writer's closures it was in")
    func aRefusalNamesTheClosureItWasIn() async throws {
        // Given. Two closures written by `entry`, and the second is the one
        // that refuses when called
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(failing: .these(["aborted"])),
                    body: [
                        Statement(
                            binding: .constant("first"),
                            expression: .closure(Procedure(signature: Signature(returns: .int), body: [returning(.literal(.int(1)))]))
                        ),
                        Statement(
                            binding: .constant("second", declared: .procedure(ProcedureType(returns: .int, failing: .these(["aborted"])))),
                            expression: .closure(
                                Procedure(
                                    signature: Signature(returns: .int, failing: .these(["aborted"])),
                                    body: [
                                        Statement(expression: aborting(literal("no")))
                                    ]
                                )
                            )
                        ),
                        Statement(binding: .constant("called"), expression: .apply(reference("second"), arguments: []))
                    ]
                )
            ]
        )

        let image = try await builder.build([sut] + Module.standard)

        // When / Then
        await #expect {
            try await Executor().run(image)
        } throws: { error in
            (error as? Aborted)?.trace?.rendered == "called.entry.closure[1].[0]"
        }
    }

    @Test("a statement that fails is announced as failed and not as completed")
    func failureIsAnnounced() async throws {
        // Given
        let observer = RecordingObserver()
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(failing: .these(["test"])),
                    body: [
                        Statement(binding: .constant("doomed"), expression: .call(Call(selector: "App.fail", arguments: [.literal(.bool(false))])))
                    ]
                )
            ]
        )

        // When
        let image = try await builder.build([sut] + Module.standard + [.failing])

        _ = try? await Executor(observer: observer).run(image)

        // Then
        let events = await observer.events

        #expect(events.contains(.failed("doomed")))
        #expect(!events.contains { event in
            if case let .completed(id, _) = event { return id == "doomed" }

            return false
        })
    }

    @Test("a statement a leave passes through is announced as started and never as ended")
    func aLeaveIsNoFailure() async throws {
        // Given. The break never finishes, so neither does the statement it
        // is written in; the loop it ends finishes
        let observer = RecordingObserver()
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(returns: .int),
                    body: [
                        Statement(binding: .constant("walk"), expression: .loop(
                                while: .literal(.bool(true)),
                                body: [
                                    Statement(expression: .leave(.loop(nil)))
                                ]
                            )
                        ),
                        returning(.literal(.int(1)))
                    ]
                )
            ]
        )

        // When
        let image = try await builder.build([sut] + Module.standard)
        let returned = try await Executor(observer: observer).run(image)

        // Then
        let events = await observer.events

        #expect(returned == .int(1))
        #expect(events == [
            .started("walk"),
            .started("walk[0].[0]"),
            .completed("walk", .null),
            .started("[1]")
        ])
    }

    @Test("a caught failure is announced under the name it was bound as")
    func catchIsAnnounced() async throws {
        // Given
        let observer = RecordingObserver()
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(returns: .optional(.string)),
                    body: [
                        Statement(binding: .variable("kept"), expression: .literal(.null)),
                        Statement(binding: .constant("fragile"), expression: .try(
                                [
                                    Statement(binding: .constant("doomed"), expression: .call(
                                        Call(selector: "App.fail", arguments: [.literal(.bool(true))])
                                    ))
                                ],
                                catch: [
                                    Statement(binding: .assignment([.name("kept")]), expression: .literal(.string("caught")))
                                ]
                            )
                        ),
                        returning(reference("kept"))
                    ]
                )
            ]
        )

        // When
        let image = try await builder.build([sut] + Module.standard + [.failing])
        let returned = try await Executor(observer: observer).run(image)

        // Then
        #expect(returned == .string("caught"))
        #expect(await observer.events.contains(.caught("fragile")))
    }

    // MARK: - Public
    // MARK: - Private
    private func completed(piece: Int, with value: Value, in events: [ObservedEvent]) -> Bool {
        events.contains { event in
            guard case let .completed(place, returned) = event else { return false }

            return place.hasPrefix("both.Standard.Concurrent.map.[2][\(piece)].")
                && place.hasSuffix(".entry.closure[0].step")
                && returned == value
        }
    }
}
