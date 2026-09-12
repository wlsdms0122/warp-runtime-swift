//
//  LoweredTypeTests.swift
//  WarpTests
//
//  Created by JSilver on 9/3/26.
//

import Foundation
import Testing
@testable import Warp

// What the build leaves the run to read types by: rows for names, one judge
// over shapes, and a document's type reaching it through a door.
@Suite("Types lower to shapes the run reads by row")
struct LoweredTypeTests {
    // MARK: - Property
    private let builder = Builder()

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
        let table = types.loweredTypes
        let written: [TypeExpression] = Array(types.types.values) + [
            .array(.named("bank.Acct")),
            .nullable(.named("bank.Owner")),
            .parameter(name: "T", constraint: "app.Ordered"),
            .procedure(Signature(parameters: ["of": Parameter(type: .named("bank.Account"))], returns: .int), .pure),
            .dictionary(.named("app.Maybe"))
        ]

        // When / Then
        for type in written {
            #expect(type.lowered(in: table).rendered(in: table) == type.rendered, "\(type.rendered)")
        }
    }

    @Test("a name lowers to its row, and the row of the record it names is the chain's end")
    func aNameLowersToARow() throws {
        // Given
        let table = types.loweredTypes

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

    @Test("a walk's reading lowers to itself, and every judgment answers it as any")
    func aReadingLowersToItself() throws {
        // Given
        let table = types.loweredTypes
        let reading = try TypeExpression.reading(of: "T", path: [.key("inner")]).lowered(in: table)

        // When / Then
        #expect(reading == .reading(of: "T", path: [.key("inner")]))
        #expect(try TypeExpression.array(.reading(of: "T", path: [])).lowered(in: table)
            == .array(.reading(of: "T", path: [])))
        #expect(LoweredType.int.accepts(reading, in: table))
        #expect(reading.accepts(.int, in: table))
        #expect(try reading.settling(.int(1), at: "", in: table) == .int(1))
    }

    @Test("a record settling into an alias slot takes the canonical name, and passes it again by comparison")
    func aRecordSettlesUnderTheCanonicalName() throws {
        // Given: a slot spelled with the alias, a nameless record, and one
        // already named by the alias
        let table = types.loweredTypes
        let slot = TypeExpression.named("bank.Acct").lowered(in: table)
        let owner = Value.dictionary(["name": .string("a")])

        // When
        let settled = try slot.settling(.dictionary(["balance": .int(1), "owner": owner]), at: "input", in: table)
        let again = try slot.settling(settled, at: "input", in: table)
        let spelled = try slot.settling(
            .record(Record(name: "bank.Acct", ["balance": .int(1), "owner": owner])),
            at: "input",
            in: table
        )

        // Then
        #expect(
            settled == .record(
                Record(name: "bank.Account", ["balance": .int(1), "owner": .record(Record(name: "bank.Owner", ["name": .string("a")]))])
            )
        )
        #expect(again == settled)
        #expect(spelled == settled)
        #expect {
            try slot.settling(.record(Record(name: "bank.Owner", ["balance": .int(1), "owner": owner])), at: "input", in: table)
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
        #expect(TypeExpression.named("bank.Vault").accepts(.int, in: types))
    }

    @Test("a linked row settles a bounded parameter by row, and its slots carry the lowering")
    func aLinkedRowCarriesItsSlots() async throws {
        // Given
        let module = try Module(
            procedures: [
                "entry": Procedure(
                    body: [],
                    result: .call(Call(
                        receiver: .literal(.int(1)),
                        selector: "std.math.lessThan",
                        arguments: ["value": .literal(.int(2))]
                    ))
                )
            ]
        )

        // When
        let image = try builder.build([module] + Module.standard, entry: "entry")
        let row = try #require(image["std.math.lessThan"])
        let ordered = try #require(image.loweredTypes.constraintRow(named: "std.Comparable"))

        // Then
        #expect(row.slots.map(\.name) == ["of", "value"])
        #expect(row.slots.map(\.shape) == [.parameter(label: "T", bound: .membership(ordered)), .parameter(label: "T", bound: .membership(ordered))])
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
                    result: .call(Call(
                        receiver: .literal(.array([.int(1), .int(2)])),
                        selector: "std.collection.map",
                        arguments: [
                            "value": .closure(
                                Procedure(
                                    signature: Signature(parameters: ["item": Parameter(type: .int)], returns: .int),
                                    body: [],
                                    result: .call(Call(
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
        let image = try builder.build([module] + Module.standard, entry: "entry")

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
        let table = TypeTable().loweredTypes

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

    @Test("a table built by hand whose names form a cycle answers instead of chasing them")
    func aCycleOfNamesIsRefusedNotChased() {
        // Given
        let circular = TypeTable(types: ["app.A": .named("app.B"), "app.B": .named("app.A"), "app.C": .int])

        // When / Then: the cycle is refused where it is met, and the row
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

    @Test("one undeclared name passes every reading and is refused where a value meets it")
    func anUndeclaredNameTouchesOnlyItsOwnJudgments() {
        // Given: a table with one bad row beside a good one
        let table = TypeTable(types: ["app.Bad": .named("app.Missing"), "app.Good": .nullable(.int)])

        // When / Then
        #expect(TypeExpression.named("app.Good").declaresNull(in: table))
        #expect(TypeExpression.named("app.Good").accepts(.int, in: table))
        #expect(TypeExpression.named("app.Bad").accepts(.int, in: table))
        #expect(TypeExpression.int.accepts(.named("app.Bad"), in: table))
        #expect(TypeExpression.named("app.Bad").lowered(in: table.loweredTypes)
            .couldBothHold(.int, in: table.loweredTypes))
        #expect(!TypeExpression.named("app.Bad").declaresNull(in: table))
        #expect {
            try TypeExpression.named("app.Bad").settling(.int(1), at: "input", in: table)
        } throws: { error in
            "\(error)".contains("input: declares type 'app.Missing', which nothing declares")
        }
    }

    @Test("a name that reaches itself under a wrapper is a cycle, and the value judge says so")
    func aCycleUnderAWrapperIsRefusedNotChased() {
        // Given: a table built by hand, which the build's refusals never saw
        let table = TypeTable(
            types: [
                "app.M": .nullable(.named("app.M")),
                "app.A": .variable(.named("app.B")),
                "app.B": .inout(.named("app.A")),
                "app.T": .nullable(.named("app.Leaf")),
                "app.Leaf": .int
            ]
        )

        // When / Then: each cycle is refused where a value meets it, and a
        // chain that ends is walked to its end
        #expect {
            try TypeExpression.named("app.M").settling(.int(1), at: "input", in: table)
        } throws: { error in
            "\(error)".contains("input: declares type 'app.M', which names itself")
        }
        #expect {
            try TypeExpression.named("app.A").settling(.int(1), at: "input", in: table)
        } throws: { error in
            "\(error)".contains("input: declares type 'app.A', which names itself")
        }
        #expect(throws: Never.self) {
            try TypeExpression.named("app.T").settling(.int(1), at: "input", in: table)
        }
        #expect(TypeExpression.named("app.T").declaresNull(in: table))
    }

    @Test("the build refuses a chain of names that comes back on itself under a wrapper")
    func theLinkRefusesACycleUnderAWrapper() throws {
        // Given
        let sut = try Module(
            imports: [],
            types: ["app.A": .nullable(.named("app.B")), "app.B": .named("app.A")],
            procedures: [entryName: Procedure(body: [], result: .literal(.null))]
        )

        // When / Then
        #expect {
            try Builder().build([sut] + Module.standard, entry: entryName)
        } throws: { error in
            error is BuildError && "\(error)".contains("through nothing but names")
        }
    }

    @Test("a row is found by the bytes of its spelling, and not by an equivalent one")
    func aRowIsFoundByBytes() {
        // Given: a declared name written composed, and asked for decomposed
        let composed: Name = "app.Caf\u{E9}"
        let decomposed = "app.Cafe\u{301}"
        let table = TypeTable(types: [composed: .int])

        // When / Then: Swift calls the two spellings equal, and the table
        // does not
        #expect(composed.spelling == decomposed)
        #expect(table.loweredTypes.row(named: composed) == 0)
        #expect(throws: NameRefused.self) { try Name(decomposed) }
    }

    @Test("a procedure another link made is refused by a run, not read by its rows")
    func aProcedureFromAnotherLinkIsRefused() async throws {
        // Given: a closure made by one image, handed to a run of another
        let maker = try Module(
            procedures: [
                "entry": Procedure(
                    body: [],
                    result: .closure(Procedure(body: [], result: .literal(.int(1))))
                )
            ]
        )
        let taker = try Module(
            procedures: [
                "entry": Procedure(
                    signature: Signature(parameters: ["held": Parameter(type: .procedure(nil))]),
                    body: [],
                    result: .apply(.reference([.key("held")]), arguments: [:])
                )
            ]
        )
        let made = try await Executor().run(try builder.build([maker] + Module.standard, entry: "entry"))
        let taking = try builder.build([taker] + Module.standard, entry: "entry")

        // When / Then
        await #expect(throws: ArgumentError.self) {
            try await Executor().run(taking, arguments: ["held": made])
        }
    }

    @Test("a procedure from a link that declared no types is refused too")
    func aProcedureFromATypelessLinkIsRefused() async throws {
        // Given: neither link declares a type, so neither has a row a type
        // number could mean something in, and the rows a body does carry, the
        // procedures it sends to and the document its variables come from,
        // still mean something in one link alone.
        let maker = try Module(
            procedures: [
                "entry": Procedure(
                    body: [],
                    result: .closure(Procedure(body: [], result: .literal(.int(1))))
                )
            ]
        )
        let taker = try Module(
            procedures: [
                "entry": Procedure(
                    signature: Signature(parameters: ["held": Parameter(type: .procedure(nil))]),
                    body: [],
                    result: .apply(.reference([.key("held")]), arguments: [:])
                )
            ]
        )
        let made = try await Executor().run(try builder.build([maker], entry: "entry"))
        let taking = try builder.build([taker], entry: "entry")

        // When / Then
        await #expect(throws: ArgumentError.self) {
            try await Executor().run(taking, arguments: ["held": made])
        }
    }

    @Test("a judgment says the rule, rather than naming a link nobody named")
    func aJudgmentWithNoLinkSaysTheRule() async throws {
        // Given: a closure out of a run, judged with no declarations behind
        // the judgment. Which link this one came from is not knowable where
        // it is met, so naming one would be inventing it.
        let maker = try Module(
            procedures: [
                "entry": Procedure(
                    body: [],
                    result: .closure(Procedure(body: [], result: .literal(.int(1))))
                )
            ]
        )
        let made = try await Executor().run(try builder.build([maker] + Module.standard, entry: "entry"))

        // When / Then
        #expect {
            try Parameter(type: .procedure(nil)).checking(made, called: "held")
        } throws: { error in
            "\(error)".contains("read where the link that made it is being read")
        }
    }

    @Test("a reading naming an undeclared constraint passes membership, since nothing is proven of it")
    func anUndeclaredReadingPassesMembership() {
        // Given
        let reading = TypeExpression.parameter(name: "T", constraint: "app.Nobody")

        // When / Then
        #expect(types.admits(constraint: "app.Ordered", reading: reading) == true)
    }

    // MARK: - Public
    // MARK: - Private
}
