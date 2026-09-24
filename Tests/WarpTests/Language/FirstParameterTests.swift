//
//  FirstParameterTests.swift
//  WarpTests
//
//  Created by JSilver on 8/17/26.
//

import Foundation
import Testing
@testable import Warp

// What a procedure is about is its first parameter, declared and filled the way
// every other one is, and a procedure taking one is a declaration like any other.
// It is not reserved for native code.
@Suite("What a declaration is about is its first parameter")
struct FirstParameterTests {
    // MARK: - Property
    private let builder = Builder()

    // MARK: - Lifecycle
    // MARK: - Test
    @Test("a first argument is read by the name the signature gave it")
    func firstArgumentIsANamedParameter() async throws {
        // Given
        let sut = try Module(
            procedures: [
                "entry": Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            Parameter(name: "procedure", type: .string)
                        ]
                    ),
                    body: [
                        Statement(binding: .constant("said"), expression: .call(Call(selector: "shout", arguments: [.reference([.key("procedure")])]))
                        )
                    ],
                    result: .record([
                            "result": .reference([.key("said")])
                        ])
                ),
                "shout": Procedure(
                    signature: Signature(
                        parameters: [
                            Parameter(name: "of", type: .string)
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

    @Test("a native procedure reads its first argument by the parameter's own key")
    func firstArgumentIsReadByItsKey() async throws {
        // Given
        let sut = try Module(
            procedures: [
                "entry": Procedure(
                    access: .public,
                    body: [],
                    result: .record([
                        "result": .call(Call(selector: "app.echo", arguments: [.literal(.int(20))]))
                    ])
                ),
                "app.echo": Procedure(
                    signature: Signature(of: EchoQuery.self, returns: .int),
                    implementation: .query(EchoQuery())
                )
            ]
        )

        // When
        let outputs = try await run(sut)

        // Then
        #expect(outputs["result"] == .int(20))
    }

    @Test("a native procedure and a written one are declared the same way")
    func nativeAndWrittenDeclareAlike() async throws {
        // Given
        let written = try Module(
            procedures: [
                "entry": Procedure(
                    access: .public,
                    body: [
                        Statement(binding: .constant("done"), expression: .literal(.string("end"))
                        )
                    ]
                ),
                "shout": Procedure(
                    signature: Signature(
                        parameters: [
                            Parameter(name: "of", type: .string)
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
        let image = try await builder.build([written] + Module.standard)

        // Then. One table, and what separates them is only how each is written
        let shout = try #require(image["shout"])
        let count = try #require(image["std.collection.count"])

        #expect(shout.signature.names.first == "of")
        #expect(count.signature.names.first == "collection")
        #expect(shout.isWritten)
        #expect(!count.isWritten)
    }

    @Test("a call fills a required first parameter by the argument at its position")
    func firstArgumentSuppliesItsParameter() async throws {
        // Given. The argument stands at the first parameter's position, so the
        // builder must not read that parameter as one nobody supplied
        let sut = try Module(
            procedures: [
                "entry": Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            Parameter(name: "names", type: .array(.string))
                        ]
                    ),
                    body: [
                        Statement(
                            binding: .constant("many"),
                            expression: .call(Call(selector: "std.collection.count", arguments: [reference("names")]))
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
                        Statement(binding: .constant("done"), expression: .call(Call(
                            selector: "app.fail",
                            arguments: [.literal(.bool(true))]
                        ))
                        )
                    ]
                ),
                "entry": Procedure(
                    access: .public,
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
        let image = try await builder.build([sut] + Module.standard + [.failing])

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
                parameters: [Parameter(name: "of", type: .array(.string))],
                returns: .string
            ),
            body: [],
            result: .call(Call(selector: "std.text.joined", arguments: [reference("of"), .literal(.string(""))]))
        )
        let sut = try Module(
            procedures: [
                "label": label,
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [Parameter(name: "names", type: .array(.string))]
                    ),
                    body: [],
                    result: .call(Call(selector: "label", arguments: [reference("names")]))
                )
            ]
        )

        // When
        let image = try await builder.build([sut] + Module.standard)

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
                    access: .public,
                    signature: Signature(
                        parameters: [
                            Parameter(name: "subject", type: .any)
                        ]
                    ),
                    body: [],
                    result: .reference([.key("subject"), .key("size")])
                ),
                "size": Procedure(
                    signature: Signature(
                        parameters: [
                            Parameter(name: "of", type: .array(.any))
                        ],
                        returns: .int
                    ),
                    body: [],
                    result: .call(Call(selector: "std.collection.count", arguments: [reference("of")]))
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            "\(error)".contains("reads a dot on any, which declares nothing")
        }
    }
}

// Answers what it was sent, read by the first parameter's own key.
private struct EchoQuery: Query {
    enum Parameters: Int, ParameterSet {
        case of

        var declared: Parameter { Parameter(name: "of", type: .int) }
    }

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func evaluate(_ question: Question<Self>) async throws -> Value? {
        question[.of]
    }

    // MARK: - Private
}
