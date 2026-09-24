//
//  BuilderTests.swift
//  WarpTests
//
//  Created by JSilver on 8/16/26.
//

import Foundation
import Testing
@testable import Warp

// Linking, asked the way a caller asks it: modules loaded from documents, handed
// over as a set, and one name to start from.
@Suite
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
                    selector: "std.math.dividedBy",
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

    @Test("a enum no candidate of which fits the type is refused at link")
    func anUnsatisfiableOneOfIsRefused() async throws {
        // Given. Admitting nothing is a fact about the type and the set
        // together, not about the set being empty
        let sut = try Module(
            procedures: [
                entryName: Procedure(access: .public, body: []),
                "helper": Procedure(
                    signature: Signature(
                        parameters: [Parameter(name: "count", type: .int, candidates: ["fast"])]
                    ),
                    body: []
                )
            ]
        )

        // When / Then
        let error = await #expect(throws: BuildError.self) {
            try await builder.build([sut] + Module.standard)
        }

        #expect(error?.message.contains("admits nothing") == true)
    }

    @Test("a enum that admits nothing is refused at link")
    func anEmptyOneOfIsRefused() async throws {
        // Given. No call could ever fit it, so the declaration is the defect
        let sut = try Module(
            procedures: [
                entryName: Procedure(access: .public, body: []),
                "helper": Procedure(
                    signature: Signature(
                        parameters: [Parameter(name: "mode", type: .string, candidates: [])]
                    ),
                    body: []
                )
            ]
        )

        // When / Then
        let error = await #expect(throws: BuildError.self) {
            try await builder.build([sut] + Module.standard)
        }

        #expect(error?.message.contains("admits nothing") == true)
    }

    @Test("constants settle in the order they read each other, however deep")
    func constantsSettleInReadingOrder() async throws {
        // Given. A chain written so that alphabetical order is the reverse of
        // reading order, and long enough that settling whatever can be settled
        // and going round again would take more than one pass. What each one
        // reads is settled before it because the order says so, not because
        // enough rounds happened.
        let sut = try Module(
            constants: [
                "zebra": .literal(.int(2)),
                "yak": .call(
                    Call(selector: "std.math.times", arguments: [reference("zebra"), reference("zebra")])
                ),
                "xerus": .call(
                    Call(selector: "std.math.plus", arguments: [reference("yak"), reference("zebra")])
                )
            ],
            procedures: [entryName: Procedure(access: .public, body: [], result: reference("xerus"))]
        )

        // When
        let answer = try await run(sut, entry: entryName)

        // Then
        #expect(answer == .int(6))
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
        func module(closure: Name, reading constant: Name) async throws -> Module {
            try Module(
                constants: [
                    closure: .closure(Procedure(body: [], result: reference(constant))),
                    constant: .literal(.int(3))
                ],
                procedures: [
                    entryName: Procedure(
                        access: .public,
                        body: [
                            Statement(binding: .constant("got"), expression: .apply(reference(closure), arguments: [])
                            )
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

    @Test("a closure a constant holds may not introduce a sibling's name")
    func aClosureConstantMayNotShadowASibling() async throws {
        // Given. The rule a body is held to at load, met here from the caller's
        // side. Neither type links, and both are the same mistake: a name the
        // module bound, introduced again where it would take the constant's
        // place.
        func module(introducing statement: Statement?) async throws -> Module {
            try Module(
                constants: [
                    "apply": .closure(Procedure(
                        signature: Signature(
                            parameters: statement == nil
                                ? [Parameter(name: "zebra", type: .int)]
                                : [],
                            returns: .int
                        ),
                        body: statement.map { one in [one] } ?? [],
                        result: reference("zebra")
                    )),
                    "zebra": .literal(.int(7))
                ],
                procedures: [entryName: Procedure(access: .public, body: [])]
            )
        }

        // When / Then. The two ways a closure introduces a name of its own
        for introduced in [nil, Statement(binding: .constant("zebra"), expression: .literal(.int(7)))] {
            await #expect(throws: ValidationError.self) {
                try await run(module(introducing: introduced))
            }
        }
    }

    @Test("a closure reading a constant from inside a block still has it")
    func aClosureReadsASiblingFromInsideABlock() async throws {
        // Given. How deep in the closure the name is read makes no difference
        // to when it has to be settled: the capture happens once, when the
        // closure is made. The spelling puts the closure first in name order,
        // which is the order it would settle in if nothing said otherwise.
        let sut = try Module(
            constants: [
                "apply": .closure(Procedure(
                    signature: Signature(returns: .int),
                    body: [
                        Statement(binding: .constant("got"), expression: .block(Block(body: [], result: reference("zebra")))
                        )
                    ],
                    result: reference("got")
                )),
                "zebra": .literal(.int(7))
            ],
            procedures: [
                entryName: Procedure(
                    access: .public,
                    body: [
                        Statement(binding: .constant("got"), expression: .apply(reference("apply"), arguments: [])
                        )
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

    @Test("a closure a constant holds inside a record reads the constants beside it")
    func aClosureInsideARecordCapturesItsSiblings() async throws {
        // Given. What captures is the closure and not the constant holding it,
        // so a closure nested in a record has the same demand on the order as
        // one written on its own.
        let sut = try Module(
            constants: [
                "apply": .record([
                    "run": .closure(Procedure(
                        signature: Signature(returns: .int),
                        body: [],
                        result: reference("zebra")
                    ))
                ]),
                "zebra": .literal(.int(3))
            ],
            procedures: [
                entryName: Procedure(
                    access: .public,
                    body: [
                        Statement(binding: .constant("got"), expression: .apply(reference("apply", "run"), arguments: [])
                        )
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
                        selector: "std.text.joined",
                        arguments: [
                            .array([
                                .literal(.string("https://")),
                                .call(Call(selector: "std.text.text", arguments: [reference("host")]))
                            ])
                        ]
                    )
                )
            ],
            procedures: [entryName: Procedure(access: .public, body: [], result: reference("url"))]
        )

        // When
        let answer = try await run(sut, entry: entryName)

        // Then
        #expect(answer == .string("https://warp.dev"))
    }

    @Test("a call on a path this run would never take is still resolved")
    func unreachedCallIsLinked() async throws {
        // Given. The else arm cannot be taken with this input, and the warrant
        // for checking it anyway is compilation: unreached code still compiles
        let sut = try Module(
            procedures: [
                "caller": Procedure(
                    access: .public,
                    body: [
                        Statement(
                            expression: .conditional(equals(
                                        .literal(.string("yes")),
                                        .literal(.string("yes"))
                                        ), then: [
                                        Statement(binding: .constant("safe"), expression: .literal(.string("fine"))
                                        )
                                    ], else: [
                                        Statement(binding: .constant("risky"), expression: .call(Call(selector: "missing"))
                                        )
                                    ])
                        )
                    ]
                )
            ]
        )

        // When / Then
        await #expect(throws: BuildError.self) {
            try await builder.build([sut])
        }
    }

    @Test("a call inside a rescue body is resolved")
    func rescueBodyIsLinked() async throws {
        // Given
        let sut = try Module(
            procedures: [
                "caller": Procedure(
                    access: .public,
                    body: [
                        Statement(binding: .constant("attempt"), expression: .attempt(Block(body: [
                                        Statement(binding: .constant("attempt"), expression: .call(Call(
                                            selector: "app.fail",
                                            arguments: [.literal(.bool(true))]
                                        ))
                                        )
                                    ]), rescue: Block(body: [
                                        Statement(binding: .constant("recover"), expression: .call(Call(selector: "missing"))
                                        )
                                    ]), failure: "attempt")
                        )
                    ]
                )
            ]
        )

        // When / Then
        await #expect(throws: BuildError.self) {
            try await builder.build([sut])
        }
    }

    @Test("resolution follows the callee's own calls")
    func linkingIsTransitive() async throws {
        // Given. `caller` names nothing missing; `middle` does
        let sut = try Module(
            procedures: [
                "caller": Procedure(
                    access: .public,
                    body: [
                        Statement(binding: .constant("call"), expression: .call(Call(selector: "middle"))
                        )
                    ]
                ),
                "middle": Procedure(
                    body: [
                        Statement(binding: .constant("deeper"), expression: .call(Call(selector: "leaf"))
                        )
                    ]
                )
            ]
        )

        // When / Then
        await #expect(throws: BuildError.self) {
            try await builder.build([sut])
        }
    }

    @Test("names resolve across every module in the link, flat")
    func symbolsResolveAcrossModules() async throws {
        // Given. No module says anything about the others; what to link is the
        // caller's statement and joining the names up is the builder's work
        let caller = try Module(
            procedures: [
                "caller": Procedure(
                    access: .public,
                    body: [
                        Statement(binding: .constant("call"), expression: .call(Call(selector: "middle"))
                        )
                    ]
                )
            ]
        )
        let middle = try Module(
            procedures: [
                "middle": Procedure(
                    body: [
                        Statement(binding: .constant("deeper"), expression: .call(Call(selector: "leaf"))
                        )
                    ]
                )
            ]
        )
        let leaf = try Module(
            procedures: [
                "leaf": Procedure(
                    body: [
                        Statement(binding: .constant("done"), expression: .literal(.string("end"))
                        )
                    ]
                )
            ]
        )

        // When
        let image = try await builder.build([caller, middle, leaf])

        // Then
        #expect(try image.reached(from: "caller") == ["caller", "middle", "leaf"])
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
                        Statement(binding: .constant("call"), expression: .call(Call(selector: "leaf"))
                        )
                    ]
                )
            ]
        )
        let leaf = try Module(
            procedures: [
                "leaf": Procedure(
                    body: [
                        Statement(binding: .constant("done"), expression: .literal(.string("end"))
                        )
                    ]
                )
            ]
        )

        // When / Then
        await #expect(throws: BuildError.self) {
            try await builder.build([caller])
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
                        Statement(binding: .constant("done"), expression: .literal(.string("left"))
                        )
                    ]
                )
            ]
        )
        let right = try Module(
            procedures: [
                "shared": Procedure(
                    body: [
                        Statement(binding: .constant("done"), expression: .literal(.string("right"))
                        )
                    ]
                )
            ]
        )

        // When / Then
        await #expect(throws: BuildError.self) {
            try await builder.build([left, right])
        }
    }

    @Test("an entry nothing declares is refused")
    func missingEntryIsRefused() async throws {
        // Given
        let sut = try Module(
            procedures: [
                "present": Procedure(
                    body: [
                        Statement(binding: .constant("done"), expression: .literal(.string("end"))
                        )
                    ]
                )
            ]
        )

        // When / Then. The build judged every declaration; the run is what
        // names one, and a name nothing declares is refused there.
        let image = try await builder.build([sut])

        await #expect(throws: ExecutionError.self) {
            try await Executor().run(image, entry: "absent")
        }
    }

    @Test("any declaration can be the entry")
    func anyProcedureCanBeTheEntry() async throws {
        // Given. Nothing marks one of them, so which runs is this argument
        let sut = try Module(
            procedures: [
                "first": Procedure(
                    body: [
                        Statement(binding: .constant("done"), expression: .literal(.string("from-first"))
                        )
                    ],
                    result: .record([
                            "result": .reference([.key("done")])
                        ])
                ),
                "second": Procedure(
                    body: [
                        Statement(binding: .constant("done"), expression: .literal(.string("from-second"))
                        )
                    ],
                    result: .record([
                            "result": .reference([.key("done")])
                        ])
                )
            ]
        )

        // When
        let first = try await run(sut, entry: "first")
        let second = try await run(sut, entry: "second")

        // Then
        #expect(first["result"] == .string("from-first"))
        #expect(second["result"] == .string("from-second"))
    }

    @Test("a self-recursive procedure links once instead of forever")
    func recursiveProcedureLinksOnce() async throws {
        // Given
        let sut = try Module(
            procedures: [
                "loopy": Procedure(
                    access: .public,
                    body: [
                        Statement(binding: .constant("again"), expression: .call(Call(selector: "loopy"))
                        )
                    ]
                )
            ]
        )

        // When
        let image = try await builder.build([sut])

        // Then
        #expect(try image.reached(from: "loopy") == ["loopy"])
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
                        Statement(binding: .constant("echo"), expression: .reference([.key("base")])
                        )
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
        await #expect(throws: BuildError.self) {
            try await builder.build([sut])
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
                        Statement(binding: .constant("echo"), expression: .reference([.key("base")])
                        )
                    ]
                ),
                "caller": Procedure(
                    access: .public,
                    body: [
                        Statement(binding: .constant("call"), expression: .call(Call(selector: "callee"))
                        )
                    ]
                )
            ]
        )

        // When / Then
        await #expect(throws: BuildError.self) {
            try await builder.build([sut])
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
                        Statement(binding: .constant("echo"), expression: .reference([.key("base")])
                        )
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
                        ))
                        )
                    ]
                )
            ]
        )

        // When / Then
        await #expect(throws: BuildError.self) {
            try await builder.build([sut])
        }
    }

    @Test("what no body settles is not something the build can be wrong about")
    func anAnswerNothingSettlesIsNotJudged() async throws {
        // Given. `held` comes back from a call that declares no answer, and
        // whose body answers what that same call answers. An answer worked out
        // from its own is not one the text states, so nothing is known about it
        // and nothing is refused. That is the bound on the promise: inference
        // answers where the text settles and `any` everywhere else.
        let sut = try Module(
            procedures: [
                "callee": Procedure(
                    signature: Signature(
                        parameters: [
                            Parameter(name: "base", type: .int)
                        ]
                    ),
                    body: [
                        Statement(binding: .constant("echo"), expression: .reference([.key("base")])
                        )
                    ]
                ),
                "caller": Procedure(
                    access: .public,
                    body: [
                        Statement(binding: .constant("held"), expression: .call(Call(selector: "opaque"))
                        ),
                        Statement(binding: .constant("call"), expression: .call(Call(
                            selector: "callee",
                            arguments: [.reference([.key("held")])]
                        ))
                        )
                    ]
                ),
                "opaque": Procedure(
                    body: [],
                    result: .call(Call(selector: "opaque"))
                )
            ]
        )

        // When / Then
        _ = try await builder.build([sut])
    }

    @Test("a body that settles an answer is held to it, declared or not")
    func anAnswerReadOffABodyIsJudged() async throws {
        // Given. The same type, with a body whose answer the text does settle:
        // a body with no result hands back null, and null is not a whole
        // number. What the declaration says stays what it says; what the build
        // reads a call as is what the body hands back.
        let sut = try Module(
            procedures: [
                "callee": Procedure(
                    signature: Signature(parameters: [Parameter(name: "base", type: .int)]),
                    body: [Statement(binding: .constant("echo"), expression: .reference([.key("base")]))]
                ),
                "caller": Procedure(
                    access: .public,
                    body: [
                        Statement(binding: .constant("held"), expression: .call(Call(selector: "opaque"))
                        ),
                        Statement(binding: .constant("call"), expression: .call(Call(
                            selector: "callee",
                            arguments: [.reference([.key("held")])]
                        ))
                        )
                    ]
                ),
                "opaque": Procedure(
                    body: [Statement(binding: .constant("made"), expression: .literal(.string("whatever")))]
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut])
        } throws: { error in
            error is BuildError && "\(error)".contains("holds null where int is declared")
        }
    }

    @Test("a procedure that calls nothing links alone")
    func selfContainedProcedureLinks() async throws {
        // Given
        let sut = try Module(
            procedures: [
                "alone": Procedure(
                    access: .public,
                    body: [
                        Statement(binding: .constant("done"), expression: .literal(.string("end"))
                        )
                    ]
                )
            ]
        )

        // When
        let image = try await builder.build([sut])

        // Then
        #expect(try image.reached(from: "alone") == ["alone"])
    }

    @Test("an undeclared selector is refused before what it answers is read")
    func anUndeclaredSelectorIsRefusedWhereItIsMet() async throws {
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(returns: .int),
                    body: [
                        Statement(binding: .constant("got"), expression: .call(
                                Call(selector: "plus", arguments: [.literal(.int(1)), .literal(.int(2))])
                            )
                        )
                    ],
                    result: .reference([.key("got"), .key("field")])
                )
            ]
        )

        let error = await #expect(throws: BuildError.self) {
            try await builder.build([sut] + Module.standard)
        }

        #expect(error?.message == "sends 'plus', which no module in this link declares")
        #expect(error?.place?.rendered == "procedures.entry.body.got[0].call")
    }

    @Test("a dotted spelling resolves beside the full link")
    func aDottedSpellingResolvesBesideTheFullLink() async throws {
        // Given. `std.concurrent.all` is sent beside every standard bundle, and
        // its spelling names one declaration among all of them
        let sut = try Module(
            procedures: [
                "caller": Procedure(
                    access: .public,
                    body: [
                        Statement(binding: .constant("both"), expression: .call(
                                Call(
                                    selector: "std.concurrent.all",
                                    arguments: [
                                        .array([
                                            .closure(Procedure(body: [], result: .literal(.int(1))))
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
}
