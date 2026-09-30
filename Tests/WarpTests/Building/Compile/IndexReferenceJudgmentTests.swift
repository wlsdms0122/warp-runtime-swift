//
//  IndexReferenceJudgmentTests.swift
//  WarpTests
//
//  Created by JSilver on 8/23/26.
//

import Foundation
import Testing
@testable import Warp

// The dot judged behind an index reference. The walk continues through `[i]`
// the way it does through `[0]`, so nothing after one escapes the build.
@Suite
struct IndexReferenceJudgmentTests {
    // MARK: - Property
    private let builder = Builder()
    private let entryName: Name = "entry"

    // MARK: - Initializer
    // MARK: - Test
    @Test("a constant does not run a body its own document declares")
    func aConstantDoesNotRunAWrittenBody() async throws {
        // Given. `shout` has a written body, still being resolved beside the
        // constants it may read; a constant that runs it is a cycle with no
        // start, refused out loud
        let sut = try Module(
            constants: [
                "loud": .call(Call(selector: "shout", arguments: [.literal(.string("hi"))]))
            ],
            procedures: [
                "shout": Procedure(
                    signature: Signature(
                        parameters: [Parameter(name: "of", type: .string)],
                        returns: .string
                    ),
                    body: [],
                    result: .reference([.key("of")])
                ),
                entryName: Procedure(
                    access: .public,
                    signature: Signature(),
                    body: [],
                    result: .reference([.key("loud")])
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("a circle with no start")
        }
    }

    @Test("a body's constant-headed call runs a written procedure, resolved")
    func aBodyFoldsThroughAWrittenProcedure() async throws {
        // Given. The constants are settled and the procedures resolved by the time a
        // body folds, so a constant-headed call may run a written procedure: the
        // cycle the settling refuses is the constants' own
        let sut = try Module(
            constants: ["greeting": .literal(.string("hi"))],
            procedures: [
                "shout": Procedure(
                    signature: Signature(
                        parameters: [Parameter(name: "of", type: .string)],
                        returns: .int
                    ),
                    body: [],
                    result: .call(Call(selector: "std.collection.count", arguments: [reference("of")]))
                ),
                entryName: Procedure(
                    access: .public,
                    signature: Signature(returns: .int),
                    body: [],
                    result: .call(Call(selector: "shout", arguments: [reference("greeting")]))
                )
            ]
        )

        // When / Then. Folded at the build to the value the resolved body
        // answers
        #expect(try await run(sut) == .int(2))
    }

    @Test("whether a body links is its own text's fact, whoever calls it")
    func linkabilityDoesNotDependOnCallers() async throws {
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
                result: .call(Call(selector: "std.collection.count", arguments: [reference("of")]))
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

        // When / Then. Links and answers, `loud` present or not
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

    @Test("a closure parameter may not take a constant's name")
    func aClosureParameterDoesNotShadowAConstant() throws {
        // Given. Compiling folds a constant wherever its name is read, so a
        // closure parameter under that name would never be the one that
        // answers; refused where the top-level signature's is
        let procedure = Procedure(
            signature: Signature(),
            body: [
                Statement(binding: .constant("f"), expression: .closure(Procedure(
                        signature: Signature(
                            parameters: [Parameter(name: "greeting", type: .string)]
                        ),
                        body: [],
                        result: .reference([.key("greeting")])
                    ))
                )
            ],
            result: .literal(.int(1))
        )

        // When / Then. There is no such module to hand anywhere: making one is
        // what refuses
        #expect {
            try Module(
                constants: ["greeting": .literal(.string("hi"))],
                procedures: [entryName: procedure]
            )
        } throws: { error in
            "\(error)".contains("take the place of")
        }
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
                        selector: "std.text.uppercased",
                        arguments: [.literal(.string("a")), .literal(.bool(true))]
                    ))
                ))
            ],
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(),
                    body: [],
                    result: .reference([.key("f")])
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("sending 'std.text.uppercased' 2 arguments, and it takes 1")
        }
    }

    @Test("a constant index inside an index reference folds, however deep")
    func nestedConstantIndexReferencesFold() async throws {
        // Given. `items[names[C]]`: the inner index reads a constant, and no
        // constant name survives into the image at any depth
        let sut = try Module(
            constants: ["C": .literal(.int(0))],
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            Parameter(name: "items", type: .array(.string)),
                            Parameter(name: "names", type: .array(.int))
                        ],
                        returns: .string
                    ),
                    body: [],
                    result: .reference([
                        .key("items"),
                        .indexRef([.key("names"), .indexRef([.key("C")])])
                    ])
                )
            ]
        )

        // When / Then
        #expect(
            try await run(
                sut,
                arguments: [
                    "items": .array([.string("a"), .string("b")]),
                    "names": .array([.int(1)])
                ]
            ) == .string("b")
        )
    }

    @Test("an undeclared field behind an index reference refuses at the build")
    func anUndeclaredFieldBehindAnIndexReferenceRefuses() async throws {
        // Given. The element type is known whatever the index is, so the absent
        // field is the build's to refuse
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            Parameter(name: "i", type: .int),
                            Parameter(name: "items", type: .array(.record(["id": .string])))
                        ]
                    ),
                    body: [],
                    result: .reference([
                        .key("items"),
                        .indexRef([.key("i")]),
                        .key("nope")
                    ])
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("does not declare")
        }
    }

    @Test("an index reference that provably is not a number refuses at the build")
    func anIndexReferenceReadingIsJudged() async throws {
        // Given. `name` is text, and an index is a whole number; the text
        // proves the defect, so the build refuses it
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            Parameter(name: "items", type: .array(.string)),
                            Parameter(name: "name", type: .string)
                        ]
                    ),
                    body: [],
                    result: .reference([.key("items"), .indexRef([.key("name")])])
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("expected int")
        }
    }

    @Test("a const body nobody reaches still has its sends checked")
    func anUnreachedConstBodyIsChecked() async throws {
        // Given. `shout` is derivable, so its body lands in the image and runs
        // whenever a path reaches it; a call it writes wrongly is the build's to
        // refuse whether or not the entry ever mentions it
        let sut = try Module(
            procedures: [
                "shout": Procedure(
                    signature: Signature(
                        parameters: [Parameter(name: "of", type: .string)],
                        returns: .string
                    ),
                    body: [],
                    result: .call(Call(
                        selector: "std.text.uppercased",
                        arguments: [.reference([.key("of")]), .literal(.bool(true))]
                    ))
                ),
                entryName: Procedure(
                    access: .public,
                    signature: Signature(),
                    body: [],
                    result: .literal(.int(1))
                )
            ]
        )

        // When / Then. `uppercased` takes one argument and is sent two
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("sending 'std.text.uppercased' 2 arguments, and it takes 1")
        }
    }

    @Test("an index reference into what is not an array refuses like an index")
    func anIndexReferenceNeedsAnArray() async throws {
        // Given
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            Parameter(name: "i", type: .int),
                            Parameter(name: "text", type: .string)
                        ]
                    ),
                    body: [],
                    result: .reference([.key("text"), .indexRef([.key("i")])])
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("only an array or a dictionary is indexed")
        }
    }

    // MARK: - Public
    // MARK: - Private
}
