//
//  TypeTests.swift
//  WarpTests
//
//  Created by JSilver on 8/17/26.
//

import Foundation
import Testing
@testable import Warp

// A declaration says more about a list than that it is one. What composing types
// buys is that the refusal happens at the boundary, naming the element that
// disagreed, instead of somewhere inside the body.
@Suite("A type is an expression")
struct TypeTests {
    // MARK: - Lifecycle
    // MARK: - Test
    @Test("an array declares what it holds")
    func arrayDeclaresItsElement() throws {
        // Given
        let sut = TypeExpression.array(.string)

        // When
        let settled = try sut.settling(
            .array([.string("a"), .string("b")]),
            at: "names"
        )

        // Then
        #expect(settled == .array([.string("a"), .string("b")]))

        #expect(throws: ArgumentError.self) {
            try sut.settling(.array([.string("a"), .int(1)]), at: "names")
        }
    }

    @Test("a refusal names the element that disagreed")
    func refusalNamesTheElement() {
        // Given
        let sut = TypeExpression.array(.string)

        // When
        let error = #expect(throws: ArgumentError.self) {
            try sut.settling(.array([.string("a"), .int(1)]), at: "names")
        }

        // Then. The index is in the message, so the author knows which one
        #expect(error?.message.contains("names[1]") == true)
    }

    @Test("a record settles to the fields declared, and a value carrying more loses them")
    func recordDeclaresFields() throws {
        // Given. What arrives is data from outside, and a payload gains fields
        let sut = TypeExpression.record(["id": .string, "done": .bool])

        // When
        let settled = try sut.settling(
            .dictionary(["id": .string("a"), "done": .bool(true), "extra": .int(1)]),
            at: "task"
        )

        // Then
        #expect(settled["extra"] == nil)
        #expect(settled["id"] == .string("a"))

        #expect(throws: ArgumentError.self) {
            try sut.settling(.dictionary(["id": .string("a")]), at: "task")
        }
    }

    @Test("a name is identifiers joined by dots, and never a scalar's word", arguments: [
        ("Account", true), ("bank.Account", true), ("_x1", true),
        ("true", false), ("bank.null", true), ("", false), ("a..b", false), ("foo-bar", false), ("café", false)
    ])
    func aTypeNameIsIdentifiersJoinedByDots(name: String, holds: Bool) {
        #expect(((try? Name(name))?.isDeclarable ?? false) == holds)
    }

    @Test("an alias of a declared record names the record on either side")
    func anAliasNamesTheRecordItStandsFor() throws {
        // Given
        let types = TypeTable(types: ["Person": .record(["name": .string]), "Someone": .named("Person")])
        let sut = TypeExpression.named("Someone")

        // When
        let bare = try sut.settling(.dictionary(["name": .string("a")]), at: "who", in: types)
        let aliased = try sut.settling(.record(Record(name: "Someone", ["name": .string("a")])), at: "who", in: types)
        let named = try sut.settling(.record(Record(name: "Person", ["name": .string("a")])), at: "who", in: types)

        // Then. Every one settles under the record's own name
        #expect(bare == .record(Record(name: "Person", ["name": .string("a")])))
        #expect(aliased == bare)
        #expect(named == bare)
    }

    @Test("a named type resolves through the table it was declared in")
    func namedTypeResolves() throws {
        // Given
        let types = TypeTable(types: ["Task": .record(["id": .string])])
        let sut = TypeExpression.array(.named("Task"))

        // When
        let settled = try sut.settling(
            .array([.dictionary(["id": .string("a")])]),
            at: "tasks",
            in: types
        )

        // Then
        #expect(settled == .array([.record(Record(name: "Task", ["id": .string("a")]))]))

        #expect(throws: ArgumentError.self) {
            try sut.settling(.array([.dictionary(["id": .int(1)])]), at: "tasks", in: types)
        }
    }

    @Test("a type may name itself")
    func namedTypeMayRecur() throws {
        // Given. Kept rather than expanded at link, which is what makes a
        // self-naming shape a shape instead of a regress
        let types = TypeTable(
            types: ["Tree": .record(["value": .int, "children": .array(.named("Tree"))])]
        )
        let sut = TypeExpression.named("Tree")

        // When
        let settled = try sut.settling(
            .dictionary([
                "value": .int(1),
                "children": .array([.dictionary(["value": .int(2), "children": .array([])])])
            ]),
            at: "tree",
            in: types
        )

        // Then
        #expect(settled["value"] == .int(1))
    }

    @Test("the builder refuses a signature that names a shape nobody declared")
    func unknownTypeIsALinkError() throws {
        // Given
        let sut = try Module(
            procedures: [
                "entry": Procedure(
                    signature: Signature(
                        parameters: ["task": Parameter(type: .named("Nowhere"))]
                    ),
                    body: []
                )
            ]
        )

        // When / Then
        #expect(throws: LinkError.self) {
            try Builder().build([sut], entry: "entry")
        }
    }

    @Test("a type reads back in the spelling it was declared with")
    func typesRenderAsWritten() {
        #expect(TypeExpression.array(.string).rendered == "array<string>")
        #expect(TypeExpression.dictionary(.named("Task")).rendered == "dictionary<Task>")
        #expect(TypeExpression.array(.array(.int)).rendered == "array<array<int>>")
        #expect(TypeExpression.record(["b": .int, "a": .string]).rendered == "{ a: string, b: int }")
    }

    @Test("a call handed to a parameter it cannot fit is refused at link")
    func mismatchedCallIsALinkError() {
        // Given. Nothing runs here. Both sides are declarations, and a
        // declaration is text, so this is the half of checking the builder can
        // do
        let counts = Procedure(
            signature: Signature(returns: .int),
            body: [],
            result: .literal(.int(1))
        )
        let wants = Procedure(
            signature: Signature(parameters: ["word": Parameter(type: .string)]),
            body: []
        )
        let entry = Procedure(
            body: [
                Statement(binding: .constant("said"), expression: .call(
                        Call(
                            selector: "wants",
                            arguments: [
                                "word": .call(Call(selector: "counts"))
                            ]
                        )
                    )
                )
            ]
        )

        // When / Then
        #expect(throws: LinkError.self) {
            try Builder().build(
                [try Module(procedures: ["entry": entry, "wants": wants, "counts": counts])],
                entry: "entry"
            )
        }
    }

    @Test("an undeclared answer is read off the body, and held to the same rule")
    func undeclaredAnswerIsReadOffTheBody() throws {
        // Given. `counts` declares nothing, and its body answers a whole
        // number. The declaration stays as the author left it; what the link
        // reads a call as is what the body hands back, so the same disagreement
        // a declared answer earns is earned here.
        let counts = Procedure(body: [], result: .literal(.int(1)))
        let wants = Procedure(
            signature: Signature(parameters: ["word": Parameter(type: .string)]),
            body: []
        )
        let entry = Procedure(
            body: [
                Statement(binding: .constant("said"), expression: .call(
                        Call(
                            selector: "wants",
                            arguments: [
                                "word": .call(Call(selector: "counts"))
                            ]
                        )
                    )
                )
            ]
        )

        // When / Then
        #expect {
            try Builder().build(
                [try Module(procedures: ["entry": entry, "wants": wants, "counts": counts])],
                entry: "entry"
            )
        } throws: { error in
            error is LinkError && "\(error)".contains("holds int where string is declared")
        }

        // And a body whose answer nothing can be read from says nothing. An
        // answer worked out from its own is not one the text states.
        let circling = Procedure(
            body: [],
            result: .call(Call(selector: "counts"))
        )

        _ = try Builder().build(
            [try Module(procedures: ["entry": entry, "wants": wants, "counts": circling])],
            entry: "entry"
        )
    }

    @Test("a dictionary slot takes a record whose fields all fit it")
    func aDictionaryTakesAKnownRecord() {
        // Given. A record is a dictionary whose fields happen to be known, and
        // knowing them is not a reason to refuse it
        let sut = TypeExpression.dictionary(.any)

        // When / Then
        #expect(sut.accepts(.record(["axes": .string, "depth": .int])))
        #expect(TypeExpression.dictionary(.string).accepts(.record(["axes": .string])))
        #expect(!TypeExpression.dictionary(.int).accepts(.record(["axes": .string])))
    }

    @Test("a record slot does not take a bare dictionary")
    func aRecordDoesNotTakeADictionary() {
        // Given. A record names fields it requires; a dictionary promises none
        #expect(!TypeExpression.record(["axes": .string]).accepts(.dictionary(.string)))
    }

}
