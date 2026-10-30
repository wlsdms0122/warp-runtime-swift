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
                        Statement(binding: .constant("greeting"), expression: joined(literal("hello, "), spelling(reference("who")))),
                        Statement(binding: .constant("loud"), expression: joined(spelling(reference("greeting")), literal("!"))),
                        returning(dictionary([
                                "result": .reference([.name("loud")])
                            ]))
                    ]
                )
            ]
        )

        // When
        let outputs = try await run(spec, arguments: ["who": .string("spec")])

        // Then
        #expect(outputs.dictionaryValue?["result"] == .string("hello, spec!"))
    }

    @Test("a recoverable failure runs the catch path")
    func recoverableFailureRunsCatch() async throws {
        // Given
        let spec = try Module(
            procedures: [
                "entry": Procedure(
                    access: .public,
                    signature: Signature(returns: .any),
                    body: [
                        Statement(binding: .variable("kept"), expression: .literal(.null)),
                        Statement(binding: .constant("fragile"), expression: .try([
                                        Statement(binding: .constant("fragile"), expression: .call(Call(
                                            selector: "App.fail",
                                            arguments: [.literal(.bool(true))]
                                        )))
                                    ], catch: [
                                        Statement(binding: .assignment([.name("kept")]), expression: .literal(.string("recovered")))
                                    ])
                        ),
                        returning(dictionary([
                                "result": .reference([.name("kept")])
                            ]))
                    ]
                )
            ]
        )

        // When
        let outputs = try await run(spec, vocabulary: Module.standard + [.failing])

        // Then. What the catch wrote is there after the try
        #expect(outputs.dictionaryValue?["result"] == .string("recovered"))
    }

    @Test("the failure is a value inside the catch, and only there")
    func catchSeesFailurePayload() async throws {
        // Given
        let spec = try Module(
            constants: ["fragile": .literal(.string("before"))],
            procedures: [
                "entry": Procedure(
                    access: .public,
                    signature: Signature(returns: .any),
                    body: [
                        Statement(binding: .variable("reason"), expression: .literal(.null)),
                        Statement(binding: .constant("fragile"), expression: .try([
                                        Statement(binding: .constant("doomed"), expression: .call(Call(
                                            selector: "App.fail",
                                            arguments: [.literal(.bool(true))]
                                        )))
                                    ], catch: [
                                        Statement(binding: .assignment([.name("reason")]), expression: joined(
                                                literal("saw: "),
                                                spelling(reference("fragile", "message"))
                                            )
                                        )
                                    ])
                        ),
                        returning(dictionary([
                                "reason": .reference([.name("reason")]),
                                "after": .reference([.name("fragile")])
                            ]))
                    ]
                )
            ]
        )

        // When
        let outputs = try await run(spec, vocabulary: Module.standard + [.failing])

        // Then. Inside the catch, `fragile` was the failure payload; after it,
        // `fragile` is the name around the try, so the payload never leaks
        // past the catch
        #expect(outputs.dictionaryValue?["reason"] == .string("saw: the world did not cooperate"))
        #expect(outputs.dictionaryValue?["after"] == .string("before"))
    }

    @Test("an uncaught failure propagates")
    func uncaughtFailurePropagates() async throws {
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

    @Test("a reference typo is not disguised by catch")
    func referenceTypoBypassesCatch() async throws {
        // Given. Type misuse is an author error; catch must not disguise it
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
                        Statement(binding: .constant("fragile"), expression: .try([
                                        mayFail(),
                                        Statement(binding: .constant("spelled"), expression: joined(
                                                literal("x="),
                                                spelling(reference("n", "field"))
                                            )
                                        )
                                    ], catch: [
                                        Statement(binding: .constant("recovery"), expression: .literal(.string("recovered")))
                                    ])
                        )
                    ]
                )
            ]
        )

        // When / Then. A catch cannot disguise what the build already refused,
        // because there is no run for it to be part of
        await #expect {
            try await run(spec, arguments: ["n": .int(1)])
        } throws: { error in
            error is BuildError && "\(error)".contains("n.field names 'field', and Int has no name there to read")
        }
    }

    @Test("an entry the data does not carry reads as null where the author wrote ?[")
    func absentEntryReadsAsNullThroughOptional() async throws {
        // Given. `?[` expects absence: it returns null, nothing is thrown,
        // and the catch never runs
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
                        Statement(binding: .constant("fragile"), expression: .try([
                                        mayFail(),
                                        Statement(binding: .assignment([.name("kept")]), expression: .reference([.name("data"), .index("missing", optional: true)]))
                                    ], catch: [
                                        Statement(binding: .assignment([.name("kept")]), expression: .literal(.string("recovered")))
                                    ])
                        ),
                        returning(dictionary([
                                "result": .reference([.name("kept")])
                            ]))
                    ]
                )
            ]
        )

        // When
        let outputs = try await run(spec, arguments: ["data": .dictionary([:])])

        // Then
        #expect(outputs.dictionaryValue?["result"] == .null)
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

    @Test("joining a null spells null, and nothing is there for a catch to absorb")
    func nullJoinedIntoTextSpellsNull() async throws {
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
                        Statement(binding: .constant("fragile"), expression: .try([
                                        mayFail(),
                                        Statement(binding: .assignment([.name("kept")]), expression: joined(
                                                literal("name="),
                                                spelling(reference("maybe"))
                                            )
                                        )
                                    ], catch: [
                                        Statement(binding: .assignment([.name("kept")]), expression: .literal(.string("recovered")))
                                    ])
                        ),
                        returning(dictionary([
                                "result": .reference([.name("kept")])
                            ]))
                    ]
                )
            ]
        )

        // When
        let outputs = try await run(spec, arguments: ["kind": .string("b")])

        // Then
        #expect(outputs.dictionaryValue?["result"] == .string("name=null"))
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
                            expression: aborting(joined(
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

    @Test("abort is caught by catch like any thrown error")
    func abortIsCaughtLikeThrownError() async throws {
        // Given. Like a thrown error, abort is catchable
        let spec = try Module(
            procedures: [
                "entry": Procedure(
                    access: .public,
                    signature: Signature(returns: .any),
                    body: [
                        Statement(binding: .variable("kept"), expression: .literal(.null)),
                        Statement(binding: .constant("bail"), expression: .try([
                                        Statement(
                                            expression: aborting(literal("giving up"))
                                        )
                                    ], catch: [
                                        Statement(binding: .assignment([.name("kept")]), expression: .literal(.string("recovered")))
                                    ])
                        ),
                        returning(dictionary([
                                "result": .reference([.name("kept")])
                            ]))
                    ]
                )
            ]
        )

        // When
        let outputs = try await run(spec)

        // Then
        #expect(outputs.dictionaryValue?["result"] == .string("recovered"))
    }

    // MARK: - Public
    // MARK: - Private
}
