//
//  ReceiverTests.swift
//  WarpTests
//
//  Created by JSilver on 8/17/26.
//

import Foundation
import Testing
@testable import Warp

// A receiver is a declared parameter, and a procedure a caller sends to one is a
// declaration like any other. It is not reserved for native code.
@Suite("A declaration may be sent to something")
struct ReceiverTests {
    // MARK: - Property
    private let builder = Builder()

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
                            "procedure": Parameter(type: .string)
                        ]
                    ),
                    body: [
                        Statement(binding: .constant("said"), expression: .call(Call(receiver: .reference([.key("procedure")]), selector: "shout"))
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
        let outputs = try await run(sut, arguments: ["procedure": .string("hey")])

        // Then
        #expect(outputs["result"] == .string("hey!"))
    }

    @Test("a native procedure and a written one are declared the same way")
    func nativeAndWrittenDeclareAlike() async throws {
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
                    ],
                    result: .reference([.key("loud")])
                )
            ]
        )

        // When
        let image = try await builder.build([written] + Module.standard, entry: entryName)

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
        // Given. The receiver is written in front of the selector, so the
        // builder must not read its parameter as one nobody supplied
        let sut = try Module(
            procedures: [
                "entry": Procedure(
                    signature: Signature(
                        parameters: [
                            "names": Parameter(type: .array(.string))
                        ]
                    ),
                    body: [
                        Statement(
                            binding: .constant("many"),
                            expression: .call(Call(receiver: reference("names"), selector: "std.collection.count"))
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
    func constnessIsALinkFact() async throws {
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
                        Statement(binding: .constant("done"), expression: .call(Call(selector: "app.fail", arguments: [
                                        "recoverable": .literal(.bool(true))
                                    ]))
                        )
                    ]
                ),
                "entry": Procedure(
                    body: [
                        Statement(binding: .constant("a"), expression: .call(Call(selector: "clean"))
                        ),
                        Statement(binding: .constant("b"), expression: .call(Call(selector: "dirty"))
                        )
                    ]
                )
            ]
        )

        // When
        let image = try await builder.build([sut] + Module.standard + [.failing], entry: entryName)

        // Then. `clean` computes; `dirty` reaches an effect, and everything
        // that reaches it goes with it
        #expect(image["clean"]?.constness == .const)
        #expect(image["dirty"]?.constness != .const)
        #expect(image["entry"]?.constness != .const)
        #expect(image["std.collection.count"]?.constness == .const)
    }

    @Test("a body that sends a const procedure is const")
    func aBodyThatSendsIsStillConst() async throws {
        // Given. Constness is judged over the name a body wrote, and what that
        // name means depends on where it was written. `label` sends `joined`,
        // which is const, so `label` is const
        let label = Procedure(
            signature: Signature(
                receiver: "of",
                parameters: ["of": Parameter(type: .array(.string))],
                returns: .string
            ),
            body: [],
            result: .call(Call(receiver: reference("of"), selector: "std.text.joined"))
        )
        let sut = try Module(
            procedures: [
                "label": label,
                entryName: Procedure(
                    signature: Signature(
                        parameters: ["names": Parameter(type: .array(.string))]
                    ),
                    body: [],
                    result: .call(Call(receiver: reference("names"), selector: "label"))
                )
            ]
        )

        // When
        let image = try await builder.build([sut] + Module.standard, entry: entryName)

        // Then
        #expect(image["label"]?.constness == .const)
    }

    @Test("a dot on an undeclared type is refused")
    func aDotOnAnyIsRefused() async throws {
        // Given. `any` declares no field, so the dot has nothing to read, and
        // a procedure by that name is reached by writing the call rather than by
        // the dot finding it.
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
                    result: .call(Call(receiver: reference("of"), selector: "std.collection.count"))
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard, entry: entryName)
        } throws: { error in
            "\(error)".contains("reads a dot on any, which declares nothing")
        }
    }
}
