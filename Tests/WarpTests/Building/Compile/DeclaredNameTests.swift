//
//  DeclaredNameTests.swift
//  WarpTests
//
//  Created by JSilver on 9/6/26.
//

import Foundation
import Testing
@testable import Warp
import WarpStandard
import WarpTestSupport

@Suite("A name that says what it holds")
struct DeclaredNameTests {
    // MARK: - Property
    private let takes = Signature(parameters: [Parameter(name: "x", type: .int)], returns: .int)

    // MARK: - Initializer
    // MARK: - Test
    @Test("a name is refused what its declaration does not take")
    func aDeclarationRefusesWhatItDoesNotTake() async throws {
        // Given
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    body: [
                        Statement(binding: .constant("held", declared: .int), expression: .literal(.string("no")))
                    ],
                    result: reference("held")
                )
            ]
        )

        // When / Then
        await #expect {
            try await Builder().build([sut] + Module.standard)
        } throws: { error in
            "\(error)".contains("holds Int, and what it was given is String")
        }
    }

    @Test("a declaration naming a type nothing declares is refused")
    func aDeclarationNamingNothingIsRefused() async throws {
        // Given
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    body: [
                        Statement(
                            binding: .constant("held", declared: .named("App.Missing")),
                            expression: .literal(.int(1))
                        )
                    ],
                    result: reference("held")
                )
            ]
        )

        // When / Then
        await #expect {
            try await Builder().build([sut] + Module.standard)
        } throws: { error in
            error is BuildError
                && "\(error)".contains("names type 'App.Missing', which no module in this link declares")
        }
    }

    @Test("a declaration is held where a body is read rather than where one is reached")
    func aDeclarationIsHeldInABodyNothingReaches() async throws {
        // Given. A procedure that runs an effect, so it is not in the const set,
        // and that nothing calls, so it is not on the frontier. Its text still
        // has to compile
        let sut = try Module(
            imports: ["App.Missing", "Standard.Control.abort"],
            procedures: [
                entryName: Procedure(access: .public, body: [], result: .literal(.int(1))),
                "stray": Procedure(
                    body: [
                        Statement(
                            expression: .call(
                                Call(selector: "Standard.Control.abort", arguments: [.literal(.string("x"))])
                            )
                        ),
                        Statement(
                            binding: .constant("held", declared: .named("App.Missing")),
                            expression: .literal(.int(1))
                        )
                    ],
                    result: .literal(.int(1))
                )
            ]
        )

        // When / Then
        await #expect {
            try await Builder().build([sut] + Module.standard)
        } throws: { error in
            "\(error)".contains("App.Missing")
        }
    }

    @Test("a variable that says what it holds is held to it, and a write does not retype it")
    func aDeclaredVariableIsNotRetypedByAWrite() async throws {
        // Given
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    body: [
                        Statement(binding: .variable("held", declared: .int), expression: .literal(.int(1))),
                        Statement(binding: .assignment([.key("held")]), expression: .literal(.string("no")))
                    ],
                    result: reference("held")
                )
            ]
        )

        // When / Then
        await #expect {
            try await Builder().build([sut] + Module.standard)
        } throws: { error in
            "\(error)".contains("writes 'held' as String, and it holds Int")
        }
    }

    @Test("what a name says it holds is what the run puts in it")
    func aDeclarationSettlesTheValue() async throws {
        // Given. The value is a whole number and the name says it holds a
        // fraction. A declaration is a boundary like a parameter's, so what
        // crosses it is settled
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    body: [
                        Statement(binding: .constant("held", declared: .double), expression: .literal(.int(1)))
                    ],
                    result: .record(["got": reference("held")])
                )
            ]
        )

        // When
        let answer = try await Executor().run(try Builder().build([sut] + Module.standard))

        // Then
        #expect(answer == .record(Record(name: nil, ["got": .double(1)])))
    }

    @Test("a construct that binds the name says what it holds, and the author does not")
    func aConstructBoundNameTakesNoDeclaration() throws {
        // Given. A loop binds the round under the statement's name
        let statement = Statement(
            binding: .constant("walk", declared: .int),
            expression: .loop(while: .literal(.bool(false)), body: Block(body: []))
        )

        // When / Then. Refused where the module is made
        #expect {
            try Module(
                procedures: [
                    entryName: Procedure(access: .public, body: [statement], result: .literal(.int(1)))
                ]
            )
        } throws: { error in
            error is ValidationError && "\(error)".contains("this construct binds the name")
        }
    }

    @Test("a block answering an attempt writes each way into the name on its own")
    func anAttemptABlockAnswersIsHeldEachWay() async throws {
        // Given. The body answers an int and the rescue a string, under a block the name starts with
        let attempt = Warp.Expression.attempt(
            Block(
                body: [
                    Statement(
                        expression: .conditional(
                            .literal(.bool(false)),
                            then: [Statement(expression: aborting(literal("stops")))],
                            else: nil
                        )
                    )
                ],
                result: .literal(.int(1))
            ),
            rescue: Block(body: [], result: .literal(.string("s")))
        )

        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    body: [
                        Statement(binding: .variable("x", declared: .int), expression: .block(Block(body: [], result: attempt)))
                    ],
                    result: reference("x")
                )
            ]
        )

        // When
        let refusal = await #expect(throws: BuildError.self) {
            try await Builder().build([sut] + Module.standard)
        }

        // Then
        #expect(refusal?.message == "holds Int, and what it was given is Int or String")
    }

    @Test("an attempt inside a list literal writes each way into the element on its own")
    func anAttemptInAListIsHeldEachWay() async throws {
        // Given. The list's one element is an attempt whose body answers an int and whose rescue a string
        let attempt = Warp.Expression.attempt(
            Block(
                body: [
                    Statement(
                        expression: .conditional(
                            .literal(.bool(false)),
                            then: [Statement(expression: aborting(literal("stops")))],
                            else: nil
                        )
                    )
                ],
                result: .literal(.int(1))
            ),
            rescue: Block(body: [], result: .literal(.string("s")))
        )
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    body: [
                        Statement(binding: .variable("xs", declared: .array(.int)), expression: .array([attempt]))
                    ],
                    result: reference("xs")
                )
            ]
        )

        // When
        let refusal = await #expect(throws: BuildError.self) {
            try await Builder().build([sut] + Module.standard)
        }

        // Then
        #expect(refusal?.message == "holds Array<Int>, and what it was given is [Int or String]")
    }

    @Test("a name declaring a type parameter is refused, because no call fills a name")
    func aDeclaredTypeParameterIsRefused() async throws {
        // Given
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    body: [
                        Statement(binding: .constant("held", declared: .parameter(name: "T")), expression: .literal(.int(1)))
                    ],
                    result: reference("held")
                )
            ]
        )

        // When / Then
        await #expect {
            try await Builder().build([sut] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("writes `some T`, and nothing here is filled by a call")
        }
    }

    @Test("a declaration inside a module variable is held the way one inside a procedure is")
    func aDeclarationInsideAModuleVariableIsHeld() async throws {
        // Given
        let sut = try Module(
            variables: [
                "started": .closure(
                    Procedure(
                        body: [
                            Statement(
                                binding: .constant("inner", declared: .named("App.Missing")),
                                expression: .literal(.int(1))
                            )
                        ],
                        result: .literal(.int(1))
                    )
                )
            ],
            procedures: [entryName: Procedure(access: .public, body: [], result: .literal(.int(1)))]
        )

        // When / Then
        await #expect {
            try await Builder().build([sut] + Module.standard)
        } throws: { error in
            "\(error)".contains("App.Missing")
        }
    }

    @Test("a closure under a name that says what it holds is handed in place, and the procedure writes it back")
    func aDeclaredClosureIsHandedInPlace() async throws {
        // Given. The build derives `const isolated` for a closure literal, and an
        // `inout` slot takes the same type. The name says what it holds, so
        // what the slot asks and what the name is are one type
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(returns: .int),
                    body: [
                        Statement(
                            binding: .variable("step", declared: .procedure(takes.type)),
                            expression: .closure(Procedure(signature: takes, body: [], result: reference("x")))
                        ),
                        Statement(
                            expression: .call(
                                Call(selector: "swap", arguments: [.reference([.key("step")])])
                            )
                        )
                    ],
                    result: .apply(reference("step"), arguments: [.literal(.int(2))])
                ),
                "swap": Procedure(
                    signature: Signature(parameters: [Parameter(name: "step", type: .inout(.procedure(takes.type)))]),
                    body: [
                        Statement(
                            binding: .assignment([.key("step")]),
                            expression: .closure(Procedure(signature: takes, body: [], result: .literal(.int(9))))
                        )
                    ]
                )
            ]
        )

        // When
        let answer = try await Executor().run(try Builder().build([sut] + Module.standard))

        // Then. The procedure wrote a closure of its own into the caller's name
        #expect(answer == .int(9))
    }

    @Test("a closure under a name that says nothing is refused by the slot it does not equal")
    func anUndeclaredClosureDoesNotFitTheSlot() async throws {
        // Given. The same program with the declaration left off. The build works
        // out `const isolated Procedure` for the literal, and the slot asks for
        // `Procedure`
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(returns: .int),
                    body: [
                        Statement(
                            binding: .variable("step"),
                            expression: .closure(Procedure(signature: takes, body: [], result: reference("x")))
                        ),
                        Statement(
                            expression: .call(
                                Call(selector: "swap", arguments: [.reference([.key("step")])])
                            )
                        )
                    ],
                    result: .apply(reference("step"), arguments: [.literal(.int(2))])
                ),
                "swap": Procedure(
                    signature: Signature(parameters: [Parameter(name: "step", type: .inout(.procedure(takes.type)))]),
                    body: []
                )
            ]
        )

        // When / Then
        await #expect {
            try await Builder().build([sut] + Module.standard)
        } throws: { error in
            error is BuildError
                && "\(error)".contains("which holds const isolated Procedure<(Int) -> Int> where inout Procedure<(Int) -> Int> is declared")
        }
    }

    // MARK: - Public
    // MARK: - Private
}
