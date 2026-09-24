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

// `call:` names a symbol, never a document. Naming the document would write a
// linkage fact into the call site, which is the one thing call decided an
// author should never have to write.
@Suite
struct CallTests {
    // MARK: - Property
    private let loader = Loader.testing

    // MARK: - Initializer
    // MARK: - Test
    @Test("the callee signature settles inputs at the call boundary, a null handed reading null")
    func calleeSignatureSettlesInputs() async throws {
        // Given
        let sut = try loader.loadDocument([
            "procedures": [
                "caller": [
                    "body": [
                        [
                            "let": "call",
                            "value": ["call": ["procedure": "callee", "arguments": [41, .null]]
                        ]]
                    ],
                    "result": ["result": ["ref": "call.pair"]]
                ],
                "callee": [
                    "parameters": [["name": "base", "type": "int"], ["name": "bump", "type": "int?"]],
                    "body": [
                        [
                            "let": "echo",
                            "value": ["base": ["ref": "base"], "bump": ["ref": "bump"]]
                        ]
                    ],
                    "result": ["pair": ["ref": "echo"]],
                    "returns": ["pair": ["base": "int", "bump": "int?"]]
                ]
            ]
        ])

        // When
        let outputs = try await run(sut, entry: "caller")

        // Then. `bump` declares null, so the null handed reads null at the
        // callee boundary
        #expect(outputs["result"] == .dictionary(["base": .int(41), "bump": .null]))
    }

    @Test("a constant argument violating the callee signature is rejected at link")
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
                    "parameters": [["name": "base", "type": "int"]],
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
                    "body": [["let": "call", "value": ["call": ["procedure": "some-other-file.greet"]]]],
                    "result": ["result": ["ref": "call.said"]]
                ]
            ]
        ])
        let elsewhere = try loader.loadDocument([
            "procedures": [
                "some-other-file.greet": [
                    "body": [["let": "procedure", "value": "hello"]],
                    "result": ["said": ["ref": "procedure"]],
                    "returns": ["said": "string"]
                ]
            ]
        ])

        // When
        let outputs = try await run([caller, elsewhere], entry: "caller")

        // Then
        #expect(outputs["result"] == .string("hello"))
    }

    @Test("a call writes what a procedure is about as its first argument")
    func callWritesItsSubjectFirst() async throws {
        // Given. What a procedure is about is its first parameter, filled the
        // way every other one is, so a document is not forced through
        // `x.shout` to hand it over
        let sut = try loader.loadDocument([
            "imports": ["std.text.joined", "std.text.text"],
            "procedures": [
                "entry": [
                    "parameters": [["name": "procedure", "type": "string"]],
                    "body": [
                        [
                            "let": "said",
                            "value": ["call": ["procedure": "shout", "arguments": [["ref": "procedure"]]]
                        ]]
                    ],
                    "result": ["result": ["ref": "said"]]
                ],
                "shout": [
                    "parameters": [["name": "of", "type": "string"]],
                    "returns": "string",
                    "body": [],
                    "result": ["format": "${of}!", "with": ["of": ["ref": "of"]]]
                ]
            ]
        ])

        // When
        let outputs = try await run(sut, arguments: ["procedure": .string("hey")])

        // Then
        #expect(outputs["result"] == .string("hey!"))
    }

    @Test("a call carries values only, and a blocks key has no meaning to refuse quietly")
    func aBlocksKeyIsRefusedAtDecode() {
        // Given. A body a procedure is to run travels as a closure argument, so
        // `blocks:` names nothing. An unknown key is refused where it is
        // written rather than dropped.
        let sut: Value = [
            "procedures": [
                "entry": [
                    "body": [
                        [
                            "let": "walked",
                            "value": ["call": [
                                "procedure": "helper",
                                "blocks": ["body": ["body": [["let": "step", "value": 1]]]]
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
            "\(error)".contains("blocks")
        }
    }

    @Test("runaway recursive calls end by caller cancellation")
    func recursiveCallStopsOnCancellation() async throws {
        // Given. The kernel carries no recursion guard (a reappearing name is
        // not a cycle oracle); runaway calls end by caller cancellation, which
        // must propagate through the call chain
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
        await #expect(throws: (any Error).self) {
            try await task.value
        }
    }
}
