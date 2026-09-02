//
//  LinkerTests.swift
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
struct LinkerTests {
    // MARK: - Property
    private let linker = Linker()

    // MARK: - Initializer
    // MARK: - Test
    @Test("a constant that cannot be settled says why, not that it is a cycle")
    func aRefusedConstantSaysWhy() throws {
        // Given — `greeting` names nothing that is missing, so the only reason
        // it fails is its own: `text` refuses to spell nothing
        let sut = try Module(
            constants: [
                "greeting": .dispatch(Dispatch(receiver: .literal(.null), selector: "std.text.text"))
            ],
            procedures: [entryName: Procedure(body: [])]
        )

        // When / Then
        let error = #expect(throws: LinkError.self) {
            try linker.link([sut] + Module.standard, entry: entryName)
        }

        #expect(error?.place?.rendered == "constants.greeting")
        #expect(
            error?.message.contains("names it back") == false,
            "a refusal of its own was reported as a cycle"
        )
    }

    @Test("a default the parameter itself would refuse is refused at link")
    func aDefaultOutsideTheTypeIsRefused() throws {
        // Given — the fallback only ever runs for the one call that leans on
        // it, which is exactly the call that could not see this coming
        let sut = try Module(
            procedures: [
                entryName: Procedure(body: []),
                "helper": Procedure(
                    signature: Signature(
                        parameters: [
                            "count": Parameter(type: .int, default: .string("three"))
                        ]
                    ),
                    body: []
                )
            ]
        )

        // When / Then
        let error = #expect(throws: LinkError.self) {
            try linker.link([sut] + Module.standard, entry: entryName)
        }

        #expect(error?.place?.rendered == "procedures.helper.parameters.count")
    }

    @Test("a default outside its own oneOf is refused at link")
    func aDefaultOutsideOneOfIsRefused() throws {
        // Given
        let sut = try Module(
            procedures: [
                entryName: Procedure(body: []),
                "helper": Procedure(
                    signature: Signature(
                        parameters: [
                            "mode": Parameter(
                                type: .string,
                                oneOf: ["fast", "slow"],
                                default: .string("medium")
                            )
                        ]
                    ),
                    body: []
                )
            ]
        )

        // When / Then
        let error = #expect(throws: LinkError.self) {
            try linker.link([sut] + Module.standard, entry: entryName)
        }

        #expect(error?.place?.rendered == "procedures.helper.parameters.mode")
    }

    @Test("an omitted argument arrives as the settled default")
    func aDefaultArrivesSettled() async throws {
        // Given — the fallback walks the same gate an argument does, so a whole
        // number defaulting a fraction slot arrives as the fraction it settles to
        let answer = try await answer(
            of: [],
            result: reference("count"),
            signature: Signature(
                parameters: ["count": Parameter(type: .double, default: .int(1))]
            )
        )

        // Then — Swift-level equality is kind-strict, so this is the settled kind
        #expect(answer == .double(1))
    }

    @Test("a oneOf no candidate of which fits the type is refused at link")
    func anUnsatisfiableOneOfIsRefused() throws {
        // Given — admitting nothing is a fact about the type and the set
        // together, not about the set being empty
        let sut = try Module(
            procedures: [
                entryName: Procedure(body: []),
                "helper": Procedure(
                    signature: Signature(
                        parameters: ["count": Parameter(type: .int, oneOf: ["fast"])]
                    ),
                    body: []
                )
            ]
        )

        // When / Then
        let error = #expect(throws: LinkError.self) {
            try linker.link([sut] + Module.standard, entry: entryName)
        }

        #expect(error?.message.contains("admits nothing") == true)
    }

    @Test("a null default on a type that does not admit null is refused at link")
    func aNullDefaultOutsideTheTypeIsRefused() throws {
        // Given — the explicitly-null default is the value the body receives,
        // so the declaration must admit it like any other value
        let sut = try Module(
            procedures: [
                entryName: Procedure(body: []),
                "helper": Procedure(
                    signature: Signature(
                        parameters: ["word": Parameter(type: .string, default: .null)]
                    ),
                    body: []
                )
            ]
        )

        // When / Then
        let error = #expect(throws: LinkError.self) {
            try linker.link([sut] + Module.standard, entry: entryName)
        }

        #expect(error?.message.contains("null") == true)
    }

    @Test("a parameter nested in a procedure type is judged like a top-level one")
    func aNestedParameterDeclarationIsJudged() throws {
        // Given — the declaration facts are the same wherever the parameter is
        // written, so the judgment rides the same recursion that resolves the
        // nested type names
        let sut = try Module(
            procedures: [
                entryName: Procedure(body: []),
                "helper": Procedure(
                    signature: Signature(
                        parameters: [
                            "by": Parameter(
                                type: .procedure(
                                    Signature(
                                        parameters: [
                                            "mode": Parameter(type: .string, oneOf: [])
                                        ],
                                        returns: .bool
                                    )
                                )
                            )
                        ]
                    ),
                    body: []
                )
            ]
        )

        // When / Then
        let error = #expect(throws: LinkError.self) {
            try linker.link([sut] + Module.standard, entry: entryName)
        }

        #expect(error?.message.contains("admits nothing") == true)
    }

    @Test("a oneOf that admits nothing is refused at link")
    func anEmptyOneOfIsRefused() throws {
        // Given — no call could ever fit it, so the declaration is the defect
        let sut = try Module(
            procedures: [
                entryName: Procedure(body: []),
                "helper": Procedure(
                    signature: Signature(
                        parameters: ["mode": Parameter(type: .string, oneOf: [])]
                    ),
                    body: []
                )
            ]
        )

        // When / Then
        let error = #expect(throws: LinkError.self) {
            try linker.link([sut] + Module.standard, entry: entryName)
        }

        #expect(error?.message.contains("admits nothing") == true)
    }

    @Test("constants settle in the order they read each other, however deep")
    func constantsSettleInReadingOrder() async throws {
        // Given — a chain written so that alphabetical order is the reverse of
        // reading order, and long enough that settling whatever can be settled
        // and going round again would take more than one pass. What each one
        // reads is settled before it because the order says so, not because
        // enough rounds happened.
        let sut = try Module(
            constants: [
                "zebra": .literal(.int(2)),
                "yak": .dispatch(
                    Dispatch(
                        receiver: reference("zebra"),
                        selector: "std.math.times",
                        arguments: ["value": reference("zebra")]
                    )
                ),
                "xerus": .dispatch(
                    Dispatch(
                        receiver: reference("yak"),
                        selector: "std.math.plus",
                        arguments: ["value": reference("zebra")]
                    )
                )
            ],
            procedures: [entryName: Procedure(body: [], result: reference("xerus"))]
        )

        // When
        let answer = try await run(sut, entry: entryName)

        // Then
        #expect(answer == .int(6))
    }

    @Test("a closure constant reads a constant beside it whatever the two are called")
    func aClosureConstantCapturesItsSiblings() async throws {
        // Given — making a closure freezes the scope it was made in, so a
        // sibling its body reads has to be settled by then. Nothing in the body
        // runs while the constants settle, which is what makes it look like no
        // dependency at all — and read that way, what the closure captures is
        // whatever happened to be settled when its turn came round.
        //
        // Both spellings of one program, differing only in whether the closure
        // sorts before or after what it reads. An answer that is not the same
        // twice is a program whose meaning is in its names.
        func module(closure: String, reading constant: String) throws -> Module {
            try Module(
                constants: [
                    closure: .closure(Procedure(body: [], result: reference(constant))),
                    constant: .literal(.int(3))
                ],
                procedures: [
                    entryName: Procedure(
                        body: [
                            Statement(binding: .constant("got"), expression: .invoke(reference(closure), arguments: [:])
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
        // Given — the rule a body is held to at load, met here from the caller's
        // side. Neither shape links, and both are the same mistake: a name the
        // module bound, introduced again where it would take the constant's
        // place.
        func module(introducing statement: Statement?) throws -> Module {
            try Module(
                constants: [
                    "apply": .closure(Procedure(
                        signature: Signature(
                            parameters: statement == nil
                                ? ["zebra": Parameter(type: .int)]
                                : [:],
                            returns: .int
                        ),
                        body: statement.map { one in [one] } ?? [],
                        result: reference("zebra")
                    )),
                    "zebra": .literal(.int(7))
                ],
                procedures: [entryName: Procedure(body: [])]
            )
        }

        // When / Then — the two ways a closure introduces a name of its own
        for introduced in [nil, Statement(binding: .constant("zebra"), expression: .literal(.int(7)))] {
            await #expect(throws: ValidationError.self) {
                try await run(module(introducing: introduced))
            }
        }
    }

    @Test("a closure reading a constant from inside a block still has it")
    func aClosureReadsASiblingFromInsideABlock() async throws {
        // Given — how deep in the closure the name is read makes no difference
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
                    body: [
                        Statement(binding: .constant("got"), expression: .invoke(reference("apply"), arguments: [:])
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
        // Given — what captures is the closure and not the constant holding it,
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
                    body: [
                        Statement(binding: .constant("got"), expression: .invoke(reference("apply", "run"), arguments: [:])
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

    @Test("a constant may reach a word the same way a body does")
    func aConstantReachesAWord() async throws {
        // Given — folding happens after the words are known, so a constant that
        // interpolates is a constant that sends
        let sut = try Module(
            constants: [
                "host": .literal(.string("warp.dev")),
                "url": .dispatch(
                    Dispatch(
                        receiver: .array([
                            .literal(.string("https://")),
                            .dispatch(Dispatch(receiver: reference("host"), selector: "std.text.text"))
                        ]),
                        selector: "std.text.joined"
                    )
                )
            ],
            procedures: [entryName: Procedure(body: [], result: reference("url"))]
        )

        // When
        let answer = try await run(sut, entry: entryName)

        // Then
        #expect(answer == .string("https://warp.dev"))
    }

    @Test("a call on a path this run would never take is still resolved")
    func unreachedCallIsLinked() throws {
        // Given — the else arm cannot be taken with this input, and the warrant
        // for checking it anyway is compilation: unreached code still compiles
        let sut = try Module(
            procedures: [
                "caller": Procedure(
                    body: [
                        Statement(
                            expression: .conditional(equals(
                                        .literal(.string("yes")),
                                        .literal(.string("yes"))
                                        ), then: [
                                        Statement(binding: .constant("safe"), expression: .literal(.string("fine"))
                                        )
                                    ], else: [
                                        Statement(binding: .constant("risky"), expression: .dispatch(Dispatch(selector: "missing"))
                                        )
                                    ])
                        )
                    ]
                )
            ]
        )

        // When / Then
        #expect(throws: LinkError.self) {
            try linker.link([sut], entry: "caller")
        }
    }

    @Test("a call inside a rescue body is resolved")
    func rescueBodyIsLinked() throws {
        // Given
        let sut = try Module(
            procedures: [
                "caller": Procedure(
                    body: [
                        Statement(binding: .constant("attempt"), expression: .attempt(Block(body: [
                                        Statement(binding: .constant("attempt"), expression: .dispatch(Dispatch(selector: "app.fail", arguments: [
                                                        "recoverable": .literal(.bool(true))
                                                    ]))
                                        )
                                    ]), rescue: Block(body: [
                                        Statement(binding: .constant("recover"), expression: .dispatch(Dispatch(selector: "missing"))
                                        )
                                    ]), failure: "attempt")
                        )
                    ]
                )
            ]
        )

        // When / Then
        #expect(throws: LinkError.self) {
            try linker.link([sut], entry: "caller")
        }
    }

    @Test("resolution follows the callee's own calls")
    func linkingIsTransitive() throws {
        // Given — `caller` names nothing missing; `middle` does
        let sut = try Module(
            procedures: [
                "caller": Procedure(
                    body: [
                        Statement(binding: .constant("call"), expression: .dispatch(Dispatch(selector: "middle"))
                        )
                    ]
                ),
                "middle": Procedure(
                    body: [
                        Statement(binding: .constant("deeper"), expression: .dispatch(Dispatch(selector: "leaf"))
                        )
                    ]
                )
            ]
        )

        // When / Then
        #expect(throws: LinkError.self) {
            try linker.link([sut], entry: "caller")
        }
    }

    @Test("names resolve across every module in the link, flat")
    func symbolsResolveAcrossModules() throws {
        // Given — no module says anything about the others; what to link is the
        // caller's statement and joining the names up is the linker's work
        let caller = try Module(
            procedures: [
                "caller": Procedure(
                    body: [
                        Statement(binding: .constant("call"), expression: .dispatch(Dispatch(selector: "middle"))
                        )
                    ]
                )
            ]
        )
        let middle = try Module(
            procedures: [
                "middle": Procedure(
                    body: [
                        Statement(binding: .constant("deeper"), expression: .dispatch(Dispatch(selector: "leaf"))
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
        let image = try linker.link([caller, middle, leaf], entry: "caller")

        // Then
        #expect(Set(image.procedures.keys) == ["caller", "middle", "leaf"])
    }

    @Test("a module left out of the link is a module that does not exist")
    func omittedModuleIsUnresolved() throws {
        // Given — the set is the whole world, so leaving one out is not a
        // lookup that fails later but a name nothing declares
        let caller = try Module(
            procedures: [
                "caller": Procedure(
                    body: [
                        Statement(binding: .constant("call"), expression: .dispatch(Dispatch(selector: "leaf"))
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
        #expect(throws: LinkError.self) {
            try linker.link([caller], entry: "caller")
        }
        #expect(throws: Never.self) {
            try linker.link([caller, leaf], entry: "caller")
        }
    }

    @Test("two modules declaring one name are refused")
    func duplicateSymbolIsRefused() throws {
        // Given — one flat namespace is what taking the whole world at once
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
        #expect(throws: LinkError.self) {
            try linker.link([left, right], entry: "shared")
        }
    }

    @Test("an entry nothing declares is refused")
    func missingEntryIsRefused() throws {
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

        // When / Then
        #expect(throws: LinkError.self) {
            try linker.link([sut], entry: "absent")
        }
    }

    @Test("any declaration can be the entry")
    func anyProcedureCanBeTheEntry() async throws {
        // Given — nothing marks one of them, so which runs is this argument
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
    func recursiveProcedureLinksOnce() throws {
        // Given
        let sut = try Module(
            procedures: [
                "loopy": Procedure(
                    body: [
                        Statement(binding: .constant("again"), expression: .dispatch(Dispatch(selector: "loopy"))
                        )
                    ]
                )
            ]
        )

        // When
        let image = try linker.link([sut], entry: "loopy")

        // Then
        #expect(Set(image.procedures.keys) == ["loopy"])
    }

    @Test("an argument the callee never declared is refused")
    func undeclaredArgumentIsRefused() throws {
        // Given
        let sut = try Module(
            procedures: [
                "callee": Procedure(
                    signature: Signature(
                        parameters: [
                            "base": Parameter(type: .int)
                        ]
                    ),
                    body: [
                        Statement(binding: .constant("echo"), expression: .reference([.key("base")])
                        )
                    ]
                ),
                "caller": Procedure(
                    body: [
                        Statement(binding: .constant("call"), expression: .dispatch(Dispatch(selector: "callee", arguments: [
                                        "base": .literal(.int(1)),
                                        "bonus": .literal(.int(2))
                                    ]))
                        )
                    ]
                )
            ]
        )

        // When / Then
        #expect(throws: LinkError.self) {
            try linker.link([sut], entry: "caller")
        }
    }

    @Test("a required argument nobody passes is refused")
    func missingRequiredArgumentIsRefused() throws {
        // Given
        let sut = try Module(
            procedures: [
                "callee": Procedure(
                    signature: Signature(
                        parameters: [
                            "base": Parameter(type: .int)
                        ]
                    ),
                    body: [
                        Statement(binding: .constant("echo"), expression: .reference([.key("base")])
                        )
                    ]
                ),
                "caller": Procedure(
                    body: [
                        Statement(binding: .constant("call"), expression: .dispatch(Dispatch(selector: "callee"))
                        )
                    ]
                )
            ]
        )

        // When / Then
        #expect(throws: LinkError.self) {
            try linker.link([sut], entry: "caller")
        }
    }

    @Test("an argument named rather than written is judged by what the name holds")
    func referenceArgumentIsJudged() throws {
        // Given — the type is wrong, and both sides said so in their own text:
        // `text` was declared a string and `base` is declared an int
        let sut = try Module(
            procedures: [
                "callee": Procedure(
                    signature: Signature(
                        parameters: [
                            "base": Parameter(type: .int)
                        ]
                    ),
                    body: [
                        Statement(binding: .constant("echo"), expression: .reference([.key("base")])
                        )
                    ]
                ),
                "caller": Procedure(
                    signature: Signature(
                        parameters: [
                            "text": Parameter(type: .string)
                        ]
                    ),
                    body: [
                        Statement(binding: .constant("call"), expression: .dispatch(Dispatch(selector: "callee", arguments: [
                                        "base": .reference([.key("text")])
                                    ]))
                        )
                    ]
                )
            ]
        )

        // When / Then
        #expect(throws: LinkError.self) {
            try linker.link([sut], entry: "caller")
        }
    }

    @Test("what no body settles is not something the link can be wrong about")
    func anAnswerNothingSettlesIsNotJudged() throws {
        // Given — `held` comes back from a call that declares no answer, and
        // whose body answers what that same call answers. An answer worked out
        // from its own is not one the text states, so nothing is known about
        // it and nothing is refused. That is the bound on the promise:
        // inference answers where the text settles and `any` everywhere else.
        let sut = try Module(
            procedures: [
                "callee": Procedure(
                    signature: Signature(
                        parameters: [
                            "base": Parameter(type: .int)
                        ]
                    ),
                    body: [
                        Statement(binding: .constant("echo"), expression: .reference([.key("base")])
                        )
                    ]
                ),
                "caller": Procedure(
                    body: [
                        Statement(binding: .constant("held"), expression: .dispatch(Dispatch(selector: "opaque"))
                        ),
                        Statement(binding: .constant("call"), expression: .dispatch(Dispatch(selector: "callee", arguments: [
                                        "base": .reference([.key("held")])
                                    ]))
                        )
                    ]
                ),
                "opaque": Procedure(
                    body: [],
                    result: .dispatch(Dispatch(selector: "opaque"))
                )
            ]
        )

        // When / Then
        _ = try linker.link([sut], entry: "caller")
    }

    @Test("a body that settles an answer is held to it, declared or not")
    func anAnswerReadOffABodyIsJudged() throws {
        // Given — the same shape, with a body whose answer the text does
        // settle: a body with no result hands back null, and null is not a
        // whole number. What the declaration says stays what it says; what the
        // link reads a call as is what the body hands back.
        let sut = try Module(
            procedures: [
                "callee": Procedure(
                    signature: Signature(parameters: ["base": Parameter(type: .int)]),
                    body: [Statement(binding: .constant("echo"), expression: .reference([.key("base")]))]
                ),
                "caller": Procedure(
                    body: [
                        Statement(binding: .constant("held"), expression: .dispatch(Dispatch(selector: "opaque"))
                        ),
                        Statement(binding: .constant("call"), expression: .dispatch(Dispatch(selector: "callee", arguments: [
                                        "base": .reference([.key("held")])
                                    ]))
                        )
                    ]
                ),
                "opaque": Procedure(
                    body: [Statement(binding: .constant("made"), expression: .literal(.string("whatever")))]
                )
            ]
        )

        // When / Then
        #expect {
            try linker.link([sut], entry: "caller")
        } throws: { error in
            error is LinkError && "\(error)".contains("holds null where int is declared")
        }
    }

    @Test("a procedure that calls nothing links alone")
    func selfContainedProcedureLinks() throws {
        // Given
        let sut = try Module(
            procedures: [
                "alone": Procedure(
                    body: [
                        Statement(binding: .constant("done"), expression: .literal(.string("end"))
                        )
                    ]
                )
            ]
        )

        // When
        let image = try linker.link([sut], entry: "alone")

        // Then
        #expect(Set(image.procedures.keys) == ["alone"])
    }

    @Test("an undeclared selector is refused before what it answers is read")
    func anUndeclaredSelectorIsRefusedWhereItIsMet() throws {
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    signature: Signature(returns: .int),
                    body: [
                        Statement(binding: .constant("got"), expression: .dispatch(
                                Dispatch(
                                    receiver: .literal(.int(1)),
                                    selector: "plus",
                                    arguments: ["value": .literal(.int(2))]
                                )
                            )
                        )
                    ],
                    result: .reference([.key("got"), .key("field")])
                )
            ]
        )

        let error = #expect(throws: LinkError.self) {
            try linker.link([sut] + Module.standard, entry: entryName)
        }

        #expect(error?.message == "sends 'plus', which no module in this link declares")
        #expect(error?.place?.rendered == "procedures.entry.body.got[0].dispatch")
    }

    @Test("a dotted spelling resolves beside the full link")
    func aDottedSpellingResolvesBesideTheFullLink() throws {
        // Given — `std.concurrent.all` is sent beside every standard bundle,
        // and its spelling names one declaration among all of them
        let sut = try Module(
            procedures: [
                "caller": Procedure(
                    body: [
                        Statement(binding: .constant("both"), expression: .dispatch(
                                Dispatch(
                                    receiver: .array([
                                        .closure(Procedure(body: [], result: .literal(.int(1))))
                                    ]),
                                    selector: "std.concurrent.all"
                                )
                            )
                        )
                    ]
                )
            ]
        )

        // When / Then
        _ = try linker.link([sut] + Module.standard, entry: "caller")
    }
}
