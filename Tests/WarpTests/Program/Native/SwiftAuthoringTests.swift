//
//  SwiftAuthoringTests.swift
//  WarpTests
//
//  Created by JSilver on 8/16/26.
//

import Foundation
import Testing
@testable import Warp
import WarpStandard
import WarpTestSupport

// Procedures written in Swift and run without a front end.
@Suite("Authoring a procedure in Swift")
struct SwiftAuthoringTests {
    // Answers what it was sent, read by the first parameter's own key.
    private struct EchoQuery: Query {
        enum Parameters: Int, ParameterSet {
            case of

            // MARK: - Property
            var declared: Parameter { Parameter(name: "of", type: .int) }

            // MARK: - Initializer
            // MARK: - Public
            // MARK: - Private
        }

        // MARK: - Property
        // MARK: - Initializer
        // MARK: - Public
        func evaluate(_ question: Question<Self>) async throws -> Value {
            question[.of]
        }

        // MARK: - Private
    }

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("hello world needs no front end")
    func helloWorld() async throws {
        // Given
        let builder = Builder()
        let procedure = Procedure(
            signature: Signature(returns: .any),
            body: [
                Statement(binding: .constant("greet"), expression: .literal(.string("hello, world"))),
                returning(map(["greeting": .reference([.name("greet")])]))
            ]
        )

        // When
        let image = try await builder.build(
            [try Module(procedures: ["greet": procedure.with(access: .public)])] + Module.standard
        )
        let outputs = try await Executor().run(image, entry: "greet")

        // Then
        #expect(outputs.map?["greeting"] == .string("hello, world"))
    }

    @Test("control flow and the signature are reachable from Swift alone")
    func controlFlow() async throws {
        // Given
        let builder = Builder()
        let index = Expression.reference([.name("counted"), .name("index")])
        let procedure = Procedure(
            signature: Signature(parameters: [Parameter(name: "rounds", type: .int)], returns: .any),
            body: [
                Statement(binding: .variable("seen"), expression: .literal(.int(-1))),
                Statement(binding: .constant("counted"), expression: .loop(
                        while: differs(
                            index,
                            .reference([.name("rounds")])
                            ),
                        body: [Statement(binding: .assignment([.name("seen")]), expression: index)]
                    )
                ),
                Statement(binding: .variable("verdict"), expression: .literal(.string("counted otherwise"))),
                Statement(
                    expression: .conditional(
                        equals(
                            .reference([.name("seen")]),
                            .literal(.int(2))
                            ),
                        then: [
                            Statement(binding: .assignment([.name("verdict")]), expression: .literal(.string("counted to three")))
                        ],
                        else: nil
                    )
                ),
                returning(map(["verdict": .reference([.name("verdict")])]))
            ]
        )

        // When. Comparing is a procedure, so this builds with the bundle that
        // declares one, and the bundles that bundle leans on. The control flow
        // beside it needs nothing.
        let image = try await builder.build(
            [try Module(procedures: ["entry": procedure.with(access: .public)])]
                + Module.logic + Module.math + Module.collection + Module.sharedGround
        )
        let outputs = try await Executor().run(
            image,
            arguments: ["rounds": .int(3)]
        )

        // Then
        #expect(outputs.map?["verdict"] == .string("counted to three"))
    }

    @Test("a native effect needs no decoder to run")
    func hostEffectWithoutDecoder() async throws {
        // Given
        let builder = Builder()
        let procedure = Procedure(
            signature: Signature(returns: .any),
            body: [
                Statement(binding: .constant("shout"), expression: .call(
                    Call(selector: "App.shout", arguments: [.literal(.string("hey"))])
                )),
                returning(map(["shout": .reference([.name("shout")])]))
            ]
        )

        // When
        let image = try await builder.build(
            [try Module(procedures: ["greet": procedure.with(access: .public)]), .shouting] + Module.standard
        )
        let outputs = try await Executor().run(image, entry: "greet")

        // Then
        #expect(outputs.map?["shout"] == .string("HEY"))
    }

    @Test("a library procedure, a native procedure and a written one are all one expression")
    func oneCallingType() async throws {
        // Given. Three selectors that are answered in three different places,
        // written identically. Where each is found is the runtime's business.
        let builder = Builder()
        let procedure = Procedure(
            signature: Signature(returns: .any),
            body: [
                Statement(binding: .constant("names"), expression: .literal(.array([.string("a")]))),
                Statement(binding: .constant("counted"), expression: .call(
                    Call(selector: "Standard.Collection.count", arguments: [.reference([.name("names")])])
                )),
                Statement(binding: .constant("shouted"), expression: .call(
                    Call(selector: "App.shout", arguments: [.literal(.string("hi"))])
                )),
                Statement(binding: .constant("called"), expression: .call(
                    Call(selector: "echo", arguments: [.literal(.string("yo"))])
                )),
                returning(map([
                    "counted": .reference([.name("counted")]),
                    "shouted": .reference([.name("shouted")]),
                    "called": .reference([.name("called"), .name("said")])
                ]))
            ]
        )
        // A second declaration, in the same module. A call names a symbol, and
        // which module declared it is the builder's business.
        let echo = Procedure(
            signature: Signature(
                parameters: [Parameter(name: "text", type: .string)],
                returns: .named("App.Said")
            ),
            body: [returning(.struct(["said": .reference([.name("text")])]))]
        )

        // When
        let image = try await builder.build(
            [
                try Module(
                    types: ["App.Said": .struct(["said": .string])],
                    procedures: ["speak": procedure.with(access: .public), "echo": echo]
                ),
                .shouting
            ] + Module.standard
        )
        let outputs = try await Executor().run(image, entry: "speak")

        // Then
        #expect(outputs.map?["counted"] == .int(1))
        #expect(outputs.map?["shouted"] == .string("HI"))
        #expect(outputs.map?["called"] == .string("yo"))
    }

    @Test("a native procedure reads its first argument by the parameter's own key")
    func firstArgumentIsReadByItsKey() async throws {
        // Given
        let sut = try Module(
            procedures: [
                "entry": Procedure(
                    access: .public,
                    signature: Signature(returns: .any),
                    body: [
                        returning(map([
                            "result": .call(Call(selector: "App.echo", arguments: [.literal(.int(20))]))
                        ]))
                    ]
                ),
                "App.echo": Procedure(
                    signature: Signature(of: EchoQuery.self, returns: .int),
                    implementation: .query(EchoQuery())
                )
            ]
        )

        // When
        let outputs = try await run(sut)

        // Then
        #expect(outputs.map?["result"] == .int(20))
    }

    @Test("a native procedure and a written one are declared the same way")
    func nativeAndWrittenDeclareAlike() async throws {
        // Given
        let written = try Module(
            procedures: [
                "entry": Procedure(
                    access: .public,
                    body: [
                        Statement(binding: .constant("done"), expression: .literal(.string("end")))
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
                        Statement(binding: .constant("loud"), expression: .reference([.name("of")])),
                        returning(.reference([.name("loud")]))
                    ]
                )
            ]
        )

        // When
        let image = try await Builder().build([written] + Module.standard)

        // Then. One table, and what separates them is only how each is written
        let shout = try #require(image["shout"])
        let count = try #require(image["String.count"])

        #expect(shout.signature.names.first == "of")
        #expect(count.signature.names.first == "collection")
        #expect(shout.isWritten)
        #expect(!count.isWritten)
    }

    // MARK: - Public
    // MARK: - Private
}
