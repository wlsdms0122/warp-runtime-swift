//
//  BuilderTests.swift
//  WarpTests
//
//  Created by JSilver on 8/16/26.
//

import Foundation
import Testing
@testable import Warp
import WarpTestSupport

// Building, asked the way a host asks it: modules loaded from documents,
// handed over as a set.
@Suite("Building a set of modules")
struct BuilderTests {
    // MARK: - Property
    private let builder = Builder()

    // MARK: - Initializer
    // MARK: - Test
    @Test("a constant that cannot be settled says why, not that it is a cycle")
    func aRefusedConstantSaysWhy() async throws {
        // Given. `greeting` names nothing that is missing, so the only reason
        // it fails is its own: `dividedBy` refuses a zero divisor
        let sut = try Module(
            constants: [
                "greeting": .call(Call(
                    selector: "Standard.Numeric.dividedBy",
                    arguments: [.literal(.int(1)), .literal(.int(0))]
                ))
            ],
            procedures: [entryName: Procedure(access: .public, body: [])]
        )

        // When / Then
        let error = await #expect(throws: BuildError.self) {
            try await builder.build([sut] + Module.standard)
        }

        #expect(error?.place?.rendered == "constants.greeting")
        #expect(
            error?.message.contains("names it back") == false,
            "a refusal of its own was reported as a cycle"
        )
    }

    @Test("a closure constant reads a constant beside it whatever the two are called")
    func aClosureConstantCapturesItsSiblings() async throws {
        // Given. Making a closure freezes the scope it was made in, so a
        // sibling its body reads has to be settled by then. Nothing in the body
        // runs while the constants settle, which is what makes it look like no
        // dependency at all, and read that way, what the closure captures is
        // whatever happened to be settled when its turn came round.
        //
        // Both spellings of one program, differing only in whether the closure
        // sorts before or after what it reads. An answer that is not the same
        // twice is a program whose meaning is in its names.
        func module(closure: Name, reading constant: Name) throws -> Module {
            try Module(
                constants: [
                    closure: .closure(Procedure(signature: Signature(returns: .int, failing: .anything), body: [], result: reference(constant))),
                    constant: .literal(.int(3))
                ],
                procedures: [
                    entryName: Procedure(
                        access: .public,
                        signature: Signature(returns: .int, failing: .anything),
                        body: [
                            Statement(binding: .constant("got"), expression: .apply(reference(closure), arguments: []))
                        ],
                        result: reference("got")
                    )
                ]
            )
        }

        // When
        let first = try await run(module(closure: "apply", reading: "zebra"), entry: entryName)
        let last = try await run(module(closure: "zapply", reading: "alpha"), entry: entryName)

        // Then
        #expect(first == .int(3))
        #expect(last == .int(3))
    }

    @Test("a closure reading a constant from inside an arm still has it")
    func aClosureReadsASiblingFromInsideAnArm() async throws {
        // Given. How deep in the closure the name is read makes no difference
        // to when it has to be settled: the capture happens once, when the
        // closure is made. The spelling puts the closure first in name order,
        // which is the order it would settle in if nothing said otherwise.
        let sut = try Module(
            constants: [
                "apply": .closure(Procedure(
                    signature: Signature(returns: .int),
                    body: [
                        Statement(binding: .variable("got"), expression: .literal(.int(0))),
                        Statement(expression: .conditional(
                            .literal(.bool(true)),
                            then: [Statement(binding: .assignment([.name("got")]), expression: reference("zebra"))],
                            else: nil
                        ))
                    ],
                    result: reference("got")
                )),
                "zebra": .literal(.int(7))
            ],
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(returns: .int, failing: .anything),
                    body: [
                        Statement(binding: .constant("got"), expression: .apply(reference("apply"), arguments: []))
                    ],
                    result: reference("got")
                )
            ]
        )

        // When
        let answer = try await run(sut, entry: entryName)

        // Then
        #expect(answer == .int(7))
    }

    @Test("a closure a constant holds inside a struct reads the constants beside it")
    func aClosureInsideAStructCapturesItsSiblings() async throws {
        // Given. What captures is the closure and not the constant holding it,
        // so a closure nested in a struct has the same demand on the order as
        // one written on its own.
        let sut = try Module(
            types: ["App.Runner": .struct(["run": .procedure(ProcedureType(returns: .int, failing: .anything))])],
            constants: [
                "apply": .cast(
                    .struct([
                        "run": .closure(Procedure(
                            signature: Signature(returns: .int),
                            body: [],
                            result: reference("zebra")
                        ))
                    ]),
                    as: .named("App.Runner"),
                    optional: false
                ),
                "zebra": .literal(.int(3))
            ],
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(returns: .int, failing: .anything),
                    body: [
                        Statement(binding: .constant("got"), expression: .apply(reference("apply", "run"), arguments: []))
                    ],
                    result: reference("got")
                )
            ]
        )

        // When
        let answer = try await run(sut, entry: entryName)

        // Then
        #expect(answer == .int(3))
    }

    @Test("a constant may reach a procedure the same way a body does")
    func aConstantReachesAProcedure() async throws {
        // Given. Folding happens after the procedures are known, so a constant that
        // interpolates is a constant that sends
        let sut = try Module(
            constants: [
                "host": .literal(.string("warp.dev")),
                "url": .call(
                    Call(
                        selector: "Standard.Text.joined",
                        arguments: [
                            .array([
                                .literal(.string("https://")),
                                .call(Call(selector: "Standard.Text.text", arguments: [reference("host")]))
                            ]),
                            .literal(.string(""))
                        ]
                    )
                )
            ],
            procedures: [entryName: Procedure(access: .public, signature: Signature(returns: .string), body: [], result: reference("url"))]
        )

        // When
        let answer = try await run(sut, entry: entryName)

        // Then
        #expect(answer == .string("https://warp.dev"))
    }

    @Test("a call on a path this run would never take is still resolved")
    func unreachedCallIsResolved() async throws {
        // Given. The else arm cannot be taken with this input, and the warrant
        // for checking it anyway is compilation: unreached code still compiles
        let sut = try Module(
            procedures: [
                "caller": Procedure(
                    access: .public,
                    body: [
                        Statement(
                            expression: .conditional(
                                equals(.literal(.string("yes")), .literal(.string("yes"))),
                                then: [
                                    Statement(binding: .constant("safe"), expression: .literal(.string("fine")))
                                ],
                                else: [
                                    Statement(binding: .constant("risky"), expression: .call(Call(selector: "missing")))
                                ]
                            )
                        )
                    ]
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("sends 'missing', which no module in this link declares")
        }
    }

    @Test("a call inside a rescue body is resolved")
    func rescueBodyIsResolved() async throws {
        // Given
        let sut = try Module(
            procedures: [
                "caller": Procedure(
                    access: .public,
                    body: [
                        Statement(binding: .constant("attempt"), expression: .attempt(
                                Block(body: [mayFail()]),
                                rescue: Block(body: [
                                    Statement(binding: .constant("recover"), expression: .call(Call(selector: "missing")))
                                ])
                            )
                        )
                    ]
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("sends 'missing', which no module in this link declares")
        }
    }

    @Test("every declaration's calls are resolved, whoever calls it")
    func everyDeclarationIsResolved() async throws {
        // Given. `caller` names nothing missing; `middle` does
        let sut = try Module(
            procedures: [
                "caller": Procedure(
                    access: .public,
                    body: [
                        Statement(binding: .constant("call"), expression: .call(Call(selector: "middle")))
                    ]
                ),
                "middle": Procedure(
                    body: [
                        Statement(binding: .constant("deeper"), expression: .call(Call(selector: "leaf")))
                    ]
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut])
        } throws: { error in
            error is BuildError && "\(error)".contains("sends 'leaf', which no module in this link declares")
        }
    }

    @Test("a module left out of the link is a module that does not exist")
    func omittedModuleIsUnresolved() async throws {
        // Given. The set is the whole graph, so leaving one out is not a lookup
        // that fails later but a name nothing declares
        let caller = try Module(
            procedures: [
                "caller": Procedure(
                    access: .public,
                    body: [
                        Statement(binding: .constant("call"), expression: .call(Call(selector: "leaf")))
                    ]
                )
            ]
        )
        let leaf = try Module(
            procedures: [
                "leaf": Procedure(
                    body: [
                        Statement(binding: .constant("done"), expression: .literal(.string("end")))
                    ]
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([caller])
        } throws: { error in
            error is BuildError && "\(error)".contains("sends 'leaf', which no module in this link declares")
        }
        await #expect(throws: Never.self) {
            try await builder.build([caller, leaf])
        }
    }

    @Test("two modules declaring one name are refused")
    func duplicateSymbolIsRefused() async throws {
        // Given. One flat namespace is what taking the whole graph at once
        // costs, and two declarations of a name have no way to be told apart
        let left = try Module(
            procedures: [
                "shared": Procedure(
                    body: [
                        Statement(binding: .constant("done"), expression: .literal(.string("left")))
                    ]
                )
            ]
        )
        let right = try Module(
            procedures: [
                "shared": Procedure(
                    body: [
                        Statement(binding: .constant("done"), expression: .literal(.string("right")))
                    ]
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([left, right])
        } throws: { error in
            error is BuildError && "\(error)".contains("'shared' is declared by")
        }
    }

    @Test("an undeclared selector is refused before what it answers is read")
    func anUndeclaredSelectorIsRefusedWhereItIsMet() async throws {
        // Given
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(returns: .int),
                    body: [
                        Statement(binding: .constant("got"), expression: .call(
                            Call(selector: "plus", arguments: [.literal(.int(1)), .literal(.int(2))])
                        ))
                    ],
                    result: .reference([.name("got"), .name("field")])
                )
            ]
        )

        // When / Then
        let error = await #expect(throws: BuildError.self) {
            try await builder.build([sut] + Module.standard)
        }

        #expect(error?.message == "sends 'plus', which no module in this link declares")
        #expect(error?.place?.rendered == "procedures.entry.body.got[0].call")
    }

    @Test("a dotted spelling resolves beside the full link")
    func aDottedSpellingResolvesBesideTheFullLink() async throws {
        // Given. `Standard.Concurrent.all` is sent beside every standard bundle, and
        // its spelling names one declaration among all of them
        let sut = try Module(
            procedures: [
                "caller": Procedure(
                    access: .public,
                    signature: Signature(failing: .these(["concurrent_failed"])),
                    body: [
                        Statement(binding: .constant("both"), expression: .call(
                                Call(
                                    selector: "Standard.Concurrent.all",
                                    arguments: [
                                        .array([
                                            .closure(Procedure(signature: Signature(returns: .int, isolation: .isolated), body: [], result: .literal(.int(1))))
                                        ])
                                    ]
                                )
                            )
                        )
                    ]
                )
            ]
        )

        // When / Then
        _ = try await builder.build([sut] + Module.standard)
    }

    @Test("whether a body builds is its own text's fact, whoever calls it")
    func buildingDoesNotDependOnCallers() async throws {
        // Given. `helper` folds a constant-headed call through a written procedure; a procedure
        // (`loud`) that happens to call `helper` must not change what `helper`
        // means, because nothing about `helper`'s text changed
        let procedures: [Name: Procedure] = [
            "shout": Procedure(
                signature: Signature(
                    parameters: [Parameter(name: "of", type: .string)],
                    returns: .int
                ),
                body: [],
                result: .call(Call(selector: "Standard.Collection.count", arguments: [reference("of")]))
            ),
            "helper": Procedure(
                signature: Signature(returns: .int),
                body: [],
                result: .call(Call(selector: "shout", arguments: [reference("greeting")]))
            ),
            "loud": Procedure(
                signature: Signature(
                    parameters: [Parameter(name: "of", type: .int)],
                    returns: .int
                ),
                body: [],
                result: .call(Call(selector: "helper"))
            ),
            entryName: Procedure(
                access: .public,
                signature: Signature(returns: .int),
                body: [],
                result: .call(Call(selector: "helper"))
            )
        ]

        let sut = try Module(
            constants: ["greeting": .literal(.string("hi"))],
            procedures: procedures
        )

        // When / Then. Builds and answers, `loud` present or not
        #expect(try await run(sut) == .int(2))

        var without = procedures
        without["loud"] = nil

        #expect(
            try await run(try Module(
                constants: ["greeting": .literal(.string("hi"))],
                procedures: without
            )) == .int(2)
        )
    }

    @Test("a closure a constant holds has its sends checked")
    func aConstantClosureIsChecked() async throws {
        // Given. The closure runs later, so evaluating the constant proves
        // nothing about the call inside it; the gate every gathered call passes
        // catches the argument no parameter stands to take
        let sut = try Module(
            constants: [
                "f": .closure(Procedure(
                    signature: Signature(returns: .string),
                    body: [],
                    result: .call(Call(
                        selector: "Standard.Text.uppercased",
                        arguments: [.literal(.string("a")), .literal(.bool(true))]
                    ))
                ))
            ],
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(),
                    body: [],
                    result: .reference([.name("f")])
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("sending 'Standard.Text.uppercased' with 2 arguments, and it takes 1")
        }
    }

    @Test("a const body nobody reaches still has its sends checked")
    func anUnreachedConstBodyIsChecked() async throws {
        // Given. Nothing reaches `shout`, and a call it writes wrongly is the
        // build's to refuse all the same
        let sut = try Module(
            procedures: [
                "shout": Procedure(
                    signature: Signature(
                        parameters: [Parameter(name: "of", type: .string)],
                        returns: .string
                    ),
                    body: [],
                    result: .call(Call(
                        selector: "Standard.Text.uppercased",
                        arguments: [.reference([.name("of")]), .literal(.bool(true))]
                    ))
                ),
                entryName: Procedure(
                    access: .public,
                    signature: Signature(returns: .int),
                    body: [],
                    result: .literal(.int(1))
                )
            ]
        )

        // When / Then. `uppercased` takes one argument and is sent two
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("sending 'Standard.Text.uppercased' with 2 arguments, and it takes 1")
        }
    }

    // MARK: - Public
    // MARK: - Private
}
