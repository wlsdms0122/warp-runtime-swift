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
                        Statement(binding: .assignment([.name("held")]), expression: .literal(.string("no")))
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

    @Test("a struct literal written through a field without var is refused for the field")
    func aLiteralWrittenThroughAFixedFieldIsRefusedForTheField() async throws {
        // Given. `p` declares the struct the literal would be read as, and
        // not `var`, so the path is what stops the write
        let sut = try Module(
            types: [
                "App.A": .struct(["k": .string]),
                "App.W": .struct(["p": .named("App.A")])
            ],
            procedures: [
                entryName: Procedure(
                    access: .public,
                    body: [
                        Statement(
                            binding: .variable("w", declared: .named("App.W")),
                            expression: .struct(["p": .struct(["k": .literal(.string("x"))])])
                        ),
                        Statement(
                            binding: .assignment([.name("w"), .name("p")]),
                            expression: .struct(["k": .literal(.string("y"))])
                        )
                    ],
                    result: reference("w")
                )
            ]
        )

        // When / Then
        await #expect {
            try await Builder().build([sut] + Module.standard)
        } throws: { error in
            "\(error)".contains("w.p writes through 'p', which the type declares without `var`")
        }
    }

    @Test("what a name says it holds is what the run puts in it")
    func aDeclarationHoldsTheValue() async throws {
        // Given. The value is a whole number and the name says it holds a
        // fraction. A declaration is held like a parameter's, so what it
        // holds is the declared type
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(returns: .double),
                    body: [
                        Statement(binding: .constant("held", declared: .double), expression: .literal(.int(1)))
                    ],
                    result: reference("held")
                )
            ]
        )

        // When
        let answer = try await Executor().run(try Builder().build([sut] + Module.standard))

        // Then
        #expect(answer == .double(1))
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
        // Given. An `inout` slot takes the type the name says it holds, so
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
                                Call(selector: "swap", arguments: [.reference([.name("step")])])
                            )
                        )
                    ],
                    result: .apply(reference("step"), arguments: [.literal(.int(2))])
                ),
                "swap": Procedure(
                    signature: Signature(parameters: [Parameter(name: "step", type: .inout(.procedure(takes.type)))]),
                    body: [
                        Statement(
                            binding: .assignment([.name("step")]),
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
    func aClosureUnderANameSayingNothingDoesNotFitTheSlot() async throws {
        // Given. The same program with the declaration left off, and a literal
        // declaring const and isolated, which the name now is, while the slot
        // asks for the plain procedure type
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(returns: .int, failing: .anything),
                    body: [
                        Statement(
                            binding: .variable("step"),
                            expression: .closure(Procedure(
                                signature: Signature(
                                    parameters: takes.parameters,
                                    returns: takes.returns,
                                    constness: .const,
                                    isolation: .isolated
                                ),
                                body: [],
                                result: reference("x")
                            ))
                        ),
                        Statement(
                            expression: .call(
                                Call(selector: "swap", arguments: [.reference([.name("step")])])
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
                && "\(error)".contains("which holds const isolated (Int) -> Int where inout (Int) -> Int is declared")
        }
    }

    @Test("a closure's signature is held to the same judgement as a declaration")
    func aClosureSignatureIsJudgedAtTheBuild() async throws {
        // Given. Unreached code still has to compile, and a signature written
        // inline is a declaration however deep a body buries it
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(),
                    body: [
                        Statement(binding: .constant("kept"), expression: .closure(Procedure(
                                signature: Signature(
                                    parameters: [
                                        Parameter(name: "it", type: .named("Nope"))
                                    ]
                                ),
                                body: [],
                                result: reference("it")
                            ))
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
            error is BuildError && "\(error)".contains("names type 'Nope', which no module in this link declares")
        }
    }

    // MARK: - Public
    // MARK: - Private
}
