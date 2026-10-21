//
//  CallTests.swift
//  WarpSyntaxTests
//
//  Created by JSilver on 8/9/26.
//

import Foundation
import Testing
@testable import Warp
@testable import WarpSyntax
import WarpTestSupport

// `call:` names a symbol, never a document. Naming the document would write a
// linkage fact into the call site, which is the one thing call decided an
// author should never have to write.
@Suite("A call names a symbol")
struct CallTests {
    // MARK: - Property
    private let loader = Loader.testing

    // MARK: - Initializer
    // MARK: - Test
    @Test("the callee signature holds inputs at the call, a null handed reading null")
    func calleeSignatureHoldsInputs() async throws {
        // Given
        let sut = try loader.loadDocument([
            "types": [
                "App.Pair": ["struct": ["base": "Int", "bump": "Int?"]],
                "App.Echo": ["struct": ["pair": "App.Pair"]]
            ],
            "procedures": [
                "caller": [
                    "returns": "Any",
                    "body": [
                        [
                            "let": "call",
                            "value": ["call": ["procedure": "callee", "arguments": [41, .null]]
                        ]],
                        ["value": ["return": ["dictionary": [["result", ["ref": "call.pair"]]]]]]
                    ]
                ],
                "callee": [
                    "parameters": [["name": "base", "type": "Int"], ["name": "bump", "type": "Int?"]],
                    "body": [
                        [
                            "let": "echo",
                            "type": "App.Pair",
                            "value": ["struct": ["base": ["ref": "base"], "bump": ["ref": "bump"]]]
                        ],
                        ["value": ["return": ["struct": ["pair": ["ref": "echo"]]]]]
                    ],
                    "returns": "App.Echo"
                ]
            ]
        ])

        // When
        let outputs = try await run(sut, entry: "caller")

        // Then. `bump` declares null, so the null handed reads null in the
        // callee
        #expect(outputs.map?["result"] == .struct(Struct(name: "App.Pair", ["base": .int(41), "bump": .null])))
    }

    @Test("a constant argument violating the callee signature is rejected at the build")
    func signatureViolationRejectsCall() async throws {
        // Given
        let sut = try loader.loadDocument([
            "procedures": [
                "caller": [
                    "body": [
                        [
                            "let": "call",
                            "value": ["call": ["procedure": "callee", "arguments": ["not-a-number"]]
                        ]]
                    ]
                ],
                "callee": [
                    "parameters": [["name": "base", "type": "Int"]],
                    "body": [["let": "echo", "value": ["ref": "base"]]]
                ]
            ]
        ])

        // When / Then. Nothing runs: the argument is a constant, so its type is
        // knowable before the run and the refusal happens there
        await #expect(throws: BuildError.self) {
            try await Builder().build([sut])
        }
    }

    @Test("a call names a procedure and not the document that declares it")
    func callNamesASymbol() async throws {
        // Given. The callee lives in a module the caller never mentions
        let caller = try loader.loadDocument([
            "imports": ["some-other-file.greet"],
            "procedures": [
                "caller": [
                    "returns": "Any",
                    "body": [["let": "call", "value": ["call": ["procedure": "some-other-file.greet"]]], ["value": ["return": ["dictionary": [["result", ["ref": "call.said"]]]]]]]
                ]
            ]
        ])
        let elsewhere = try loader.loadDocument([
            "types": ["App.Said": ["struct": ["said": "String"]]],
            "procedures": [
                "some-other-file.greet": [
                    "body": [["let": "word", "value": "hello"], ["value": ["return": ["struct": ["said": ["ref": "word"]]]]]],
                    "returns": "App.Said"
                ]
            ]
        ])

        // When
        let outputs = try await run([caller, elsewhere], entry: "caller")

        // Then
        #expect(outputs.map?["result"] == .string("hello"))
    }

    @Test("a call writes what a procedure is about as its first argument")
    func callWritesItsSubjectFirst() async throws {
        // Given. What a procedure is about is its first parameter, filled the
        // way every other one is, so a document is not forced through
        // `x.shout` to hand it over
        let sut = try loader.loadDocument([
            "imports": ["Standard.Text.joined", "Standard.Text.text"],
            "procedures": [
                "entry": [
                    "returns": "Any",
                    "parameters": [["name": "word", "type": "String"]],
                    "body": [
                        [
                            "let": "said",
                            "value": ["call": ["procedure": "shout", "arguments": [["ref": "word"]]]
                        ]],
                        ["value": ["return": ["dictionary": [["result", ["ref": "said"]]]]]]
                    ]
                ],
                "shout": [
                    "parameters": [["name": "of", "type": "String"]],
                    "returns": "String",
                    "body": [["value": ["return": ["format": "${of}!", "with": ["of": ["ref": "of"]]]]]]
                ]
            ]
        ])

        // When
        let outputs = try await run(sut, arguments: ["word": .string("hey")])

        // Then
        #expect(outputs.map?["result"] == .string("hey!"))
    }

    @Test("a key the call does not name is refused at the load")
    func anUnknownKeyIsRefusedAtTheLoad() {
        // Given. A call's keys are closed, so one it does not name is refused
        // where it is written.
        let sut: Value = [
            "procedures": [
                "entry": [
                    "body": [
                        [
                            "let": "walked",
                            "value": ["call": [
                                "procedure": "helper",
                                "mystery": 2
                            ]
                        ]]
                    ]
                ]
            ]
        ]

        // When / Then
        #expect {
            try loader.loadDocument(sut)
        } throws: { error in
            "\(error)".contains("mystery")
        }
    }

    @Test("runaway recursive calls end when the host cancels the run")
    func recursiveCallStopsOnCancellation() async throws {
        // Given. The kernel carries no recursion guard (a reappearing name is
        // not a cycle oracle); runaway calls end when the host cancels the run,
        // which must propagate through the call chain
        let module = try loader.loadDocument([
            "procedures": ["loopy": ["access": "public", "body": [["let": "again", "value": ["call": ["procedure": "loopy"]]]]]]
        ])
        let image = try await Builder().build([module])
        let sut = Executor()

        // When
        let task = Task {
            try await sut.run(image, entry: "loopy")
        }

        try await Task.sleep(for: .milliseconds(50))
        task.cancel()

        // Then
        await #expect(throws: CancellationError.self) {
            try await task.value
        }
    }

    // MARK: - Public
    // MARK: - Private
}
