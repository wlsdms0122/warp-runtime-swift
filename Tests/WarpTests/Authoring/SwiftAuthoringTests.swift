//
//  SwiftAuthoringTests.swift
//  WarpTests
//
//  Created by JSilver on 8/16/26.
//

import Testing
@testable import Warp
import WarpStandard

// The kernel's own acceptance test: a procedure written in Swift, run without a
// front end. Nothing here spells a keyword (no `"loop"`, no `"steps"`, no path
// string) because a caller that reaches for `import Warp` is writing the IR,
// not a document about it. If a construct cannot be reached from here, it is
// only reachable through a notation, and the notation has become the language.
@Suite("Authoring a procedure in Swift")
struct SwiftAuthoringTests {
    // MARK: - Lifecycle
    // MARK: - Test
    @Test("hello world needs no front end")
    func helloWorld() async throws {
        // Given
        let builder = Builder()
        let procedure = Procedure(
            body: [
                Statement(binding: .constant("greet"), expression: .literal(.string("hello, world")))
            ],
            result: .record(["greeting": .reference([.key("greet")])])
        )

        // When
        let image = try await builder.build(
            [try Module(procedures: ["greet": procedure.with(access: .public)]), .shouting] + Module.standard
        )
        let outputs = try await Executor().run(image, entry: "greet")

        // Then
        #expect(outputs["greeting"] == .string("hello, world"))
    }

    @Test("control flow and the signature are reachable from Swift alone")
    func controlFlow() async throws {
        // Given
        let builder = Builder()
        let index = Expression.reference([.key("counted"), .key("index")])
        let procedure = Procedure(
            signature: Signature(parameters: ["rounds": Parameter(type: .int)]),
            body: [
                Statement(binding: .constant("counted"), expression: .loop(
                        while: differs(
                            index,
                            .reference([.key("rounds")])
                            ),
                        body: Block(
                            body: [Statement(binding: .constant("tick"), expression: index)],
                            result: index
                        ),
                        round: "counted"
                    )
                ),
                Statement(binding: .variable("verdict"), expression: .literal(.string("counted otherwise"))
                ),
                Statement(
                    expression: .conditional(
                        equals(
                            .reference([.key("counted")]),
                            .literal(.int(3))
                            ),
                        then: [
                            Statement(binding: .assignment([.key("verdict")]), expression: .literal(.string("counted to three"))
                            )
                        ],
                        else: nil
                    )
                )
            ],
            result: .record(["verdict": .reference([.key("verdict")])])
        )

        // When Comparing is a procedure, so this links the bundle that declares
        // one, and the bundles that bundle leans on. The control flow beside it
        // needs nothing.
        let image = try await builder.build(
            [try Module(procedures: ["entry": procedure.with(access: .public)])]
                + Module.logic + Module.math + Module.collection + Module.foundation
        )
        let outputs = try await Executor().run(
            image,
            arguments: ["rounds": .int(3)]
        )

        // Then
        #expect(outputs["verdict"] == .string("counted to three"))
    }

    @Test("a native effect needs no decoder to run")
    func hostEffectWithoutDecoder() async throws {
        // Given
        let builder = Builder()
        let procedure = Procedure(
            body: [
                Statement(binding: .constant("shout"), expression: .call(
                        Call(
                            selector: "app.shout",
                            arguments: ["text": .literal(.string("hey"))]
                        )
                    )
                )
            ],
            result: .record(["shout": .reference([.key("shout")])])
        )

        // When
        let image = try await builder.build(
            [try Module(procedures: ["greet": procedure.with(access: .public)]), .shouting] + Module.standard
        )
        let outputs = try await Executor().run(image, entry: "greet")

        // Then
        #expect(outputs["shout"] == .string("HEY"))
    }

    @Test("a library procedure, a native procedure and a procedure are all one expression")
    func oneCallingType() async throws {
        // Given. Three selectors that are answered in three different places,
        // written identically. Where each is found is the runtime's business.
        let builder = Builder()
        let procedure = Procedure(
            body: [
                Statement(binding: .constant("names"), expression: .literal(.array([.string("a")]))),
                Statement(binding: .constant("counted"), expression: .call(
                        Call(receiver: .reference([.key("names")]), selector: "std.collection.count")
                    )
                ),
                Statement(binding: .constant("shouted"), expression: .call(
                        Call(selector: "app.shout", arguments: ["text": .literal(.string("hi"))])
                    )
                ),
                Statement(binding: .constant("called"), expression: .call(
                        Call(selector: "echo", arguments: ["procedure": .literal(.string("yo"))])
                    )
                )
            ],
            result: .record([
                "counted": .reference([.key("counted")]),
                "shouted": .reference([.key("shouted")]),
                "called": .reference([.key("called"), .key("said")])
            ])
        )
        // A second declaration, in the same module. A call names a symbol, and
        // which module declared it is the builder's business.
        let echo = Procedure(
            signature: Signature(
                parameters: ["procedure": Parameter(type: .string)],
                returns: .record(["said": .string])
            ),
            body: [],
            result: .record(["said": .reference([.key("procedure")])])
        )

        // When
        let image = try await builder.build(
            [try Module(procedures: ["speak": procedure.with(access: .public), "echo": echo]), .shouting] + Module.standard
        )
        let outputs = try await Executor().run(image, entry: "speak")

        // Then
        #expect(outputs["counted"] == .int(1))
        #expect(outputs["shouted"] == .string("HI"))
        #expect(outputs["called"] == .string("yo"))
    }
}

// A procedure written in Swift and never taught to a document to spell. It conforms
// to `Effect` and to nothing else. The proof that the run path asks for no
