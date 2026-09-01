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

        // Then — the index is in the message, so the author knows which one
        #expect(error?.message.contains("names[1]") == true)
    }

    @Test("a record declares its fields and tolerates more")
    func recordDeclaresFields() throws {
        // Given — what arrives is data from outside, and a payload gains fields
        let sut = TypeExpression.record(["id": .string, "done": .bool])

        // When
        let settled = try sut.settling(
            .object(["id": .string("a"), "done": .bool(true), "extra": .int(1)]),
            at: "task"
        )

        // Then
        #expect(settled["extra"] == .int(1))

        #expect(throws: ArgumentError.self) {
            try sut.settling(.object(["id": .string("a")]), at: "task")
        }
    }

    @Test("a named type resolves through the table it was declared in")
    func namedTypeResolves() throws {
        // Given
        let types = TypeTable(types: ["Task": .record(["id": .string])])
        let sut = TypeExpression.array(.named("Task"))

        // When
        let settled = try sut.settling(
            .array([.object(["id": .string("a")])]),
            at: "tasks",
            in: types
        )

        // Then
        #expect(settled == .array([.object(["id": .string("a")])]))

        #expect(throws: ArgumentError.self) {
            try sut.settling(.array([.object(["id": .int(1)])]), at: "tasks", in: types)
        }
    }

    @Test("a type may name itself")
    func namedTypeMayRecur() throws {
        // Given — kept rather than expanded at link, which is what makes a
        // self-naming shape a shape instead of a regress
        let types = TypeTable(
            types: ["Tree": .record(["value": .int, "children": .array(.named("Tree"))])]
        )
        let sut = TypeExpression.named("Tree")

        // When
        let settled = try sut.settling(
            .object([
                "value": .int(1),
                "children": .array([.object(["value": .int(2), "children": .array([])])])
            ]),
            at: "tree",
            in: types
        )

        // Then
        #expect(settled["value"] == .int(1))
    }

    @Test("the linker refuses a signature that names a shape nobody declared")
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
            try Linker().link([sut], entry: "entry")
        }
    }

    @Test("a type reads back in the spelling it was declared with")
    func typesRenderAsWritten() {
        #expect(TypeExpression.array(.string).rendered == "array<string>")
        #expect(TypeExpression.object(.named("Task")).rendered == "object<Task>")
        #expect(TypeExpression.array(.array(.int)).rendered == "array<array<int>>")
        #expect(TypeExpression.record(["b": .int, "a": .string]).rendered == "{ a: string, b: int }")
    }

    @Test("a call handed to a parameter it cannot fit is refused at link")
    func mismatchedCallIsALinkError() {
        // Given — nothing runs here. Both sides are declarations, and a
        // declaration is text, so this is the half of checking the linker can do
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
                Statement(
                    id: "said",
                    expression: .dispatch(
                        Dispatch(
                            selector: "wants",
                            arguments: [
                                "word": .dispatch(Dispatch(selector: "counts"))
                            ]
                        )
                    )
                )
            ]
        )

        // When / Then
        #expect(throws: LinkError.self) {
            try Linker().link(
                [try Module(procedures: ["entry": entry, "wants": wants, "counts": counts])],
                entry: "entry"
            )
        }
    }

    @Test("an undeclared answer is read off the body, and held to the same rule")
    func undeclaredAnswerIsReadOffTheBody() throws {
        // Given — `counts` declares nothing, and its body answers a whole
        // number. The declaration stays as the author left it; what the link
        // reads a call as is what the body hands back, so the same
        // disagreement a declared answer earns is earned here.
        let counts = Procedure(body: [], result: .literal(.int(1)))
        let wants = Procedure(
            signature: Signature(parameters: ["word": Parameter(type: .string)]),
            body: []
        )
        let entry = Procedure(
            body: [
                Statement(
                    id: "said",
                    expression: .dispatch(
                        Dispatch(
                            selector: "wants",
                            arguments: [
                                "word": .dispatch(Dispatch(selector: "counts"))
                            ]
                        )
                    )
                )
            ]
        )

        // When / Then
        #expect {
            try Linker().link(
                [try Module(procedures: ["entry": entry, "wants": wants, "counts": counts])],
                entry: "entry"
            )
        } throws: { error in
            error is LinkError && "\(error)".contains("holds int where string is declared")
        }

        // And a body whose answer nothing can be read from says nothing —
        // an answer worked out from its own is not one the text states.
        let circling = Procedure(
            body: [],
            result: .dispatch(Dispatch(selector: "counts"))
        )

        _ = try Linker().link(
            [try Module(procedures: ["entry": entry, "wants": wants, "counts": circling])],
            entry: "entry"
        )
    }

    @Test("an object slot takes a record whose fields all fit it")
    func objectTakesAKnownRecord() {
        // Given — a record is an object whose fields happen to be known, and
        // knowing them is not a reason to refuse it
        let sut = TypeExpression.object(.any)

        // When / Then
        #expect(sut.accepts(.record(["axes": .string, "depth": .int])))
        #expect(TypeExpression.object(.string).accepts(.record(["axes": .string])))
        #expect(!TypeExpression.object(.int).accepts(.record(["axes": .string])))
    }

    @Test("a record slot does not take a bare object")
    func recordDoesNotTakeAnObject() {
        // Given — a record names fields it requires; an object promises none
        #expect(!TypeExpression.record(["axes": .string]).accepts(.object(.string)))
    }

}
