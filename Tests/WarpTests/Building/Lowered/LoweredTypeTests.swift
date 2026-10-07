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
            "Bank.Account": .record(["balance": .int, "owner": .named("Bank.Owner")]),
            "Bank.Owner": .record(["name": .string]),
            "Bank.Acct": .named("Bank.Account"),
            "App.Byte": .ranged(.whole(from: 0, to: .through(255))),
            "App.Maybe": .nullable(.int)
        ],
        contracts: ["App.Ordered": [:]],
        satisfying: ["App.Ordered": ["Int", "Double", "String"]],
        settled: true,
        of: Linkage()
    )

    // MARK: - Initializer
    // MARK: - Test
    @Test("a lowered type renders as the author wrote it")
    func aLoweredTypeRendersAsWritten() throws {
        // Given. Every declared type, and a few that name them
        let table = types.loweredTypes
        let written: [TypeExpression] = Array(types.types.values) + [
            .array(.named("Bank.Acct")),
            .nullable(.named("Bank.Owner")),
            .parameter(name: "T", bounds: ["App.Ordered"]),
            .procedure(ProcedureType(parameters: [.named("Bank.Account")], returns: .int), .const),
            .dictionary(.named("App.Maybe"))
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
            var substitution = Substitution()

            for reading in readings {
                parameter.binding(against: reading, into: &substitution, in: table)
            }

            return substitution.readings["T"]
        }

        // When / Then
        #expect(read([narrow, wide]) == .int)
        #expect(read([wide, narrow]) == .int)
        #expect(read([narrow, .int]) == .int)
        #expect(read([.int, narrow]) == .int)
    }

    @Test("a parameter one field reads two ways is reported by the two that disagreed")
    func aFieldReadingTwoWaysReportsItsTwo() {
        // Given. A record read as a dictionary whose first field reads `T` as
        // a whole number and as text, and whose second reads it as truth
        let table = types.loweredTypes
        let slot = TypeExpression.dictionary(.record(["a": .parameter(name: "T"), "b": .parameter(name: "T")])).lowered(in: table)
        let handed = TypeExpression.record([
            "x": .record(["a": .int, "b": .string]),
            "y": .record(["a": .bool, "b": .bool])
        ]).lowered(in: table)
        var substitution = Substitution()

        // When
        slot.binding(against: handed, into: &substitution, in: table)

        // Then
        #expect(substitution.readings["T"] == .int)
        #expect(substitution.disagreeing["T"] == .string)
        #expect(Set(substitution.everyReading(of: "T").map { reading in reading.rendered(in: table) }) == ["Int", "String", "Bool"])
    }

    @Test("a parameter no call fills stands where a slot takes it by its structure, and nowhere else")
    func aRigidParameterStandsByStructure() {
        // Given. A parameter its own declaration reads, which no call fills.
        // `T?` is not written in a document, and a reading may still be one
        let table = types.loweredTypes
        let parameter = TypeExpression.parameter(name: "T").lowered(in: table)
        let other = TypeExpression.parameter(name: "U").lowered(in: table)

        // When / Then. A slot taking anything, its nullable, and an array of
        // that take it
        #expect(LoweredType.any.accepts(parameter, in: table, rigid: true))
        #expect(LoweredType.nullable(parameter).accepts(parameter, in: table, rigid: true))
        #expect(LoweredType.array(.nullable(parameter)).accepts(.array(parameter), in: table, rigid: true))

        // Then. A type it may not be, and another parameter, do not
        #expect(!LoweredType.int.accepts(parameter, in: table, rigid: true))
        #expect(!LoweredType.nullable(.int).accepts(parameter, in: table, rigid: true))
        #expect(!other.accepts(parameter, in: table, rigid: true))
    }

    @Test("a contract standing as a type takes a parameter no call fills only where the parameter's own bounds prove it")
    func aRigidParameterStandsInAContractByItsBounds() {
        // Given. Int, Double and String answer `App.Ordered`
        let table = types.loweredTypes
        let ordered = TypeExpression.composition(["App.Ordered"]).lowered(in: table)
        let bounded = TypeExpression.parameter(name: "T", bounds: ["App.Ordered"]).lowered(in: table)
        let unbounded = TypeExpression.parameter(name: "T").lowered(in: table)

        // When / Then. A parameter bounded by it answers it, and one bounded
        // by nothing may be anything
        #expect(ordered.accepts(bounded, in: table, rigid: true))
        #expect(!ordered.accepts(unbounded, in: table, rigid: true))
    }

    @Test("a name lowers to its row, and the row of the record it names is the chain's end")
    func aNameLowersToARow() throws {
        // Given
        let table = types.loweredTypes

        // When
        let alias = try #require(table.row(named: "Bank.Acct"))
        let account = try #require(table.row(named: "Bank.Account"))
        let byte = try #require(table.row(named: "App.Byte"))

        // Then. The alias names the account's record, and a range names none
        #expect(TypeExpression.named("Bank.Acct").lowered(in: table) == .named(alias))
        #expect(table.recordRows[alias] == account)
        #expect(table.recordRows[account] == account)
        #expect(table.recordRows[byte] == nil)
    }

    @Test("a projection lowers to itself, and every judgment answers it as Any")
    func aProjectionLowersToItself() throws {
        // Given
        let table = types.loweredTypes
        let projection = try TypeExpression.projection(of: "T", path: [.key("inner")]).lowered(in: table)

        // When / Then
        #expect(projection == .projection(of: "T", path: [.key("inner")]))
        #expect(try TypeExpression.array(.projection(of: "T", path: [])).lowered(in: table)
            == .array(.projection(of: "T", path: [])))
        #expect(LoweredType.int.accepts(projection, in: table))
        #expect(projection.accepts(.int, in: table))
        #expect(try projection.settling(.int(1), at: "", in: table) == .int(1))
    }

    @Test("a record settling into an alias slot takes the canonical name, and passes it again by comparison")
    func aRecordSettlesUnderTheCanonicalName() throws {
        // Given. A slot spelled with the alias, a nameless record, and one
        // already named by the alias
        let table = types.loweredTypes
        let slot = TypeExpression.named("Bank.Acct").lowered(in: table)
        let owner = Value.dictionary(["name": .string("a")])

        // When
        let settled = try slot.settling(.dictionary(["balance": .int(1), "owner": owner]), at: "input", in: table)
        let again = try slot.settling(settled, at: "input", in: table)
        let spelled = try slot.settling(
            .record(Record(name: "Bank.Acct", ["balance": .int(1), "owner": owner])),
            at: "input",
            in: table
        )

        // Then
        #expect(
            settled == .record(
                Record(name: "Bank.Account", ["balance": .int(1), "owner": .record(Record(name: "Bank.Owner", ["name": .string("a")]))])
            )
        )
        #expect(again == settled)
        #expect(spelled == settled)
        #expect {
            try slot.settling(.record(Record(name: "Bank.Owner", ["balance": .int(1), "owner": owner])), at: "input", in: table)
        } throws: { error in
            "\(error)".contains("is a Bank.Owner, and the slot declares Bank.Account")
        }
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
                        selector: "Standard.Math.max",
                        arguments: [.literal(.int(1)), .literal(.int(2))]
                    ))
                )
            ]
        )

        // When
        let image = try await builder.build([module] + Module.standard)
        let row = try #require(image["Standard.Math.max"])

        // Then
        #expect(row.slots.map(\.name) == ["lhs", "rhs"])
        #expect(row.slots.map(\.type) == [.parameter(label: "T", bounds: ["Standard.Comparable"]), .parameter(label: "T", bounds: ["Standard.Comparable"])])
        #expect(row.returns == .parameter(label: "T", bounds: ["Standard.Comparable"]))
        #expect(try await Executor().run(image) == .int(2))
    }

    @Test("a procedure type declared beside the types it names reads what they declare")
    func aProcedureTypeAmongDeclaredTypes() async throws {
        // Given. A declared record holding a procedure type whose parameter
        // names a declared nullable type, lowered while the table that holds
        // both rows is still being laid.
        let module = try Module(
            types: [
                "App.Maybe": .nullable(.int),
                "App.Kinds": .record([
                    "soft": .procedure(ProcedureType(parameters: [.named("App.Maybe")]), .unstated, .unstated)
                ])
            ],
            procedures: [
                "App.entry": Procedure(
                    access: .public,
                    signature: Signature(parameters: [Parameter(name: "k", type: .named("App.Kinds"))], returns: .int),
                    body: [],
                    result: .literal(.int(1))
                )
            ]
        )

        // When
        let compiled = try await Builder().compile([module] + Module.standard)
        let table = try #require(compiled.first { one in one.declared.contains("App.entry") }).types

        // Then. The parameter naming the nullable type need not be given.
        guard case let .record(fields)? = table["App.Kinds"],
            case let .procedure(soft?, _, _)? = fields["soft"]
        else {
            Issue.record("the declared record holds its procedure type")

            return
        }

        #expect(soft.parameters.first?.declaresNull(in: TypeTable(types: module.types)) == true)
    }

    @Test("one undeclared name passes every reading and is refused where a value meets it")
    func anUndeclaredNameTouchesOnlyItsOwnJudgments() {
        // Given. A table with one bad row beside a good one
        let table = TypeTable(types: ["App.Bad": .named("App.Missing"), "App.Good": .nullable(.int)])

        // When / Then
        #expect(TypeExpression.named("App.Good").declaresNull(in: table))
        #expect(TypeExpression.named("App.Good").accepts(.int, in: table))
        #expect(TypeExpression.named("App.Bad").accepts(.int, in: table))
        #expect(TypeExpression.int.accepts(.named("App.Bad"), in: table))
        #expect(TypeExpression.named("App.Bad").lowered(in: table.loweredTypes)
            .couldBothHold(reading: .int, in: table.loweredTypes))
        #expect(!TypeExpression.named("App.Bad").declaresNull(in: table))
        #expect {
            try TypeExpression.named("App.Bad").settling(.int(1), at: "input", in: table)
        } throws: { error in
            "\(error)".contains("input: declares type 'App.Missing', which nothing declares")
        }
    }

    @Test("a name that reaches itself under a wrapper is a cycle, and the value judge says so")
    func aCycleUnderAWrapperIsRefusedNotChased() {
        // Given. A table built by hand, which the build's refusals never saw
        let table = TypeTable(
            types: [
                "App.M": .nullable(.named("App.M")),
                "App.A": .variable(.named("App.B")),
                "App.B": .inout(.named("App.A")),
                "App.T": .nullable(.named("App.Leaf")),
                "App.Leaf": .int
            ]
        )

        // When / Then. Each cycle is refused where a value meets it, and a
        // chain that ends is walked to its end
        #expect {
            try TypeExpression.named("App.M").settling(.int(1), at: "input", in: table)
        } throws: { error in
            "\(error)".contains("input: declares type 'App.M', which names itself")
        }
        #expect {
            try TypeExpression.named("App.A").settling(.int(1), at: "input", in: table)
        } throws: { error in
            "\(error)".contains("input: declares type 'App.A', which names itself")
        }
        #expect(throws: Never.self) {
            try TypeExpression.named("App.T").settling(.int(1), at: "input", in: table)
        }
        #expect(TypeExpression.named("App.T").declaresNull(in: table))
    }

    @Test("a procedure another link made is refused by a run, not read by its rows")
    func aProcedureFromAnotherLinkIsRefused() async throws {
        // Given. A closure made by one image, handed to a run of another
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
        // Given. Neither link declares a type, so neither has a row a type
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
        // Given. A closure out of a run, judged with no declarations behind
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

    // MARK: - Public
    // MARK: - Private
}
