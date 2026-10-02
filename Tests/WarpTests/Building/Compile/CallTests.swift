//
//  CallTests.swift
//  WarpTests
//
//  Created by JSilver on 8/17/26.
//

import Foundation
import Testing
@testable import Warp
import WarpStandard
import WarpTestSupport

// A procedure, a library procedure and a host's own are one expression, and
// the only difference is where the selector was found. These ask the language
// that directly, without a notation in between to spell the three differently.
@Suite("A call")
struct CallTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("a library procedure, a native procedure and a procedure are sent the same way")
    func threeKindsOfProcedureAreOneExpression() async throws {
        // Given
        let echo = Procedure(
            signature: Signature(
                parameters: [Parameter(name: "text", type: .string)],
                returns: .record(["said": .string])
            ),
            body: [],
            result: .record(["said": reference("text")])
        )
        let sut: Body = [
            Statement(binding: .constant("counted"), expression: .call(
                Call(selector: "std.collection.count", arguments: [.array([.literal(.int(1)), .literal(.int(2))])])
            )),
            Statement(binding: .constant("shouted"), expression: .call(
                Call(selector: "app.shout", arguments: [.literal(.string("hi"))])
            )),
            Statement(binding: .constant("echoed"), expression: .call(
                Call(selector: "echo", arguments: [.literal(.string("back"))])
            ))
        ]

        // When
        let outputs = try await run(
            Procedure(
                body: sut,
                result: .record([
                    "counted": reference("counted"),
                    "shouted": reference("shouted"),
                    "echoed": reference("echoed", "said")
                ])
            ),
            beside: ["echo": echo],
            vocabulary: Module.standard + [.shouting]
        )

        // Then
        #expect(outputs["counted"] == .int(2))
        #expect(outputs["shouted"] == .string("HI"))
        #expect(outputs["echoed"] == .string("back"))
    }

    @Test("an argument outside what a procedure declares is refused at the build")
    func argumentOutsideTheDeclarationIsRefused() async throws {
        // Given. `count` declares `std.Collection`, and an int is no member
        let sut = Warp.Expression.call(
            Call(selector: "std.collection.count", arguments: [.literal(.int(7))])
        )

        // When / Then
        await #expect {
            try await answer(
                of: [Statement(binding: .constant("probe"), expression: sut)],
                result: reference("probe")
            )
        } throws: { error in
            error is BuildError && "\(error)".contains("'collection' holds int, which 'std.Collection' does not admit")
        }
    }

    @Test("two declarations of one spelling are refused at the build")
    func oneNameIsDeclaredOnce() async throws {
        // Given. Which one runs must never be an accident of the link's order,
        // and an implementation is not a spelling: a body and a native
        // answering one name collide the same way two bodies would
        let rival = try Module(
            procedures: [
                "std.collection.count": Procedure(
                    signature: Signature(returns: .int),
                    implementation: .query(TicketQuery())
                )
            ]
        )

        // When / Then
        await #expect {
            try await Builder().build(
                [try Module(procedures: ["entry": Procedure(access: .public, body: [])]), rival] + Module.standard
            )
        } throws: { error in
            error is BuildError && "\(error)".contains("'std.collection.count' is declared more than once in this link")
        }
    }

    @Test("a call to a native procedure is judged against its signature like any call")
    func hostProcedureIsCheckedAgainstItsSignature() async throws {
        // Given. One argument more than the procedure declares.
        let sut = Procedure(
            body: [
                Statement(binding: .constant("shouted"), expression: .call(
                        Call(
                            selector: "app.shout",
                            arguments: [
                                .literal(.string("hi")),
                                .literal(.int(11))
                            ]
                        )
                    )
                )
            ]
        )

        // When / Then
        await #expect {
            try await run(sut, vocabulary: Module.standard + [.shouting])
        } throws: { error in
            error is BuildError && "\(error)".contains("sending 'app.shout' with 2 arguments, and it takes 1")
        }
    }

    @Test("a required argument nobody passed is refused before the run")
    func missingRequiredArgumentRefused() async throws {
        // Given
        let sut = Procedure(
            body: [
                Statement(binding: .constant("shouted"), expression: .call(Call(selector: "app.shout")))
            ]
        )

        // When / Then
        await #expect {
            try await run(sut, vocabulary: Module.standard + [.shouting])
        } throws: { error in
            error is BuildError && "\(error)".contains("sending 'app.shout' with 0 arguments, and it takes 1")
        }
    }

    @Test("a constant argument of the wrong type is refused before the run")
    func constantArgumentTypeRefused() async throws {
        // Given. Only arguments that already are what they will be can be
        // judged here, and a constant is one
        let sut = Procedure(
            body: [
                Statement(binding: .constant("shouted"), expression: .call(
                    Call(selector: "app.shout", arguments: [.literal(.int(7))])
                ))
            ]
        )

        // When / Then
        await #expect {
            try await run(sut, vocabulary: Module.standard + [.shouting])
        } throws: { error in
            error is BuildError && "\(error)".contains("sending 'app.shout': input 'text': expected string, got int")
        }
    }

    @Test("a selector nothing answers is refused before the run")
    func unresolvedSelectorRefused() async throws {
        // Given. A self-contained procedure that calls something should be told
        // it had nowhere to look, rather than handed an empty answer
        let sut = Procedure(
            body: [Statement(binding: .constant("gone"), expression: .call(Call(selector: "nowhere")))]
        )

        // When / Then
        await #expect {
            try await run(sut)
        } throws: { error in
            error is BuildError && "\(error)".contains("sends 'nowhere', which no module in this link declares")
        }
    }

    @Test("a call to another document's private declaration is refused as private, at the call")
    func aCallToAPrivateDeclarationIsRefusedAsPrivate() async throws {
        // Given. `lib` declares `lib.hidden` privately, and `app` calls it
        let lib = try Module(procedures: [
            "lib.hidden": Procedure(access: .private, signature: Signature(returns: .int), body: [], result: .literal(.int(7)))
        ])
        let app = try Module(procedures: [
            "entry": Procedure(access: .public, signature: Signature(returns: .int), body: [], result: .call(Call(selector: "lib.hidden")))
        ])

        // When
        let refusal = await #expect(throws: BuildError.self) {
            try await Builder().build([lib, app] + Module.standard)
        }

        // Then
        #expect(refusal?.message == BuildError.concealed("lib.hidden", at: Place(in: Place.Document(identity: nil))).message)
        #expect(refusal?.place?.rendered == "procedures.entry.result")
    }

    @Test("a typo in an arm today's arguments never take is still refused")
    func unreachedArmIsStillResolved() async throws {
        // Given. The warrant is compilation, not loading: a run with expensive
        // effects should not discover a typo halfway through
        let sut = Procedure(
            body: [
                Statement(
                    expression: .conditional(
                        .literal(.bool(false)),
                        then: [
                            Statement(binding: .constant("gone"), expression: .call(Call(selector: "nowhere")))
                        ],
                        else: nil
                    )
                )
            ]
        )

        // When / Then
        await #expect {
            try await run(sut)
        } throws: { error in
            error is BuildError && "\(error)".contains("sends 'nowhere', which no module in this link declares")
        }
    }

    @Test("a procedure calling itself builds once instead of forever")
    func recursiveProcedureBuildsOnce() async throws {
        // Given
        let countdown = Procedure(
            signature: Signature(
                parameters: [Parameter(name: "n", type: .int)],
                returns: .record(["done": .bool])
            ),
            body: [
                Statement(
                    expression: .conditional(
                        differs(reference("n"), .literal(.int(0))),
                        then: [
                            Statement(binding: .constant("recur"), expression: .call(
                                Call(selector: "countdown", arguments: [.literal(.int(0))])
                            ))
                        ],
                        else: nil
                    )
                )
            ],
            result: .record(["done": .literal(.bool(true))])
        )
        let sut = Procedure(
            body: [
                Statement(binding: .constant("run"), expression: .call(
                    Call(selector: "countdown", arguments: [.literal(.int(1))])
                ))
            ],
            result: .record(["done": reference("run", "done")])
        )

        // When
        let outputs = try await run(sut, beside: ["countdown": countdown])

        // Then
        #expect(outputs["done"] == .bool(true))
    }

    @Test("an argument past the callee's parameters is refused")
    func argumentPastTheParametersIsRefused() async throws {
        // Given
        let sut = try Module(
            procedures: [
                "callee": Procedure(
                    signature: Signature(
                        parameters: [
                            Parameter(name: "base", type: .int)
                        ]
                    ),
                    body: [
                        Statement(binding: .constant("echo"), expression: .reference([.key("base")]))
                    ]
                ),
                "caller": Procedure(
                    access: .public,
                    body: [
                        Statement(binding: .constant("call"), expression: .call(Call(selector: "callee", arguments: [
                                        .literal(.int(1)),
                                        .literal(.int(2))
                                    ]))
                        )
                    ]
                )
            ]
        )

        // When / Then
        await #expect {
            try await Builder().build([sut])
        } throws: { error in
            error is BuildError && "\(error)".contains("sending 'callee' with 2 arguments, and it takes 1")
        }
    }

    @Test("a required argument nobody passes is refused")
    func missingRequiredArgumentIsRefused() async throws {
        // Given
        let sut = try Module(
            procedures: [
                "callee": Procedure(
                    signature: Signature(
                        parameters: [
                            Parameter(name: "base", type: .int)
                        ]
                    ),
                    body: [
                        Statement(binding: .constant("echo"), expression: .reference([.key("base")]))
                    ]
                ),
                "caller": Procedure(
                    access: .public,
                    body: [
                        Statement(binding: .constant("call"), expression: .call(Call(selector: "callee")))
                    ]
                )
            ]
        )

        // When / Then
        await #expect {
            try await Builder().build([sut])
        } throws: { error in
            error is BuildError && "\(error)".contains("sending 'callee' with 0 arguments, and it takes 1")
        }
    }

    @Test("an argument named rather than written is judged by what the name holds")
    func referenceArgumentIsJudged() async throws {
        // Given. The type is wrong, and both sides said so in their own text:
        // `text` was declared a string and `base` is declared an int
        let sut = try Module(
            procedures: [
                "callee": Procedure(
                    signature: Signature(
                        parameters: [
                            Parameter(name: "base", type: .int)
                        ]
                    ),
                    body: [
                        Statement(binding: .constant("echo"), expression: .reference([.key("base")]))
                    ]
                ),
                "caller": Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            Parameter(name: "text", type: .string)
                        ]
                    ),
                    body: [
                        Statement(binding: .constant("call"), expression: .call(Call(
                            selector: "callee",
                            arguments: [.reference([.key("text")])]
                        )))
                    ]
                )
            ]
        )

        // When / Then
        await #expect {
            try await Builder().build([sut])
        } throws: { error in
            error is BuildError
                && "\(error)".contains("sending 'callee' with base, which holds string where int is declared")
        }
    }

    @Test("more arguments than a procedure takes are refused")
    func moreArgumentsThanParametersAreRefused() async throws {
        // Given. `absolute` takes one parameter and the call writes two. The
        // second would stand at no position, neither read nor run, so the build
        // refuses the call
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(),
                    body: [],
                    result: .call(Call(
                        selector: "std.math.absolute",
                        arguments: [.literal(.int(1)), .literal(.string("x"))]
                    ))
                )
            ]
        )

        // When / Then
        await #expect {
            try await Builder().build([sut] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("sending 'std.math.absolute' with 2 arguments, and it takes 1")
        }
    }

    // MARK: - Public
    // MARK: - Private
}
