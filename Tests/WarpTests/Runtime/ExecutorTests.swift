//
//  ExecutorTests.swift
//  WarpTests
//
//  Created by JSilver on 8/9/26.
//

import Foundation
import Testing
@testable import Warp
import WarpStandard
import WarpTestSupport

@Suite("A body as it runs")
struct ExecutorTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("statements read the names before them")
    func statementsReadTheNamesBeforeThem() async throws {
        // Given
        let spec = try Module(
            procedures: [
                "entry": Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            Parameter(name: "who", type: .string)
                        ],
                        returns: .any
                    ),
                    body: [
                        Statement(binding: .constant("greeting"), expression: interpolated(literal("hello, "), spelling(reference("who")))),
                        Statement(binding: .constant("loud"), expression: interpolated(spelling(reference("greeting")), literal("!"))),
                        returning(map([
                                "result": .reference([.name("loud")])
                            ]))
                    ]
                )
            ]
        )

        // When
        let outputs = try await run(spec, arguments: ["who": .string("spec")])

        // Then
        #expect(outputs.map?["result"] == .string("hello, spec!"))
    }

    @Test("a recoverable failure runs the rescue path")
    func recoverableFailureRunsRescue() async throws {
        // Given
        let spec = try Module(
            procedures: [
                "entry": Procedure(
                    access: .public,
                    signature: Signature(returns: .any),
                    body: [
                        Statement(binding: .variable("kept"), expression: .literal(.null)),
                        Statement(binding: .constant("fragile"), expression: .attempt([
                                        Statement(binding: .constant("fragile"), expression: .call(Call(
                                            selector: "App.fail",
                                            arguments: [.literal(.bool(true))]
                                        )))
                                    ], rescue: [
                                        Statement(binding: .assignment([.name("kept")]), expression: .literal(.string("recovered")))
                                    ])
                        ),
                        returning(map([
                                "result": .reference([.name("kept")])
                            ]))
                    ]
                )
            ]
        )

        // When
        let outputs = try await run(spec, vocabulary: Module.standard + [.failing])

        // Then. What the rescue wrote is there after the attempt
        #expect(outputs.map?["result"] == .string("recovered"))
    }

    @Test("the failure is a value inside the rescue, and only there")
    func rescueSeesFailurePayload() async throws {
        // Given
        let spec = try Module(
            constants: ["fragile": .literal(.string("before"))],
            procedures: [
                "entry": Procedure(
                    access: .public,
                    signature: Signature(returns: .any),
                    body: [
                        Statement(binding: .variable("reason"), expression: .literal(.null)),
                        Statement(binding: .constant("fragile"), expression: .attempt([
                                        Statement(binding: .constant("doomed"), expression: .call(Call(
                                            selector: "App.fail",
                                            arguments: [.literal(.bool(true))]
                                        )))
                                    ], rescue: [
                                        Statement(binding: .assignment([.name("reason")]), expression: interpolated(
                                                literal("saw: "),
                                                spelling(reference("fragile", "message"))
                                            )
                                        )
                                    ])
                        ),
                        returning(map([
                                "reason": .reference([.name("reason")]),
                                "after": .reference([.name("fragile")])
                            ]))
                    ]
                )
            ]
        )

        // When
        let outputs = try await run(spec, vocabulary: Module.standard + [.failing])

        // Then. Inside the rescue, `fragile` was the failure payload; after it,
        // `fragile` is the name around the attempt, so the payload never leaks
        // past the rescue
        #expect(outputs.map?["reason"] == .string("saw: the world did not cooperate"))
        #expect(outputs.map?["after"] == .string("before"))
    }

    @Test("an unrescued failure propagates")
    func unrescuedFailurePropagates() async throws {
        // Given
        let spec = try Module(
            procedures: [
                "entry": Procedure(
                    access: .public,
                    signature: Signature(failing: .these(["test"])),
                    body: [
                        Statement(binding: .constant("fragile"), expression: .call(Call(
                            selector: "App.fail",
                            arguments: [.literal(.bool(true))]
                        )))
                    ]
                )
            ]
        )

        // When / Then
        await #expect(throws: TestRecoverableFailure.self) {
            try await run(spec, vocabulary: Module.standard + [.failing])
        }
    }

    @Test("a reference typo is not disguised by rescue")
    func referenceTypoBypassesRescue() async throws {
        // Given. Type misuse is an author error; rescue must not disguise it
        let spec = try Module(
            procedures: [
                "entry": Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            Parameter(name: "n", type: .int)
                        ]
                    ),
                    body: [
                        Statement(binding: .constant("fragile"), expression: .attempt([
                                        mayFail(),
                                        Statement(binding: .constant("spelled"), expression: interpolated(
                                                literal("x="),
                                                spelling(reference("n", "field"))
                                            )
                                        )
                                    ], rescue: [
                                        Statement(binding: .constant("recovery"), expression: .literal(.string("recovered")))
                                    ])
                        )
                    ]
                )
            ]
        )

        // When / Then. A rescue cannot disguise what the build already refused,
        // because there is no run for it to be part of
        await #expect {
            try await run(spec, arguments: ["n": .int(1)])
        } throws: { error in
            error is BuildError && "\(error)".contains("n.field names 'field', and Int has no name there to read")
        }
    }

    @Test("an entry the data does not carry reads as null where the author wrote ?[")
    func absentEntryReadsAsNullThroughOptional() async throws {
        // Given. `?[` expects absence: it answers null, nothing is thrown,
        // and the rescue never runs
        let spec = try Module(
            procedures: [
                "entry": Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            Parameter(name: "data", type: .dictionary(key: .string, value: .any))
                        ],
                        returns: .any
                    ),
                    body: [
                        Statement(binding: .variable("kept"), expression: .literal(.string("unread"))),
                        Statement(binding: .constant("fragile"), expression: .attempt([
                                        mayFail(),
                                        Statement(binding: .assignment([.name("kept")]), expression: .reference([.name("data"), .index("missing", optional: true)]))
                                    ], rescue: [
                                        Statement(binding: .assignment([.name("kept")]), expression: .literal(.string("recovered")))
                                    ])
                        ),
                        returning(map([
                                "result": .reference([.name("kept")])
                            ]))
                    ]
                )
            ]
        )

        // When
        let outputs = try await run(spec, arguments: ["data": .dictionary([:])])

        // Then
        #expect(outputs.map?["result"] == .null)
    }

    @Test("an entry the data does not carry refuses where nothing said it may be absent")
    func absentEntryWithoutOptionalIsUnfit() async throws {
        // Given. The plain bracket promises the entry is there, so an absent
        // one is a defect the run refuses rather than a null it invents
        let spec = try Module(
            procedures: [
                "entry": Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            Parameter(name: "data", type: .dictionary(key: .string, value: .any))
                        ],
                        returns: .any
                    ),
                    body: [returning(.reference([.name("data"), .index("missing")]))]
                )
            ]
        )

        // When / Then
        await #expect(throws: ReferenceUnfit.self) {
            try await run(spec, arguments: ["data": .dictionary([:])])
        }
    }

    @Test("interpolating a null spells null, and nothing is there for a rescue to absorb")
    func nullInsideTemplateSpellsNull() async throws {
        // Given. The arm this input skips leaves `maybe` null, and text spells
        // a null as `null`
        let spec = try Module(
            procedures: [
                "entry": Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            Parameter(name: "kind", type: .string)
                        ],
                        returns: .any
                    ),
                    body: [
                        Statement(binding: .variable("maybe"), expression: .literal(.null)),
                        Statement(
                            expression: .conditional(
                                equals(.reference([.name("kind")]), .literal(.string("a"))),
                                then: [
                                    Statement(binding: .assignment([.name("maybe")]), expression: .literal(.string("made")))
                                ],
                                else: nil
                            )
                        ),
                        Statement(binding: .variable("kept"), expression: .literal(.null)),
                        Statement(binding: .constant("fragile"), expression: .attempt([
                                        mayFail(),
                                        Statement(binding: .assignment([.name("kept")]), expression: interpolated(
                                                literal("name="),
                                                spelling(reference("maybe"))
                                            )
                                        )
                                    ], rescue: [
                                        Statement(binding: .assignment([.name("kept")]), expression: .literal(.string("recovered")))
                                    ])
                        ),
                        returning(map([
                                "result": .reference([.name("kept")])
                            ]))
                    ]
                )
            ]
        )

        // When
        let outputs = try await run(spec, arguments: ["kind": .string("b")])

        // Then
        #expect(outputs.map?["result"] == .string("name=null"))
    }

    @Test("abort throws carrying its rendered message")
    func abortThrowsWithMessage() async throws {
        // Given
        let spec = try Module(
            procedures: [
                "entry": Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            Parameter(name: "reason", type: .string)
                        ],
                        failing: .these(["aborted"])
                    ),
                    body: [
                        // Nameless on purpose. A statement that never finishes
                        // binds nothing, so a name on it is refused at the build.
                        Statement(
                            expression: aborting(interpolated(
                                        literal("stopped: "),
                                        spelling(reference("reason"))
                                    ))
                        )
                    ]
                )
            ]
        )

        // When / Then. Abort is the language's throw, and carries its message
        await #expect {
            try await run(spec, arguments: ["reason": .string("no data")])
        } throws: { error in
            (error as? Aborted)?.message == "stopped: no data"
        }
    }

    @Test("abort is caught by rescue like any thrown error")
    func abortRescuesLikeThrownError() async throws {
        // Given. Like a thrown error, abort is catchable
        let spec = try Module(
            procedures: [
                "entry": Procedure(
                    access: .public,
                    signature: Signature(returns: .any),
                    body: [
                        Statement(binding: .variable("kept"), expression: .literal(.null)),
                        Statement(binding: .constant("bail"), expression: .attempt([
                                        Statement(
                                            expression: aborting(literal("giving up"))
                                        )
                                    ], rescue: [
                                        Statement(binding: .assignment([.name("kept")]), expression: .literal(.string("recovered")))
                                    ])
                        ),
                        returning(map([
                                "result": .reference([.name("kept")])
                            ]))
                    ]
                )
            ]
        )

        // When
        let outputs = try await run(spec)

        // Then
        #expect(outputs.map?["result"] == .string("recovered"))
    }

    // MARK: - Public
    // MARK: - Private
}
