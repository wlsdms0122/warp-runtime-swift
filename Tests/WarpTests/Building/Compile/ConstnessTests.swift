//
//  ConstnessTests.swift
//  WarpTests
//
//  Created by JSilver on 9/16/26.
//

import Foundation
import Testing
@testable import Warp
import WarpStandard
import WarpTestSupport

// What being const holds a body to.
//
// A declaration says it is const, and the build holds its body to that. The
// line is what a body reaches, not what it is written with. A branch, a round
// and a name of its own all stay inside the body, so what a body holding them
// returns comes from what it was handed. Reaching the run's own state does
// not, and neither does calling a value nothing said the constness of.
@Suite("What is const")
struct ConstnessTests {
    // MARK: - Property
    // A declaration whose slot asks for a body that is const,
    // so what fits here is exactly what a closure declared const may do.
    private let asking = Procedure(
        signature: Signature(
            parameters: [Parameter(name: "body", type: .procedure(ProcedureType(returns: .string, failing: .these([])), .const))],
            returns: .string
        ),
        body: [
            Statement(binding: .constant("answered"), expression: .apply(reference("body"), arguments: [])),
            returning(reference("answered"))
        ]
    )

    // What every closure handed to `asking` declares.
    private let constSignature = Signature(returns: .string, constness: .const)

    // MARK: - Initializer
    // MARK: - Test
    @Test("a body that branches may be const")
    func aBranchingBodyIsConst() async throws {
        // Given. A branch that returns from one arm and falls through to the
        // other. Nothing in it reaches past the body.
        let branching = Procedure(
            signature: constSignature,
            body: [
                Statement(expression: .conditional(
                    .literal(.bool(true)),
                    then: [Statement(expression: .leave(.procedure(.literal(.string("taken")))))],
                    else: nil
                )),
                returning(.literal(.string("fell through")))
            ]
        )

        // When
        let returned = try await run(try module(handing: branching))

        // Then
        #expect(returned == .string("taken"))
    }

    @Test("a body that loops may be const")
    func aLoopingBodyIsConst() async throws {
        // Given. A round counted out and left from. A loop is grammar, and
        // grammar reaches nothing.
        let looping = Procedure(
            signature: constSignature,
            body: [
                Statement(expression: .loop(
                    while: .literal(.bool(true)),
                    body: [
                        Statement(expression: .leave(.procedure(.literal(.string("counted")))))
                    ]
                )),
                returning(.literal(.string("never reached")))
            ]
        )

        // When
        let returned = try await run(try module(handing: looping))

        // Then
        #expect(returned == .string("counted"))
    }

    @Test("a body that binds a variable of its own may be const")
    func aBodyBindingAVariableIsConst() async throws {
        // Given. A name the body declares and writes. It is the body's own, so
        // nothing outside the body can tell it happened.
        let writing = Procedure(
            signature: constSignature,
            body: [
                Statement(binding: .variable("held"), expression: .literal(.string("first"))),
                Statement(binding: .assignment([.name("held")]), expression: .literal(.string("second"))),
                returning(reference("held"))
            ]
        )

        // When
        let returned = try await run(try module(handing: writing))

        // Then
        #expect(returned == .string("second"))
    }

    @Test("a closure declared const reaching the module's own state refuses")
    func aBodyReadingAModuleVariableIsRefused() async throws {
        // Given. The same shape, reading a name the module holds rather than
        // one the body declared. What that returns is the run's, not the text's.
        let reading = Procedure(signature: constSignature, body: [returning(reference("standing"))])
        let handed = try Module(
            variables: ["standing": .literal(.string("held"))],
            procedures: [
                "asking": asking,
                entryName: Procedure(
                    access: .public,
                    signature: Signature(returns: .string),
                    body: [
                        Statement(binding: .constant("given"), expression: .closure(reading)),
                        returning(.call(Call(selector: "asking", arguments: [reference("given")])))
                    ]
                )
            ]
        )

        // When / Then
        await #expect {
            try await Builder().build([handed] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("declared const, and it reads the module variable 'standing'")
        }
    }

    @Test("a closure declared const writing a variable it captured refuses")
    func aClosureWritingACapturedVariableIsRefused() async throws {
        // Given. A closure that writes a variable the body around it declared.
        // The box is outside the closure, so the write reaches the run's state.
        let writing = Procedure(
            signature: constSignature,
            body: [
                Statement(binding: .assignment([.name("tally")]), expression: .literal(.int(1))),
                returning(.literal(.string("written")))
            ]
        )
        let handed = try Module(
            procedures: [
                "asking": asking,
                entryName: Procedure(
                    access: .public,
                    signature: Signature(returns: .string),
                    body: [
                        Statement(binding: .variable("tally"), expression: .literal(.int(0))),
                        Statement(binding: .constant("given"), expression: .closure(writing)),
                        returning(.call(Call(selector: "asking", arguments: [reference("given")])))
                    ]
                )
            ]
        )

        // When / Then
        await #expect {
            try await Builder().build([handed] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("declared const, and it writes 'tally', which it does not declare")
        }
    }

    @Test("a declaration writing through a parameter handed in place cannot be const, and a closure sending it cannot")
    func aBodyWritingInPlaceIsRefused() async throws {
        // Given. A declaration writing its in-place parameter, and a closure
        // handing a variable of its own to it. The parameter is the caller's
        // box, so the declaration runs, and the closure sends what runs.
        let bumping = Procedure(
            signature: Signature(parameters: [Parameter(name: "count", type: .inout(.int))]),
            body: [Statement(binding: .assignment([.name("count")]), expression: .literal(.int(1)))]
        )
        let sending = Procedure(
            signature: constSignature,
            body: [
                Statement(binding: .variable("own"), expression: .literal(.int(0))),
                Statement(expression: .call(Call(selector: "bumping", arguments: [reference("own")]))),
                returning(.literal(.string("sent")))
            ]
        )
        let handed = try Module(
            procedures: [
                "asking": asking,
                "bumping": bumping,
                entryName: Procedure(
                    access: .public,
                    signature: Signature(returns: .string),
                    body: [
                        Statement(binding: .constant("given"), expression: .closure(sending)),
                        returning(.call(Call(selector: "asking", arguments: [reference("given")])))
                    ]
                )
            ]
        )

        // When / Then
        await #expect {
            try await Builder().build([handed] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("declared const, and it calls 'bumping', which is not declared const")
        }
    }

    @Test("a body declared const writing through a parameter handed in place refuses")
    func aConstBodyWritingInPlaceRefuses() async throws {
        // Given. The parameter is the caller's box, whatever the declaration
        // says of itself
        let bumping = Procedure(
            signature: Signature(parameters: [Parameter(name: "count", type: .inout(.int))], constness: .const),
            body: [Statement(binding: .assignment([.name("count")]), expression: .literal(.int(1)))]
        )
        let handed = try Module(
            procedures: [
                "bumping": bumping,
                entryName: Procedure(access: .public, body: [])
            ]
        )

        // When / Then
        await #expect {
            try await Builder().build([handed] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("declared const, and it writes 'count', which it does not declare")
        }
    }

    @Test("a body applying a name a slot said holds a const Procedure may itself be const")
    func aBodyApplyingAConstProcedureSlotIsConst() async throws {
        // Given. `asking` applies what it was handed, and its slot asks for a
        // procedure that is const, and says so of itself. A
        // closure calling `asking` may therefore be const too, and standing in
        // that same slot is where that is asked.
        let handed = try Module(
            procedures: [
                "asking": Procedure(
                    signature: Signature(
                        parameters: asking.signature.parameters,
                        returns: .string,
                        constness: .const
                    ),
                    implementation: asking.implementation
                ),
                entryName: Procedure(
                    access: .public,
                    signature: Signature(returns: .string),
                    body: [
                        Statement(
                            binding: .constant("answering"),
                            expression: .closure(Procedure(signature: constSignature, body: [returning(.literal(.string("answered")))]))
                        ),
                        Statement(
                            binding: .constant("relaying"),
                            expression: .closure(
                                Procedure(
                                    signature: constSignature,
                                    body: [
                                        returning(.call(
                                            Call(selector: "asking", arguments: [reference("answering")])
                                        ))
                                    ]
                                )
                            )
                        ),
                        returning(.call(Call(selector: "asking", arguments: [reference("relaying")])))
                    ]
                )
            ]
        )

        // When
        let returned = try await run(handed)

        // Then
        #expect(returned == .string("answered"))
    }

    @Test("a variable declared to hold a const Procedure carries that into a closure that captured it")
    func aDeclaredVariableCarriesItsClaimIntoACapture() async throws {
        // Given. The variable says what it holds, so every write into it is
        // held to that, and a closure capturing it applies what the
        // declaration said
        let handed = try Module(
            procedures: [
                "asking": asking,
                entryName: Procedure(
                    access: .public,
                    signature: Signature(returns: .string),
                    body: [
                        Statement(
                            binding: .variable(
                                "answering",
                                declared: .procedure(ProcedureType(returns: .string, failing: .these([])), .const)
                            ),
                            expression: .closure(Procedure(signature: constSignature, body: [returning(.literal(.string("answered")))]))
                        ),
                        Statement(
                            binding: .constant("relaying"),
                            expression: .closure(
                                Procedure(signature: constSignature, body: [returning(.apply(reference("answering"), arguments: []))])
                            )
                        ),
                        returning(.call(Call(selector: "asking", arguments: [reference("relaying")])))
                    ]
                )
            ]
        )

        // When
        let returned = try await run(handed)

        // Then
        #expect(returned == .string("answered"))
    }

    @Test("a variable that may be retyped says nothing a closure that captured it can apply as const")
    func aRetypableVariableCarriesNoClaimIntoACapture() async throws {
        // Given. The same capture, of a variable that declared nothing. A
        // write after the capture may put any procedure in it
        let handed = try Module(
            procedures: [
                "asking": asking,
                entryName: Procedure(
                    access: .public,
                    signature: Signature(returns: .string),
                    body: [
                        Statement(
                            binding: .variable("answering"),
                            expression: .closure(Procedure(signature: constSignature, body: [returning(.literal(.string("answered")))]))
                        ),
                        Statement(
                            binding: .constant("relaying"),
                            expression: .closure(
                                Procedure(signature: constSignature, body: [returning(.apply(reference("answering"), arguments: []))])
                            )
                        ),
                        returning(.call(Call(selector: "asking", arguments: [reference("relaying")])))
                    ]
                )
            ]
        )

        // When / Then
        await #expect {
            try await Builder().build([handed] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("declared const, and it calls a value nothing written says is const")
        }
    }

    @Test("a body applying a name no slot said anything about cannot be const")
    func aBodyApplyingAnUndeclaredNameIsRefused() async throws {
        // Given. The same apply, on a name whose slot says what the procedure
        // returns and nothing of whether it runs. Nothing before the run says
        // which procedure that holds.
        let relaying = Procedure(
            signature: Signature(
                parameters: [Parameter(name: "body", type: .procedure(ProcedureType(returns: .string, failing: .these([]))))],
                returns: .string,
                constness: .const
            ),
            body: [returning(.apply(reference("body"), arguments: []))]
        )
        let handed = try Module(
            procedures: [
                "relaying": relaying,
                entryName: Procedure(access: .public, body: [])
            ]
        )

        // When / Then
        await #expect {
            try await Builder().build([handed] + Module.standard)
        } throws: { error in
            error is BuildError
                && "\(error)".contains("'relaying' is declared const, and it calls a value nothing written says is const")
        }
    }

    @Test("what is const is declared, not worked out at the build")
    func constnessIsDeclared() async throws {
        // Given. `clean` computes and says nothing of itself; `dirty` reaches
        // an effect
        let sut = try Module(
            procedures: [
                "clean": Procedure(
                    body: [
                        Statement(binding: .constant("done"), expression: .literal(.int(1)))
                    ]
                ),
                "dirty": Procedure(
                    signature: Signature(failing: .anything),
                    body: [
                        Statement(binding: .constant("done"), expression: .call(Call(
                            selector: "App.fail",
                            arguments: [.literal(.bool(true))]
                        )))
                    ]
                ),
                "entry": Procedure(
                    access: .public,
                    signature: Signature(failing: .anything),
                    body: [
                        Statement(binding: .constant("a"), expression: .call(Call(selector: "clean"))),
                        Statement(binding: .constant("b"), expression: .call(Call(selector: "dirty")))
                    ]
                )
            ]
        )

        // When
        let image = try await Builder().build([sut] + Module.standard + [.failing])

        // Then. Nothing here is const but what its declaration says is
        #expect(image["clean"]?.signature.constness == .unstated)
        #expect(image["dirty"]?.signature.constness == .unstated)
        #expect(image["entry"]?.signature.constness == .unstated)
        #expect(image["String.count"]?.signature.constness == .const)
    }

    @Test("a body declared const that sends a const procedure builds")
    func aBodyThatSendsIsStillConst() async throws {
        // Given. `label` sends `joined`, which is declared const
        let label = Procedure(
            signature: Signature(
                parameters: [Parameter(name: "of", type: .array(.string))],
                returns: .string,
                constness: .const
            ),
            body: [returning(.call(Call(selector: "Standard.Text.joined", arguments: [reference("of"), .literal(.string(""))])))]
        )
        let sut = try Module(
            procedures: [
                "label": label,
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [Parameter(name: "names", type: .array(.string))],
                        returns: .string
                    ),
                    body: [returning(.call(Call(selector: "label", arguments: [reference("names")])))]
                )
            ]
        )

        // When
        let image = try await Builder().build([sut] + Module.standard)

        // Then
        #expect(image["label"]?.signature.constness == .const)
    }

    // MARK: - Public
    // MARK: - Private
    // The declaration above, handed the body under test.
    private func module(handing body: Procedure) throws -> Module {
        try Module(
            procedures: [
                "asking": asking,
                entryName: Procedure(
                    access: .public,
                    signature: Signature(returns: .string),
                    body: [
                        Statement(binding: .constant("given"), expression: .closure(body)),
                        returning(.call(Call(selector: "asking", arguments: [reference("given")])))
                    ]
                )
            ]
        )
    }
}
