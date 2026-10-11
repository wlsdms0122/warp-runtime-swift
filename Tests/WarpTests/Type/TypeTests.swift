//
//  TypeTests.swift
//  WarpTests
//
//  Created by JSilver on 8/17/26.
//

import Foundation
import Testing
@testable import Warp
import WarpTestSupport

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

    @Test("a record from outside is fitted to the fields declared, one short refusing")
    func recordDeclaresFields() throws {
        // Given. A declared record is its fields, and the door a value from
        // outside comes through leaves out a field it does not declare
        let types = try TypeTable(types: ["App.Task": .record(["id": .string, "done": .bool])])
        let sut = TypeExpression.named("App.Task")

        // When
        let settled = try sut.settling(.record(Record(name: "App.Task", ["id": .string("a"), "done": .bool(true)])), at: "task", in: types)
        let fitted = try sut.settling(
            .record(Record(name: "App.Task", ["id": .string("a"), "done": .bool(true), "extra": .int(1)])),
            at: "task",
            in: types
        )

        // Then
        #expect(settled["id"] == .string("a"))
        #expect(fitted["id"] == .string("a"))
        #expect(fitted["extra"] == nil)

        #expect(throws: ArgumentError.self) {
            try sut.settling(.record(Record(name: "App.Task", ["id": .string("a")])), at: "task", in: types)
        }
    }

    @Test("an alias of a declared record names the record on either side")
    func anAliasNamesTheRecordItStandsFor() throws {
        // Given
        let types = try TypeTable(types: ["Person": .record(["name": .string]), "Someone": .alias(.named("Person"))])
        let sut = TypeExpression.named("Someone")

        // When
        let aliased = try sut.settling(.record(Record(name: "Someone", ["name": .string("a")])), at: "who", in: types)
        let named = try sut.settling(.record(Record(name: "Person", ["name": .string("a")])), at: "who", in: types)

        // Then. Either settles under the record's own name
        #expect(aliased == .record(Record(name: "Person", ["name": .string("a")])))
        #expect(named == aliased)
    }

    @Test("a named type resolves through the table it was declared in")
    func namedTypeResolves() throws {
        // Given
        let types = try TypeTable(types: ["Task": .record(["id": .string])])
        let sut = TypeExpression.array(.named("Task"))

        // When
        let settled = try sut.settling(
            .array([.record(Record(name: "Task", ["id": .string("a")]))]),
            at: "tasks",
            in: types
        )

        // Then
        #expect(settled == .array([.record(Record(name: "Task", ["id": .string("a")]))]))

        #expect(throws: ArgumentError.self) {
            try sut.settling(.array([.record(Record(name: "Task", ["id": .int(1)]))]), at: "tasks", in: types)
        }
    }

    @Test("a type may name itself")
    func namedTypeMayRecur() throws {
        // Given. Kept rather than expanded at the build, which is what makes a
        // self-naming type a type and not a regress
        let types = try TypeTable(
            types: ["Tree": .record(["value": .int, "children": .array(.named("Tree"))])]
        )
        let sut = TypeExpression.named("Tree")

        // When
        let settled = try sut.settling(
            .record(Record(name: "Tree", [
                "value": .int(1),
                "children": .array([.record(Record(name: "Tree", ["value": .int(2), "children": .array([])]))])
            ])),
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
        // When / Then
        #expect(TypeExpression.array(.string).rendered == "Array<String>")
        #expect(TypeExpression.dictionary(key: .string, value: .named("Task")).rendered == "Dictionary<String, Task>")
        #expect(TypeExpression.array(.array(.int)).rendered == "Array<Array<Int>>")
        #expect(TypeDeclaration.record(["b": .int, "a": .string]).rendered == "{ a: String, b: Int }")
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
                ))
            ]
        )

        // When / Then
        await #expect {
            try await Builder().build(
                [try Module(procedures: ["entry": entry.with(access: .public), "wants": wants, "counts": counts])]
            )
        } throws: { error in
            error is BuildError
                && "\(error)".contains("sending 'wants' with text, which holds Int where String is declared")
        }
    }

    @Test("an answer no declaration writes is read off the body, and held to the same rule")
    func anUnwrittenAnswerIsReadOffTheBody() async throws {
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
                ))
            ]
        )

        // When / Then
        await #expect {
            try await Builder().build(
                [try Module(procedures: ["entry": entry.with(access: .public), "wants": wants, "counts": counts])]
            )
        } throws: { error in
            error is BuildError && "\(error)".contains("holds Int where String is declared")
        }

        // And a body whose answer nothing can be read from reads `Any`, since
        // an answer worked out from its own is not one the text states, and a
        // slot of a type takes a value read as `Any` only through a cast.
        let cycling = Procedure(
            body: [],
            result: .call(Call(selector: "counts"))
        )

        await #expect {
            try await Builder().build(
                [try Module(procedures: ["entry": entry.with(access: .public), "wants": wants, "counts": cycling])]
            )
        } throws: { error in
            error is BuildError && "\(error)".contains("holds Any where String is declared")
        }
    }

    @Test("a declared record and a map of its fields are two types")
    func aRecordAndADictionaryAreTwoTypes() throws {
        // Given. A record names the fields it holds; a map holds keys that are
        // data, and neither is a value of the other
        let types = try TypeTable(types: ["App.Axes": .record(["axes": .string])])
        let record = TypeExpression.named("App.Axes")
        let map = TypeExpression.dictionary(key: .string, value: .string)

        // When / Then
        #expect(!record.accepts(map, in: types))
        #expect(!map.accepts(record, in: types))
    }

    @Test("a nullable slot takes its value, null, and nothing else")
    func aNullableSlotSettles() throws {
        // Given
        let declared = TypeExpression.nullable(.int)

        // When / Then
        #expect(try declared.settling(.int(3), at: "limit") == .int(3))
        #expect(try declared.settling(.null, at: "limit") == .null)
        #expect {
            try declared.settling(.string("x"), at: "limit")
        } throws: { error in
            error is ArgumentError && "\(error)".contains("expected Int, got String")
        }
    }

    @Test("what may be null does not stand where null was never declared")
    func aNullableReadingNeedsANullableSlot() throws {
        // When / Then. The declared half fits its own slot, and the nullable
        // does not. In either wrapping.
        #expect(TypeExpression.nullable(.int).accepts(.int))
        #expect(TypeExpression.nullable(.int).accepts(.null))
        #expect(TypeExpression.nullable(.int).accepts(.nullable(.int)))
        #expect(!TypeExpression.int.accepts(.nullable(.int)))
        #expect(!TypeExpression.nullable(.int).accepts(.string))
        #expect(!TypeExpression.nullable(.int).accepts(.nullable(.string)))
    }

    @Test("a nullable type spells itself in refusals")
    func aNullableRenders() {
        // When / Then
        #expect(TypeExpression.nullable(.int).rendered == "Int?")
        #expect(TypeExpression.nullable(.array(.string)).rendered == "Array<String>?")
    }

    @Test("a closure a caller assembled claims nothing, and fits only a slot that asks nothing")
    func anAssembledClosureClaimsNothing() throws {
        // Given. Assembled against the table it is judged against, so what is
        // being asked is the claim and not which link made the row
        let types = try TypeTable()
        let closure = Self.assembled(answering: .int(1), in: types)

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
        let types = try TypeTable(types: ["Node": .record(["next": .named("Node")])])

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

    @Test("a map slot takes a map and no record")
    func aRecordDoesNotSettleIntoAMap() throws {
        // Given. A record is a value of its declared record, and no map
        let types = try TypeTable(types: ["Bank.Account": .record(["balance": .int])])
        let map = Value.dictionary(["balance": .int(1)])
        let named = Value.record(Record(name: "Bank.Account", ["balance": .int(1)]))
        let sut = TypeExpression.dictionary(key: .string, value: .any)

        // When / Then
        #expect(try sut.settling(map, at: "held", in: types) == map)
        #expect(throws: ArgumentError.self) {
            try sut.settling(named, at: "held", in: types)
        }
    }

    // MARK: - Public
    // MARK: - Private
    // A closure a test builds by hand, answering a value: no body a document
    // spelled, no captures, claiming nothing.
    private static func assembled(answering result: Value? = nil, in types: TypeTable = .empty) -> Closure {
        Closure(
            writer: Closure.Writer(document: .compiled(Compiled.Token()), declaration: .procedure("assembled")),
            nth: 0,
            linked: Linked(
                label: "assembled",
                origin: 0,
                signature: Signature(),
                access: .internal,
                constness: .unstated,
                isolation: .unstated,
                failing: .unstated,
                implementation: .body(
                    LoweredBody(instructions: [], result: result.map(Operation.literal)),
                    Frame(size: 0, parameters: [], variables: [], captures: [], names: [])
                ),
                foldable: true,
                in: types.loweredTypes
            ),
            captured: []
        )
    }
}
