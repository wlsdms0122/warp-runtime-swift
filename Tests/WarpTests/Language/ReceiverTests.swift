//
//  ReceiverTests.swift
//  WarpTests
//
//  Created by JSilver on 8/17/26.
//

import Foundation
import Testing
@testable import Warp

// `${x.count}` works because `count` is a declaration, and so is anything else
// that declares a receiver, which is the whole of what method syntax means
// here. It is not reserved for native code.
@Suite("A declaration may be sent to something")
struct ReceiverTests {
    // MARK: - Property
    private let linker = Linker()

    // MARK: - Lifecycle
    // MARK: - Test
    @Test("a declared receiver is read by the name the signature gave it")
    func receiverIsANamedParameter() async throws {
        // Given
        let sut = try Module(
            procedures: [
                "entry": Procedure(
                    signature: Signature(
                        parameters: [
                            "word": Parameter(type: .string)
                        ]
                    ),
                    body: [
                        Statement(binding: .constant("said"), expression: .dispatch(Dispatch(selector: "shout", arguments: [
                                        "of": .reference([.key("word")])
                                    ]))
                        )
                    ],
                    result: .record([
                            "result": .reference([.key("said")])
                        ])
                ),
                "shout": Procedure(
                    signature: Signature(
                        receiver: "of",
                        parameters: [
                            "of": Parameter(type: .string)
                        ],
                        returns: .string
                    ),
                    body: [
                        Statement(binding: .constant("loud"), expression: interpolated(
                                spelling(reference("of")),
                                literal("!")
                            )
                        )
                    ],
                    result: .reference([.key("loud")])
                )
            ]
        )

        // When
        let outputs = try await run(sut, arguments: ["word": .string("hey")])

        // Then
        #expect(outputs["result"] == .string("hey!"))
    }

    @Test("a native word and a written one are declared the same way")
    func nativeAndWrittenDeclareAlike() throws {
        // Given
        let written = try Module(
            procedures: [
                "entry": Procedure(
                    body: [
                        Statement(binding: .constant("done"), expression: .literal(.string("end"))
                        )
                    ]
                ),
                "shout": Procedure(
                    signature: Signature(
                        receiver: "of",
                        parameters: [
                            "of": Parameter(type: .string)
                        ],
                        returns: .string
                    ),
                    body: [
                        Statement(binding: .constant("loud"), expression: .reference([.key("of")])
                        )
                    ]
                )
            ]
        )

        // When
        let image = try linker.link([written] + Module.standard, entry: entryName)

        // Then. One table, and what separates them is only how each is written
        let shout = try #require(image["shout"])
        let count = try #require(image["std.collection.count"])

        #expect(shout.signature.receiver == "of")
        #expect(count.signature.receiver == "of")
        #expect(shout.isWritten)
        #expect(!count.isWritten)
    }

    @Test("a call sends its receiver even where the parameter is required")
    func receiverSuppliesItsParameter() async throws {
        // Given. The receiver is written on the other side of the dot, so the
        // linker must not read its parameter as one nobody supplied
        let sut = try Module(
            procedures: [
                "entry": Procedure(
                    signature: Signature(
                        parameters: [
                            "names": Parameter(type: .array(.string))
                        ]
                    ),
                    body: [
                        Statement(binding: .constant("many"), expression: .reference([.key("names"), .key("count")])
                        )
                    ],
                    result: .record([
                            "result": .reference([.key("many")])
                        ])
                )
            ]
        )

        // When
        let outputs = try await run(
            sut,
            arguments: ["names": .array([.string("a"), .string("b")])]
        )

        // Then
        #expect(outputs["result"] == .int(2))
    }

    @Test("what answers without running is worked out at link, not declared")
    func purityIsALinkFact() throws {
        // Given
        let sut = try Module(
            procedures: [
                "clean": Procedure(
                    body: [
                        Statement(binding: .constant("done"), expression: .literal(.int(1))
                        )
                    ]
                ),
                "dirty": Procedure(
                    body: [
                        Statement(binding: .constant("done"), expression: .dispatch(Dispatch(selector: "app.fail", arguments: [
                                        "recoverable": .literal(.bool(true))
                                    ]))
                        )
                    ]
                ),
                "entry": Procedure(
                    body: [
                        Statement(binding: .constant("a"), expression: .dispatch(Dispatch(selector: "clean"))
                        ),
                        Statement(binding: .constant("b"), expression: .dispatch(Dispatch(selector: "dirty"))
                        )
                    ]
                )
            ]
        )

        // When
        let image = try linker.link([sut] + Module.standard + [.failing], entry: entryName)

        // Then. `clean` computes; `dirty` reaches an effect, and everything
        // that reaches it goes with it
        #expect(image["clean"]?.purity == .pure)
        #expect(image["dirty"]?.purity != .pure)
        #expect(image["entry"]?.purity != .pure)
        #expect(image["std.collection.count"]?.purity == .pure)
    }

    @Test("a body that sends a word is still something a path may reach")
    func aBodyThatSendsIsStillPure() throws {
        // Given. Purity is judged over the name a body wrote, and what that
        // name means depends on where it was written. `label` sends `joined`,
        // which is pure, so `label` is pure and a path may reach it
        let label = Procedure(
            signature: Signature(
                receiver: "of",
                parameters: ["of": Parameter(type: .array(.string))],
                returns: .string
            ),
            body: [],
            result: .dispatch(Dispatch(receiver: reference("of"), selector: "std.text.joined"))
        )
        let sut = try Module(
            procedures: [
                "label": label,
                entryName: Procedure(
                    signature: Signature(
                        parameters: ["names": Parameter(type: .array(.string))]
                    ),
                    body: [],
                    result: reference("names", "label")
                )
            ]
        )

        // When
        let image = try linker.link([sut] + Module.standard, entry: entryName)

        // Then
        #expect(image["label"]?.purity == .pure)
        #expect(image["label"]?.isDerivable == true)
    }

    @Test("a procedure someone wrote is reachable from a path")
    func writtenProcedureIsReachableFromAPath() async throws {
        // Given. This is what unifying bought. `summarize` is a body, not
        // native, and `${tasks.summarize}` reaches it because the link proved
        // it answers without running.
        let sut = try Module(
            procedures: [
                "entry": Procedure(
                    signature: Signature(
                        parameters: [
                            "tasks": Parameter(type: .array(.string))
                        ]
                    ),
                    body: [
                        Statement(binding: .constant("said"), expression: .reference([.key("tasks"), .key("summarize")])
                        )
                    ],
                    result: .record([
                            "result": .reference([.key("said")])
                        ])
                ),
                "summarize": Procedure(
                    signature: Signature(
                        receiver: "of",
                        parameters: [
                            "of": Parameter(type: .array(.string))
                        ],
                        returns: .string
                    ),
                    body: [
                        Statement(binding: .constant("how_many"), expression: .reference([.key("of"), .key("count")])
                        ),
                        Statement(binding: .constant("line"), expression: interpolated(
                                spelling(reference("how_many")),
                                literal(" tasks")
                            )
                        )
                    ],
                    result: .reference([.key("line")])
                )
            ]
        )

        // When
        let outputs = try await run(
            sut,
            arguments: ["tasks": .array([.string("a"), .string("b"), .string("c")])]
        )

        // Then
        #expect(outputs["result"] == .string("3 tasks"))
    }

    @Test("a body that reaches an effect is not reachable from a path")
    func impureProcedureIsNotReachableFromAPath() throws {
        // Given. The proof is what opens the path, so losing it closes it
        let sut = try Module(
            procedures: [
                "entry": Procedure(
                    signature: Signature(
                        parameters: [
                            "tasks": Parameter(type: .array(.string))
                        ]
                    ),
                    body: [
                        Statement(binding: .constant("said"), expression: .literal(.string("nothing reaches it"))
                        )
                    ]
                ),
                "summarize": Procedure(
                    signature: Signature(
                        receiver: "of",
                        parameters: [
                            "of": Parameter(type: .array(.string))
                        ]
                    ),
                    body: [
                        Statement(binding: .constant("boom"), expression: .dispatch(Dispatch(selector: "app.fail", arguments: [
                                        "recoverable": .literal(.bool(false))
                                    ]))
                        )
                    ]
                )
            ]
        )

        // When
        let image = try linker.link([sut] + Module.standard + [.failing], entry: entryName)

        // Then
        #expect(image["summarize"]?.purity != .pure)

        // And a path that writes the word finds no word to send
        let reaching = try Module(
            procedures: [
                "entry": Procedure(
                    signature: Signature(parameters: ["tasks": Parameter(type: .array(.string))]),
                    body: [],
                    result: .reference([.key("tasks"), .key("summarize")])
                ),
                "summarize": try #require(sut.procedures["summarize"])
            ]
        )

        #expect {
            try linker.link([reaching] + Module.standard + [.failing], entry: entryName)
        } throws: { error in
            "\(error)".contains("summarize")
        }
    }

    @Test("a path to a body that reaches an effect is refused before any run")
    func aPathToAnImpureProcedureIsRefused() throws {
        // Given. The same shape, reached
        let sut = try Module(
            procedures: [
                "entry": Procedure(
                    signature: Signature(
                        parameters: [
                            "tasks": Parameter(type: .array(.string))
                        ]
                    ),
                    body: [
                        Statement(binding: .constant("said"), expression: .reference([.key("tasks"), .key("summarize")])
                        )
                    ]
                ),
                "summarize": Procedure(
                    signature: Signature(
                        receiver: "of",
                        parameters: [
                            "of": Parameter(type: .array(.string))
                        ]
                    ),
                    body: [
                        Statement(binding: .constant("boom"), expression: .dispatch(Dispatch(selector: "app.fail", arguments: [
                                        "recoverable": .literal(.bool(false))
                                    ]))
                        )
                    ]
                )
            ]
        )

        // When / Then
        #expect(throws: LinkError.self) {
            try linker.link([sut] + Module.standard + [.failing], entry: entryName)
        }
    }

    @Test("a word reached from a path is checked against the receiver it declared")
    func aPathChecksTheReceiver() async throws {
        // Given. The receiver's declared type is what makes the dot a send: the
        // link reads `array<any>`, finds no field there, and judges the word
        // against the receiver it declared
        let sut = try Module(
            procedures: [
                "entry": Procedure(
                    signature: Signature(
                        parameters: [
                            "subject": Parameter(type: .array(.any))
                        ]
                    ),
                    body: [],
                    result: .reference([.key("subject"), .key("size")])
                ),
                "size": Procedure(
                    signature: Signature(
                        receiver: "of",
                        parameters: [
                            "of": Parameter(type: .array(.any))
                        ],
                        returns: .int
                    ),
                    body: [],
                    result: .reference([.key("of"), .key("count")])
                )
            ]
        )

        // When
        let answered = try await run(sut, arguments: ["subject": .array([.string("a")])])

        // Then
        #expect(answered == .int(1))
    }

    @Test("a dot on an undeclared shape reads data alone")
    func aDotOnAnyDoesNotReachAWord() async throws {
        // Given. Nothing is known about `any`, so nothing is rewritten: the dot
        // stays a read, and a value without fields refuses it at run even
        // though a word by that name exists. A word on an undeclared value is
        // reached by declaring the value.
        let sut = try Module(
            procedures: [
                "entry": Procedure(
                    signature: Signature(
                        parameters: [
                            "subject": Parameter(type: .any)
                        ]
                    ),
                    body: [],
                    result: .reference([.key("subject"), .key("size")])
                ),
                "size": Procedure(
                    signature: Signature(
                        receiver: "of",
                        parameters: [
                            "of": Parameter(type: .array(.any))
                        ],
                        returns: .int
                    ),
                    body: [],
                    result: .reference([.key("of"), .key("count")])
                )
            ]
        )

        // When / Then
        await #expect(throws: (any Error).self) {
            try await run(sut, arguments: ["subject": .array([.string("a")])])
        }
    }

    @Test("a word reached from a path takes the defaults it declared")
    func aPathAppliesDefaults() async throws {
        // Given
        let sut = try Module(
            procedures: [
                "entry": Procedure(
                    signature: Signature(
                        parameters: [
                            "subject": Parameter(type: .array(.string))
                        ]
                    ),
                    body: [],
                    result: .reference([.key("subject"), .key("label")])
                ),
                "label": Procedure(
                    signature: Signature(
                        receiver: "of",
                        parameters: [
                            "of": Parameter(type: .array(.any)),
                            "prefix": Parameter(type: .string, default: .string("size"))
                        ],
                        returns: .string
                    ),
                    body: [
                        Statement(binding: .constant("many"), expression: .reference([.key("of"), .key("count")])
                        )
                    ],
                    result: interpolated(
                        spelling(reference("prefix")),
                        literal(": "),
                        spelling(reference("many"))
                    )
                )
            ]
        )

        // When
        let answered = try await run(
            sut,
            arguments: ["subject": .array([.string("a"), .string("b")])]
        )

        // Then
        #expect(answered == .string("size: 2"))
    }

    @Test("a word that refuses mid-path says why, rather than reading as absence")
    func aRefusalInAPathIsNotAbsence() async throws {
        // Given. `floored` takes a double and then finds no whole answer in it:
        // a fraction that is not a number has nothing to floor. That is not the
        // word declining the shape, so reporting nothing was there would report
        // the one thing known to be false.
        let sut = reference("x", "floored")

        // When / Then
        await #expect {
            try await answer(
                of: [Statement(binding: .constant("probe"), expression: sut)],
                result: reference("probe"),
                arguments: ["x": .double(.nan)],
                signature: Signature(parameters: ["x": Parameter(type: .double)])
            )
        } throws: { error in
            "\(error)".contains("no whole answer")
        }
    }

    @Test("a word that answers never is not something a path may reach")
    func neverIsNotDerivable() {
        // Given. A walk decides on its own whether to send what it reaches, and
        // leaving is not a decision a walk gets to make quietly
        let sut = Module.control.procedures["std.control.abort"]

        // When / Then
        #expect(sut?.signature.isDerivable(in: TypeTable()) == false)
    }
}
