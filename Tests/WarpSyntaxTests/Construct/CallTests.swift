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
    @Test("the callee signature settles inputs at the call boundary")
    func calleeSignatureSettlesInputs() async throws {
        // Given
        let sut = try loader.loadDocument([
            "procedures": [
                "caller": [
                    "body": [
                        [
                            "let": "call",
                            "value": ["call": ["procedure": "callee", "arguments": ["base": 41]]
                        ]]
                    ],
                    "result": ["result": ["ref": "call.pair"]]
                ],
                "callee": [
                    "parameters": ["base": "int", "bump": ["type": "int", "default": 1]],
                    "body": [
                        [
                            "let": "echo",
                            "value": ["base": ["ref": "base"], "bump": ["ref": "bump"]]
                        ]
                    ],
                    "result": ["pair": ["ref": "echo"]],
                    "returns": ["pair": ["base": "int", "bump": "int"]]
                ]
            ]
        ])

        // When
        let outputs = try await run(sut, entry: "caller")

        // Then. The omitted `bump` settled to its default at the callee
        // boundary
        #expect(outputs["result"] == .dictionary(["base": .int(41), "bump": .int(1)]))
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
                            "value": ["call": ["procedure": "callee", "arguments": ["base": "not-a-number"]]
                        ]]
                    ]
                ],
                "callee": [
                    "parameters": ["base": "int"],
                    "body": [["let": "echo", "value": ["ref": "base"]]]
                ]
            ]
        ])

        // When / Then. Nothing runs: the argument is a constant, so its type is
        // knowable before the run and the refusal happens there
        await #expect(throws: BuildError.self) {
            try await Builder().build([sut], entry: "caller")
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

    @Test("a call writes what it is sent to")
    func callWritesItsReceiver() async throws {
        // Given. `call` reaches a receiver the same way a spelling does, so a
        // document is not forced through `x.shout` to send to one
        let sut = try loader.loadDocument([
            "imports": ["std.text.joined", "std.text.text"],
            "procedures": [
                "entry": [
                    "parameters": ["procedure": "string"],
                    "body": [
                        [
                            "let": "said",
                            "value": ["call": ["procedure": "shout", "of": ["ref": "procedure"]]
                        ]]
                    ],
                    "result": ["result": ["ref": "said"]]
                ],
                "shout": [
                    "receiver": "of",
                    "parameters": ["of": "string"],
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
            "procedures": ["loopy": ["body": [["let": "again", "value": ["call": ["procedure": "loopy"]]]]]]
        ])
        let image = try await Builder().build([module], entry: "loopy")
        let sut = Executor()

        // When
        let task = Task {
            try await sut.run(image)
        }

        try await Task.sleep(for: .milliseconds(50))
        task.cancel()

        // Then
        await #expect(throws: (any Error).self) {
            try await task.value
        }
    }
}
