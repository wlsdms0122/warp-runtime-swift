//
//  TypeTests.swift
//  WarpTests
//
//  Created by JSilver on 8/17/26.
//

import Foundation
import Testing
@testable import Warp

@Suite("A type is an expression")
struct TypeTests {
    // MARK: - Property
    // MARK: - Initializer
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
        // Given. Kept rather than expanded at the build, which is what makes a
        // self-naming type a type and not a regress
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

    @Test("the builder refuses a signature that names a type nobody declared")
    func unknownTypeIsABuildError() async throws {
        // Given
        let sut = try Module(
            procedures: [
                "entry": Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [Parameter(name: "task", type: .named("Nowhere"))]
                    ),
                    body: []
                )
            ]
        )

        // When / Then
        await #expect {
            try await Builder().build([sut])
        } throws: { error in
            error is BuildError && "\(error)".contains("names type 'Nowhere', which no module in this link declares")
        }
    }

    @Test("a type reads back in the spelling it was declared with")
    func typesRenderAsWritten() {
        #expect(TypeExpression.array(.string).rendered == "array<string>")
        #expect(TypeExpression.dictionary(.named("Task")).rendered == "dictionary<Task>")
        #expect(TypeExpression.array(.array(.int)).rendered == "array<array<int>>")
        #expect(TypeExpression.record(["b": .int, "a": .string]).rendered == "{ a: string, b: int }")
    }

    @Test("a call handed to a parameter it cannot fit is refused at the build")
    func mismatchedCallIsABuildError() async {
        // Given. Nothing runs here. Both sides are declarations, and a
        // declaration is text, so this is the half of checking the builder can
        // do
        let counts = Procedure(
            signature: Signature(returns: .int),
            body: [],
            result: .literal(.int(1))
        )
        let wants = Procedure(
            signature: Signature(parameters: [Parameter(name: "text", type: .string)]),
            body: []
        )
        let entry = Procedure(
            body: [
                Statement(binding: .constant("said"), expression: .call(
                        Call(selector: "wants", arguments: [.call(Call(selector: "counts"))])
                    )
                )
            ]
        )

        // When / Then
        await #expect {
            try await Builder().build(
                [try Module(procedures: ["entry": entry.with(access: .public), "wants": wants, "counts": counts])]
            )
        } throws: { error in
            error is BuildError
                && "\(error)".contains("sending 'wants' with text, which holds int where string is declared")
        }
    }

    @Test("an undeclared answer is read off the body, and held to the same rule")
    func undeclaredAnswerIsReadOffTheBody() async throws {
        // Given. `counts` declares nothing, and its body answers a whole
        // number. The declaration stays as the author left it; what the build
        // reads a call as is what the body hands back, so the same disagreement
        // a declared answer earns is earned here.
        let counts = Procedure(body: [], result: .literal(.int(1)))
        let wants = Procedure(
            signature: Signature(parameters: [Parameter(name: "text", type: .string)]),
            body: []
        )
        let entry = Procedure(
            body: [
                Statement(binding: .constant("said"), expression: .call(
                        Call(selector: "wants", arguments: [.call(Call(selector: "counts"))])
                    )
                )
            ]
        )

        // When / Then
        await #expect {
            try await Builder().build(
                [try Module(procedures: ["entry": entry.with(access: .public), "wants": wants, "counts": counts])]
            )
        } throws: { error in
            error is BuildError && "\(error)".contains("holds int where string is declared")
        }

        // And a body whose answer nothing can be read from says nothing. An
        // answer worked out from its own is not one the text states.
        let cycling = Procedure(
            body: [],
            result: .call(Call(selector: "counts"))
        )

        _ = try await Builder().build(
            [try Module(procedures: ["entry": entry.with(access: .public), "wants": wants, "counts": cycling])]
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

    @Test("a nullable slot takes its value, null, and nothing else")
    func aNullableSlotSettles() throws {
        let declared = TypeExpression.nullable(.int)

        #expect(try declared.settling(.int(3), at: "limit") == .int(3))
        #expect(try declared.settling(.null, at: "limit") == .null)
        #expect {
            try declared.settling(.string("x"), at: "limit")
        } throws: { error in
            error is ArgumentError && "\(error)".contains("expected int, got string")
        }
    }

    @Test("what may be null does not stand where null was never declared")
    func aNullableReadingNeedsANullableSlot() throws {
        // The declared half fits its own slot, and the nullable does not. In
        // either wrapping.
        #expect(TypeExpression.nullable(.int).accepts(.int))
        #expect(TypeExpression.nullable(.int).accepts(.null))
        #expect(TypeExpression.nullable(.int).accepts(.nullable(.int)))
        #expect(!TypeExpression.int.accepts(.nullable(.int)))
        #expect(!TypeExpression.nullable(.int).accepts(.string))
        #expect(!TypeExpression.nullable(.int).accepts(.nullable(.string)))
    }

    @Test("a nullable type spells itself in refusals")
    func aNullableRenders() {
        #expect(TypeExpression.nullable(.int).rendered == "int?")
        #expect(TypeExpression.nullable(.array(.string)).rendered == "array<string>?")
    }

    @Test("a closure a caller assembled claims nothing, and fits only a slot that asks nothing")
    func anAssembledClosureClaimsNothing() throws {
        // Given. Assembled against the table it is judged against, so what is
        // being asked is the claim and not which link made the row
        let types = TypeTable()
        let closure = Closure.assembled(answering: .int(1), in: types.loweredTypes)

        // When / Then
        #expect(throws: ArgumentError.self) {
            try TypeExpression.procedure(nil, .unstated, .isolated)
                .settling(.procedure(closure), at: "piece", in: types)
        }
        #expect(throws: Never.self) {
            try TypeExpression.procedure(nil)
                .settling(.procedure(closure), at: "piece", in: types)
        }
    }

    @Test("a recursive type compared with itself agrees instead of recursing")
    func aRecursiveTypeAcceptsItself() async throws {
        // Given. A type that names itself walks back into the comparison it is
        // inside; meeting the pair again is agreement, not a regress
        let types = TypeTable(types: ["Node": .record(["next": .named("Node")])])

        // When / Then
        #expect(TypeExpression.named("Node").accepts(.named("Node"), in: types))

        let sut = try Module(
            types: ["Node": .record(["value": .int, "next": .nullable(.named("Node"))])],
            procedures: [
                "read": Procedure(
                    signature: Signature(
                        parameters: [Parameter(name: "node", type: .named("Node"))],
                        returns: .int
                    ),
                    body: [],
                    result: .reference([.key("node"), .key("value")])
                ),
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [Parameter(name: "node", type: .named("Node"))],
                        returns: .int
                    ),
                    body: [],
                    result: .call(Call(selector: "read", arguments: [reference("node")]))
                )
            ]
        )

        await #expect(throws: Never.self) {
            try await Builder().build([sut] + Module.standard)
        }
    }

    @Test("a dictionary slot takes a record and answers one whose names are data")
    func aRecordSettlesIntoADictionaryAsData() throws {
        // Given. A name is proved where a slot declares one, and a `dictionary`
        // slot declares none
        let named = Value.record(Record(name: "bank.Account", ["balance": .int(1)]))

        // When
        let settled = try TypeExpression.dictionary(.any).settling(named, at: "held")

        // Then
        #expect(settled == .dictionary(["balance": .int(1)]))
    }

    // MARK: - Public
    // MARK: - Private
}
