//
//  NamelessTests.swift
//  WarpSyntaxTests
//
//  Created by JSilver on 8/22/26.
//

import Foundation
import Testing
@testable import Warp
@testable import WarpSyntax
import WarpStandard

// A statement with no naming key: the construct runs and the answer is dropped,
// which is how an effect is asked for on its own. The other half of the same
// decision is that a leaving statement takes no name at all. It never finishes,
// so its name could never bind.
@Suite("A statement without a name")
struct NamelessTests {
    // MARK: - Property
    private let loader = Loader.testing

    // MARK: - Initializer
    // MARK: - Test
    @Test("a nameless statement runs and its answer is dropped")
    func aNamelessStatementRunsForItsEffect() async throws {
        // Given. A call whose answer nothing keeps, then an answer of its own
        let sut = try loader.loadDocument([
            "imports": ["std.math.plus"],
            "procedures": [
                "entry": [
                    "returns": "int",
                    "body": [
                        ["value": ["call": ["procedure": "std.math.plus", "of": 1, "arguments": ["value": 2]]]],
                        ["let": "kept", "value": 5]
                    ],
                    "result": ["ref": "kept"]
                ]
            ]
        ])

        // When / Then
        #expect(try await answer(sut) == .int(5))
    }

    @Test("a nameless statement binds nothing a later statement could read")
    func aNamelessStatementBindsNothing() {
        // Given. The dropped answer is dropped, not bound under some invented
        // name a reference could reach; the reference resolves nowhere and the
        // reading says so
        #expect {
            try loader.loadDocument([
                "procedures": [
                    "entry": [
                        "body": [
                            ["value": 1]
                        ],
                        "result": ["ref": "_"]
                    ]
                ]
            ])
        } throws: { error in
            "\(error)".contains("not visible")
        }
    }

    @Test("two naming keys are refused")
    func twoNamingKeysAreRefused() async {
        await #expect(throws: ReadingError.self) {
            try await loader.loadProcedure([
                "body": [["let": "one", "var": "another", "value": 1]]
            ])
        }
    }

    @Test("a named leaving statement is refused", arguments: [
        ["let": "done", "value": ["return": "answer"]] as Value,
        ["var": "gone", "value": ["break": Value.null]],
        ["set": "past", "value": ["continue": Value.null]]
    ])
    func aNamedLeavingStatementIsRefused(_ statement: Value) {
        // Given. A leaving statement never finishes, so a naming key on one
        // promises a binding that cannot happen
        #expect {
            try loader.loadProcedure(["body": [statement]])
        } throws: { error in
            "\(error)".contains("takes no name")
        }
    }

    @Test("a name on a conditional both of whose arms leave is refused at reading")
    func aNamedStructuralLeaveIsRefusedAtReading() {
        // Given. The leave rules reach through structure, and the reading sees
        // the structure: fragments read on their own pass through no
        // validation, so this is where the fact is caught for them
        #expect {
            try loader.statements(from: [
                [
                    "let": "done",
                    "value": ["conditional": [
                        "when": true,
                        "then": [["value": ["return": 1]]],
                        "else": [["value": ["return": 2]]]
                    ]
                ]]
            ])
        } throws: { error in
            "\(error)".contains("takes no name")
        }
    }

    @Test("a statement after one that leaves is refused at reading")
    func aTrailingStatementAfterALeaveIsRefusedAtReading() {
        // Given. Order is a fact only the sequence shows, so the sequence's
        // reading holds it: fragments pass through no validation, and the rule
        // must not wait for a link they may never reach
        #expect {
            try loader.statements(from: [
                ["value": ["return": 1]],
                ["let": "unreachable", "value": 2]
            ])
        } throws: { error in
            "\(error)".contains("would never run")
        }
    }

    @Test("a name on a leaving statement is refused for the leave, not for the name")
    func aLeavingStatementIsRefusedBeforeItsNameIsJudged() {
        // Given (a caller assembling statements directly, with a `set` naming a
        // leave: that the statement takes no name at all comes before any
        // question about which name it is) visibility included
        let statement = Statement(binding: .assignment([.key("past")]), expression: .leave(Leave(reach: .procedure, value: .literal(.int(1))))
        )

        #expect {
            try Validator().validate(body: [statement], visible: [])
        } throws: { error in
            "\(error)".contains("takes no name")
        }
    }

    @Test("a construct that binds through its name binds nothing when written nameless")
    func aBindingConstructWrittenNamelessBindsNothing() throws {
        // Given, a loop and an attempt with no naming key
        let module = try loader.loadProcedure(["body": [
            ["value": ["loop": ["while": false, "body": [["let": "x", "value": 1]]]]] as Value,
            ["value": ["attempt": ["body": [["let": "x", "value": 1]], "rescue": ["result": 0]]]]
        ]])

        // Then, each reads with no round and no failure to bind
        guard case let .body(block) = module.procedures[entryName]?.implementation else {
            Issue.record("expected a body")
            return
        }

        guard case let .loop(_, _, round) = block.body[0].expression,
              case let .attempt(_, _, failure) = block.body[1].expression else {
            Issue.record("expected a loop and an attempt")
            return
        }

        #expect(block.body.allSatisfy { statement in statement.binding == nil })
        #expect(round == nil)
        #expect(failure == nil)
    }

    @Test("a naming key holding null is a broken name, not a nameless statement")
    func aNullNameIsRefused() {
        // Given. A key written with no name in it: reading it as "no naming
        // key" would make a failed name and an omitted one the same document
        #expect(throws: ReadingError.self) {
            try loader.loadProcedure(["body": [["let": Value.null, "value": 1]]])
        }
    }

    @Test("a nameless statement written and read back is the same statement")
    func aNamelessStatementRoundTrips() async throws {
        // Given. The reader's set of legal documents and the writer's must be
        // one set; a document that reads but does not write back broke that
        let document: Value = [
            "imports": ["std.math.plus"],
            "procedures": [
                "entry": [
                    "returns": "int",
                    "body": [
                        ["value": ["call": ["procedure": "std.math.plus", "of": 1, "arguments": ["value": 2]]]],
                        ["let": "kept", "value": 5]
                    ],
                    "result": ["ref": "kept"]
                ]
            ]
        ]

        let loaded = try loader.loadDocument(document)
        let written = try Writer(registry: loader.registry).value(of: loaded)

        await #expect(try await Writer(registry: loader.registry).value(of: try loader.load(written)) == written)
    }

    // MARK: - Public
    // MARK: - Private
    private func answer(_ module: Module, _ arguments: [Name: Value] = [:]) async throws -> Value {
        let image = try await Builder().build([module] + Module.standard, entry: "entry")

        return try await Executor().run(image, arguments: arguments)
    }
}
