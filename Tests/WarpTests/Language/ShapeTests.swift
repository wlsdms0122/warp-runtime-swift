//
//  ShapeTests.swift
//  WarpTests
//
//  Created by JSilver on 9/3/26.
//

import Foundation
import Testing
@testable import Warp

// What the link leaves the run to read types by: rows for names, one judge
// over shapes, and a document's type reaching it through a door.
@Suite("Types lower to shapes the run reads by row")
struct ShapeTests {
    // MARK: - Property
    private let linker = Linker()

    private let types = TypeTable(
        types: [
            "bank.Account": .record(["balance": .int, "owner": .named("bank.Owner")]),
            "bank.Owner": .record(["name": .string]),
            "bank.Acct": .named("bank.Account"),
            "app.Byte": .ranged(.whole(from: 0, to: .through(255))),
            "app.Maybe": .nullable(.int)
        ],
        constraints: [
            "app.Ordered": [.int, .double, .string]
        ]
    )

    // MARK: - Initializer
    // MARK: - Test
    @Test("a lowered type renders as the author wrote it")
    func aLoweredTypeRendersAsWritten() throws {
        // Given: every declared type, and a few that name them
        let table = types.shapes
        let written: [TypeExpression] = Array(types.types.values) + [
            .array(.named("bank.Acct")),
            .nullable(.named("bank.Owner")),
            .parameter(name: "T", constraint: "app.Ordered"),
            .procedure(Signature(parameters: ["of": Parameter(type: .named("bank.Account"))], returns: .int), .pure),
            .object(.named("app.Maybe"))
        ]

        // When / Then
        for type in written {
            #expect(type.lowered(in: table).rendered(in: table) == type.rendered, "\(type.rendered)")
        }
    }

    @Test("a name lowers to its row, and the row of the record it names is the chain's end")
    func aNameLowersToARow() throws {
        // Given
        let table = types.shapes

        // When
        let alias = try #require(table.row(named: "bank.Acct"))
        let account = try #require(table.row(named: "bank.Account"))
        let byte = try #require(table.row(named: "app.Byte"))

        // Then: the alias names the account's record, and a range names none
        #expect(TypeExpression.named("bank.Acct").lowered(in: table) == .named(alias))
        #expect(table.recordRows[alias] == account)
        #expect(table.recordRows[account] == account)
        #expect(table.recordRows[byte] == nil)
    }

    @Test("a walk's reading lowers to what proves nothing")
    func aReadingLowersToAny() throws {
        // Given
        let table = types.shapes

        // When / Then
        #expect(try TypeExpression.reading(of: "T", path: [.key("inner")]).lowered(in: table) == .any)
        #expect(try TypeExpression.array(.reading(of: "T", path: [])).lowered(in: table) == .array(.any))
    }

    @Test("a record settling into an alias slot takes the canonical name, and passes it again by comparison")
    func aRecordSettlesUnderTheCanonicalName() throws {
        // Given: a slot spelled with the alias, a nameless record, and one
        // already named by the alias
        let table = types.shapes
        let slot = TypeExpression.named("bank.Acct").lowered(in: table)
        let owner = Value.object(["name": .string("a")])

        // When
        let settled = try slot.settling(.object(["balance": .int(1), "owner": owner]), at: "input", in: table)
        let again = try slot.settling(settled, at: "input", in: table)
        let spelled = try slot.settling(
            .record(name: "bank.Acct", fields: ["balance": .int(1), "owner": owner]),
            at: "input",
            in: table
        )

        // Then
        #expect(settled == .record(name: "bank.Account", fields: ["balance": .int(1), "owner": .record(name: "bank.Owner", fields: ["name": .string("a")])]))
        #expect(again == settled)
        #expect(spelled == settled)
        #expect {
            try slot.settling(.record(name: "bank.Owner", fields: ["balance": .int(1), "owner": owner]), at: "input", in: table)
        } throws: { error in
            "\(error)".contains("is a bank.Owner, and the slot declares bank.Account")
        }
    }

    @Test("a host's door refuses an undeclared name with the path in front")
    func aDoorRefusesAnUndeclaredNameWithItsPath() {
        // When / Then
        #expect {
            try TypeExpression.named("bank.Vault").settling(.int(1), at: "input 'x'", in: types)
        } throws: { error in
            "\(error)".contains("input 'x': declares type 'bank.Vault', which nothing declares")
        }
        #expect(!TypeExpression.named("bank.Vault").accepts(.int, in: types))
    }

    @Test("a linked row settles a bounded parameter by row, and its slots carry the lowering")
    func aLinkedRowCarriesItsSlots() async throws {
        // Given
        let module = try Module(
            procedures: [
                "entry": Procedure(
                    body: [],
                    result: .dispatch(Dispatch(
                        receiver: .literal(.int(1)),
                        selector: "std.math.lessThan",
                        arguments: ["value": .literal(.int(2))]
                    ))
                )
            ]
        )

        // When
        let image = try linker.link([module] + Module.standard, entry: "entry")
        let row = try #require(image["std.math.lessThan"])
        let ordered = try #require(image.shapes.constraintRow(named: "std.Comparable"))

        // Then
        #expect(row.slots.map(\.name) == ["of", "value"])
        #expect(row.slots.map(\.shape) == [.parameter(label: "T", constraint: ordered), .parameter(label: "T", constraint: ordered)])
        #expect(row.returns == .bool)
        #expect(try await Executor().run(image) == .bool(true))
    }

    @Test("a word hands a closure its arguments by name, and the closure reads them")
    func aClosureIsHandedArgumentsByName() async throws {
        // Given: `map` hands `item`, and a closure that declares it
        let module = try Module(
            procedures: [
                "entry": Procedure(
                    body: [],
                    result: .dispatch(Dispatch(
                        receiver: .literal(.array([.int(1), .int(2)])),
                        selector: "std.collection.map",
                        arguments: [
                            "value": .closure(
                                Procedure(
                                    signature: Signature(parameters: ["item": Parameter(type: .int)], returns: .int),
                                    body: [],
                                    result: .dispatch(Dispatch(
                                        receiver: .reference([.key("item")]),
                                        selector: "std.math.plus",
                                        arguments: ["value": .literal(.int(10))]
                                    ))
                                )
                            )
                        ]
                    ))
                )
            ]
        )

        // When
        let image = try linker.link([module] + Module.standard, entry: "entry")

        // Then
        #expect(try await Executor().run(image) == .array([.int(11), .int(12)]))
    }

    @Test("a parameter with a default is never required, whatever its type names")
    func aDefaultedParameterIsNeverRequired() {
        // Given: a type nothing declares, beside a default
        let sut = Parameter(type: .named("bank.Vault"), default: .string("x"))

        // When / Then
        #expect(sut.mustBeGiven(in: types) == false)
        #expect(Parameter(type: .named("bank.Vault")).mustBeGiven(in: types) == true)
    }

    @Test("an argument given twice by name is refused, not quietly kept once")
    func anArgumentGivenTwiceIsRefused() throws {
        // Given
        let signature = Signature(parameters: ["item": Parameter(type: .int)])
        let table = TypeTable().shapes

        // When / Then
        #expect {
            try signature.settle(
                [(name: "item", value: .int(1)), (name: "item", value: .int(2))],
                over: signature.lowered(in: table),
                offered: true,
                in: table
            )
        } throws: { error in
            "\(error)".contains("'item' is given more than once")
        }
    }

    @Test("a host asks a constraint about a value through the document's table")
    func aHostAsksMembershipOfAValue() {
        // When / Then
        #expect(types.admits(constraint: "app.Ordered", value: .int(1)) == true)
        #expect(types.admits(constraint: "app.Ordered", value: .bool(true)) == false)
        #expect(types.admits(constraint: "app.Nobody", value: .int(1)) == nil)
    }

    @Test("a table built by hand whose names form a circle answers instead of chasing them")
    func aCircleOfNamesIsRefusedNotChased() {
        // Given
        let circular = TypeTable(types: ["app.A": .named("app.B"), "app.B": .named("app.A"), "app.C": .int])

        // When / Then: the circle is refused where it is met, and the row
        // beside it answers as itself
        #expect {
            try TypeExpression.named("app.A").settling(.int(1), at: "input", in: circular)
        } throws: { error in
            "\(error)".contains("input: declares type 'app.A', which names itself")
        }
        #expect(!TypeExpression.named("app.A").declaresNull(in: circular))
        #expect(TypeExpression.named("app.C").accepts(.int, in: circular))
        #expect(Parameter(type: .named("app.C"), default: .int(0)).mustBeGiven(in: circular) == false)
    }

    @Test("one undeclared name touches only the judgments that reach it")
    func anUndeclaredNameTouchesOnlyItsOwnJudgments() {
        // Given: a table with one bad row beside a good one
        let table = TypeTable(types: ["app.Bad": .named("app.Missing"), "app.Good": .nullable(.int)])

        // When / Then
        #expect(TypeExpression.named("app.Good").declaresNull(in: table))
        #expect(TypeExpression.named("app.Good").accepts(.int, in: table))
        #expect(!TypeExpression.named("app.Bad").accepts(.int, in: table))
        #expect(!TypeExpression.named("app.Bad").declaresNull(in: table))
        #expect {
            try TypeExpression.named("app.Bad").settling(.int(1), at: "input", in: table)
        } throws: { error in
            "\(error)".contains("input: declares type 'app.Missing', which nothing declares")
        }
    }

    // MARK: - Public
    // MARK: - Private
}
