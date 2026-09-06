//
//  DeclaredNameTests.swift
//  Warp
//
//  Created by JSilver on 9/6/26.
//

import Foundation
import Testing
@testable import Warp
import WarpStandard

@Suite("A name that says what it holds")
struct DeclaredNameTests {
    // MARK: - Property
    private let takes = Signature(parameters: ["x": Parameter(type: .int)], returns: .int)

    // MARK: - Initializer
    // MARK: - Test
    @Test("a declaration stands where the link would have worked out something narrower")
    func aDeclarationStandsOverWhatWasWorkedOut() async throws {
        // Given. The value is an int, and the name says it holds a number
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    signature: Signature(returns: .double),
                    body: [
                        Statement(binding: .constant("held", declared: .double), expression: .literal(.int(1)))
                    ],
                    result: reference("held")
                )
            ]
        )

        // When
        let answer = try await Executor().run(try Linker().link([sut] + Module.standard, entry: entryName))

        // Then
        #expect(answer == .double(1))
    }

    @Test("a name is refused what its declaration does not take")
    func aDeclarationRefusesWhatItDoesNotTake() throws {
        // Given
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    body: [
                        Statement(binding: .constant("held", declared: .int), expression: .literal(.string("no")))
                    ],
                    result: reference("held")
                )
            ]
        )

        // When / Then
        #expect {
            try Linker().link([sut] + Module.standard, entry: entryName)
        } throws: { error in
            "\(error)".contains("holds int, and what it was given is string")
        }
    }

    @Test("a declaration naming a type nothing declares is refused")
    func aDeclarationNamingNothingIsRefused() throws {
        // Given
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    body: [
                        Statement(
                            binding: .constant("held", declared: .named("app.Missing")),
                            expression: .literal(.int(1))
                        )
                    ],
                    result: reference("held")
                )
            ]
        )

        // When / Then
        #expect(throws: (any Error).self) {
            try Linker().link([sut] + Module.standard, entry: entryName)
        }
    }

    @Test("a declaration is held where a body is read rather than where one is reached")
    func aDeclarationIsHeldInABodyNothingReaches() throws {
        // Given. A procedure that runs an effect, so it is not in the pure set,
        // and that nothing calls, so it is not on the frontier. Its text still
        // has to compile
        let sut = try Module(
            imports: ["std.control.abort"],
            procedures: [
                entryName: Procedure(body: [], result: .literal(.int(1))),
                "stray": Procedure(
                    body: [
                        Statement(
                            expression: .dispatch(
                                Dispatch(receiver: .literal(.string("x")), selector: "std.control.abort")
                            )
                        ),
                        Statement(
                            binding: .constant("held", declared: .named("app.Missing")),
                            expression: .literal(.int(1))
                        )
                    ],
                    result: .literal(.int(1))
                )
            ]
        )

        // When / Then
        #expect {
            try Linker().link([sut] + Module.standard, entry: entryName)
        } throws: { error in
            "\(error)".contains("app.Missing")
        }
    }

    @Test("a variable that says what it holds is held to it, and a write does not retype it")
    func aDeclaredVariableIsNotRetypedByAWrite() throws {
        // Given
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    body: [
                        Statement(binding: .variable("held", declared: .int), expression: .literal(.int(1))),
                        Statement(binding: .assignment([.key("held")]), expression: .literal(.string("no")))
                    ],
                    result: reference("held")
                )
            ]
        )

        // When / Then
        #expect {
            try Linker().link([sut] + Module.standard, entry: entryName)
        } throws: { error in
            "\(error)".contains("writes 'held' as string, and it holds int")
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
                    body: [
                        Statement(binding: .constant("held", declared: .double), expression: .literal(.int(1)))
                    ],
                    result: .record(["got": reference("held")])
                )
            ]
        )

        // When
        let answer = try await Executor().run(try Linker().link([sut] + Module.standard, entry: entryName))

        // Then
        #expect(answer == .record(Record(name: nil, ["got": .double(1)])))
    }

    @Test("a name declaring a range is refused a value outside it")
    func aDeclaredRangeRefusesWhatIsOutsideIt() async throws {
        // Given
        let sut = try Module(
            types: ["app.Byte": .ranged(.whole(from: 0, to: .through(255)))],
            procedures: [
                entryName: Procedure(
                    body: [
                        Statement(
                            binding: .constant("held", declared: .named("app.Byte")),
                            expression: .literal(.int(300))
                        )
                    ],
                    result: reference("held")
                )
            ]
        )
        let image = try Linker().link([sut] + Module.standard, entry: entryName)

        // When / Then
        await #expect {
            try await Executor().run(image)
        } throws: { error in
            "\(error)".contains("300 is outside")
        }
    }

    @Test("a construct that binds the name says what it holds, and the author does not")
    func aConstructBoundNameTakesNoDeclaration() throws {
        // Given. A walk binds the element under the statement's name
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    body: [
                        Statement(
                            binding: .constant("walk", declared: .int),
                            expression: .iteration(over: .array([.literal(.int(1))]), body: [], element: "walk")
                        )
                    ],
                    result: .literal(.int(1))
                )
            ]
        )

        // When / Then
        #expect {
            try Linker().link([sut] + Module.standard, entry: entryName)
        } throws: { error in
            "\(error)".contains("this construct binds the name")
        }
    }

    @Test("a name declaring a type parameter is refused, because no call fills a name")
    func aDeclaredTypeParameterIsRefused() throws {
        // Given
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    body: [
                        Statement(binding: .constant("held", declared: .parameter(name: "T")), expression: .literal(.int(1)))
                    ],
                    result: reference("held")
                )
            ]
        )

        // When / Then
        #expect(throws: (any Error).self) {
            try Linker().link([sut] + Module.standard, entry: entryName)
        }
    }

    @Test("a declaration inside a module variable is held the way one inside a procedure is")
    func aDeclarationInsideAModuleVariableIsHeld() throws {
        // Given
        let sut = try Module(
            variables: [
                "started": .closure(
                    Procedure(
                        body: [
                            Statement(
                                binding: .constant("inner", declared: .named("app.Missing")),
                                expression: .literal(.int(1))
                            )
                        ],
                        result: .literal(.int(1))
                    )
                )
            ],
            procedures: [entryName: Procedure(body: [], result: .literal(.int(1)))]
        )

        // When / Then
        #expect {
            try Linker().link([sut] + Module.standard, entry: entryName)
        } throws: { error in
            "\(error)".contains("app.Missing")
        }
    }

    @Test("a closure under a name that says what it holds is handed in place, and the word writes it back")
    func aDeclaredClosureIsHandedInPlace() async throws {
        // Given. The link derives `pure isolated` for a closure literal, and an
        // `inout` slot takes the same shape. The name says what it holds, so
        // what the slot asks and what the name is are one shape
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    signature: Signature(returns: .int),
                    body: [
                        Statement(
                            binding: .variable("step", declared: .procedure(takes)),
                            expression: .closure(Procedure(signature: takes, body: [], result: reference("x")))
                        ),
                        Statement(
                            expression: .dispatch(
                                Dispatch(selector: "swap", arguments: ["step": .reference([.key("step")])])
                            )
                        )
                    ],
                    result: .invoke(reference("step"), arguments: ["x": .literal(.int(2))])
                ),
                "swap": Procedure(
                    signature: Signature(parameters: ["step": Parameter(type: .inout(.procedure(takes)))]),
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
        let answer = try await Executor().run(try Linker().link([sut] + Module.standard, entry: entryName))

        // Then. The word wrote a closure of its own into the caller's name
        #expect(answer == .int(9))
    }

    @Test("a closure under a name that says nothing is refused by the slot it does not equal")
    func anUndeclaredClosureDoesNotFitTheSlot() throws {
        // Given. The same program with the declaration left off. The link works
        // out `pure isolated procedure` for the literal, and the slot asks for
        // `procedure`
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    signature: Signature(returns: .int),
                    body: [
                        Statement(
                            binding: .variable("step"),
                            expression: .closure(Procedure(signature: takes, body: [], result: reference("x")))
                        ),
                        Statement(
                            expression: .dispatch(
                                Dispatch(selector: "swap", arguments: ["step": .reference([.key("step")])])
                            )
                        )
                    ],
                    result: .invoke(reference("step"), arguments: ["x": .literal(.int(2))])
                ),
                "swap": Procedure(
                    signature: Signature(parameters: ["step": Parameter(type: .inout(.procedure(takes)))]),
                    body: []
                )
            ]
        )

        // When / Then
        #expect(throws: (any Error).self) {
            try Linker().link([sut] + Module.standard, entry: entryName)
        }
    }
}
