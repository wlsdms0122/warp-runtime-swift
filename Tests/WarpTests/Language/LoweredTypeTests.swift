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
// over types, and a document's type reaching it through a door.
@Suite("Types lower to types the run reads by row")
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
            .parameter(name: "T", constraints: ["app.Ordered"]),
            .procedure(ProcedureType(parameters: [.named("bank.Account")], returns: .int), .const),
            .dictionary(.named("app.Maybe"))
        ]

        // When / Then
        for type in written {
            #expect(type.lowered(in: table).rendered(in: table) == type.rendered, "\(type.rendered)")
        }
    }

    @Test("a type parameter read as ranges or as a range and its kind is the kind, whichever is read first")
    func aParameterReadAsRangesIsTheirKind() {
        // Given. Ranges meet by their kind, so two that overlap, or a range
        // and the plain kind under it, take each other both ways
        let table = types.loweredTypes
        let parameter = TypeExpression.parameter(name: "T").lowered(in: table)
        let narrow = TypeExpression.ranged(.whole(from: 0, to: .through(10))).lowered(in: table)
        let wide = TypeExpression.ranged(.whole(from: 5, to: .through(100))).lowered(in: table)

        func read(_ readings: [LoweredType]) -> LoweredType? {
            var bound: [Name: LoweredType] = [:]
            var disagreeing: [Name: LoweredType] = [:]
            var holding: [Substitution.Held] = []

            for reading in readings {
                parameter.binding(against: reading, into: &bound, disagreeing: &disagreeing, holding: &holding, in: table)
            }

            return bound["T"]
        }

        // When / Then
        #expect(read([narrow, wide]) == .int)
        #expect(read([wide, narrow]) == .int)
        #expect(read([narrow, .int]) == .int)
        #expect(read([.int, narrow]) == .int)
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
                    access: .public,
                    body: [],
                    result: .call(Call(
                        selector: "std.math.lessThan",
                        arguments: [.literal(.int(1)), .literal(.int(2))]
                    ))
                )
            ]
        )

        // When
        let image = try await builder.build([module] + Module.standard)
        let row = try #require(image["std.math.lessThan"])
        let ordered = try #require(image.loweredTypes.constraintRow(named: "std.Comparable"))

        // Then
        #expect(row.slots.map(\.name) == ["of", "value"])
        #expect(row.slots.map(\.type) == [.parameter(label: "T", bounds: [.membership(ordered)]), .parameter(label: "T", bounds: [.membership(ordered)])])
        #expect(row.returns == .bool)
        #expect(try await Executor().run(image) == .bool(true))
    }

    @Test("a procedure hands a closure its arguments by name, and the closure reads them")
    func aClosureIsHandedArgumentsByName() async throws {
        // Given: `map` hands `item`, and a closure that declares it
        let module = try Module(
            procedures: [
                "entry": Procedure(
                    access: .public,
                    body: [],
                    result: .call(Call(
                        selector: "std.collection.map",
                        arguments: [
                            .literal(.array([.int(1), .int(2)])),
                            .closure(
                                Procedure(
                                    signature: Signature(parameters: [Parameter(name: "item", type: .int)], returns: .int),
                                    body: [],
                                    result: .call(Call(
                                        selector: "std.math.plus",
                                        arguments: [.reference([.key("item")]), .literal(.int(10))]
                                    ))
                                )
                            )
                        ]
                    ))
                )
            ]
        )

        // When
        let image = try await builder.build([module] + Module.standard)

        // Then
        #expect(try await Executor().run(image) == .array([.int(11), .int(12)]))
    }

    @Test("a procedure type declared beside the types it names reads what they declare")
    func aProcedureTypeAmongDeclaredTypes() async throws {
        // Given. A declared record holding a procedure type whose parameter
        // names a declared nullable type, lowered while the table that holds
        // both rows is still being laid.
        let module = try Module(
            types: [
                "app.Maybe": .nullable(.int),
                "app.Kinds": .record([
                    "soft": .procedure(ProcedureType(parameters: [.named("app.Maybe")]), .unstated, .unstated)
                ])
            ],
            procedures: [
                "app.entry": Procedure(
                    access: .public,
                    signature: Signature(parameters: [Parameter(name: "k", type: .named("app.Kinds"))], returns: .int),
                    body: [],
                    result: .literal(.int(1))
                )
            ]
        )

        // When
        let compiled = try await Builder().compile([module] + Module.standard)
        let table = try #require(compiled.first { one in one.declared.contains("app.entry") }).types

        // Then. The parameter naming the nullable type need not be given.
        guard case let .record(fields)? = table["app.Kinds"],
              case let .procedure(soft?, _, _)? = fields["soft"]
        else {
            Issue.record("the declared record holds its procedure type")

            return
        }

        #expect(soft.parameters.first?.declaresNull(in: TypeTable(types: module.types, constraints: [:])) == true)
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
        #expect(Parameter(name: "c", type: .nullable(.named("app.C"))).mustBeGiven(in: circular) == false)
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
    func theLinkRefusesACycleUnderAWrapper() async throws {
        // Given
        let sut = try Module(
            imports: [],
            types: ["app.A": .nullable(.named("app.B")), "app.B": .named("app.A")],
            procedures: [entryName: Procedure(access: .public, body: [], result: .literal(.null))]
        )

        // When / Then
        await #expect {
            try await Builder().build([sut] + Module.standard)
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
                    access: .public,
                    body: [],
                    result: .closure(Procedure(body: [], result: .literal(.int(1))))
                )
            ]
        )
        let taker = try Module(
            procedures: [
                "entry": Procedure(
                    access: .public,
                    signature: Signature(parameters: [Parameter(name: "held", type: .procedure(nil))]),
                    body: [],
                    result: .apply(.reference([.key("held")]), arguments: [])
                )
            ]
        )
        let made = try await Executor().run(try builder.build([maker] + Module.standard))
        let taking = try await builder.build([taker] + Module.standard)

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
                    access: .public,
                    body: [],
                    result: .closure(Procedure(body: [], result: .literal(.int(1))))
                )
            ]
        )
        let taker = try Module(
            procedures: [
                "entry": Procedure(
                    access: .public,
                    signature: Signature(parameters: [Parameter(name: "held", type: .procedure(nil))]),
                    body: [],
                    result: .apply(.reference([.key("held")]), arguments: [])
                )
            ]
        )
        let made = try await Executor().run(try builder.build([maker]))
        let taking = try await builder.build([taker])

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
                    access: .public,
                    body: [],
                    result: .closure(Procedure(body: [], result: .literal(.int(1))))
                )
            ]
        )
        let made = try await Executor().run(try builder.build([maker] + Module.standard))

        // When / Then
        #expect {
            try Parameter(name: "held", type: .procedure(nil)).checking(made)
        } throws: { error in
            "\(error)".contains("read where the link that made it is being read")
        }
    }

    @Test("a reading naming an undeclared constraint passes membership, since nothing is proven of it")
    func anUndeclaredReadingPassesMembership() {
        // Given
        let reading = TypeExpression.parameter(name: "T", constraints: ["app.Nobody"])

        // When / Then
        #expect(types.admits(constraint: "app.Ordered", reading: reading) == true)
    }

    // MARK: - Public
    // MARK: - Private
}
