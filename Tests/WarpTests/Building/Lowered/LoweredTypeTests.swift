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
            "app.Ordered": [.int, .double, .string],
            "app.Numbers": [.int, .double],
            "app.Lists": [.array(.int), .array(.double)],
            "app.NumberLists": [.array(.named("app.Numbers"))]
        ]
    )

    // MARK: - Initializer
    // MARK: - Test
    @Test("a lowered type renders as the author wrote it")
    func aLoweredTypeRendersAsWritten() throws {
        // Given. Every declared type, and a few that name them
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

    @Test("a membership takes a parameter no call fills only where the parameter's own bounds prove it")
    func aRigidParameterStandsInAMembershipByItsBounds() {
        // Given. `app.Ordered` admits int, double and string
        let table = types.loweredTypes
        let ordered = TypeExpression.composition(["app.Ordered"]).lowered(in: table)
        let bounded = TypeExpression.parameter(name: "T", constraints: ["app.Ordered"]).lowered(in: table)
        let unbounded = TypeExpression.parameter(name: "T").lowered(in: table)

        // When / Then. A parameter bounded by it is one of its members, and
        // one bounded by nothing may be anything
        #expect(ordered.accepts(bounded, in: table, rigid: true))
        #expect(!ordered.accepts(unbounded, in: table, rigid: true))
    }

    @Test("a membership takes a list of a parameter no call fills only where the parameter's bounds prove each element")
    func aRigidParameterInsideAListStandsByItsBounds() {
        // Given. `app.Lists` admits lists of ints and of doubles, and
        // `app.NumberLists` lists of `app.Numbers`
        let table = types.loweredTypes
        let lists = TypeExpression.composition(["app.Lists"]).lowered(in: table)
        let numberLists = TypeExpression.composition(["app.NumberLists"]).lowered(in: table)
        let unbounded = LoweredType.array(TypeExpression.parameter(name: "T").lowered(in: table))
        let bounded = LoweredType.array(TypeExpression.parameter(name: "T", constraints: ["app.Numbers"]).lowered(in: table))

        // When / Then. A list of what may be anything is no member, and a
        // list of a parameter every member of whose bound is admitted is
        #expect(!lists.accepts(unbounded, in: table, rigid: true))
        #expect(!numberLists.accepts(unbounded, in: table, rigid: true))
        #expect(numberLists.accepts(bounded, in: table, rigid: true))
    }

    @Test("a name lowers to its row, and the row of the record it names is the chain's end")
    func aNameLowersToARow() throws {
        // Given
        let table = types.loweredTypes

        // When
        let alias = try #require(table.row(named: "bank.Acct"))
        let account = try #require(table.row(named: "bank.Account"))
        let byte = try #require(table.row(named: "app.Byte"))

        // Then. The alias names the account's record, and a range names none
        #expect(TypeExpression.named("bank.Acct").lowered(in: table) == .named(alias))
        #expect(table.recordRows[alias] == account)
        #expect(table.recordRows[account] == account)
        #expect(table.recordRows[byte] == nil)
    }

    @Test("a projection lowers to itself, and every judgment answers it as any")
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
        #expect(row.slots.map(\.name) == ["lhs", "rhs"])
        #expect(row.slots.map(\.type) == [.parameter(label: "T", bounds: [.membership(ordered)]), .parameter(label: "T", bounds: [.membership(ordered)])])
        #expect(row.returns == .bool)
        #expect(try await Executor().run(image) == .bool(true))
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

    @Test("one undeclared name passes every reading and is refused where a value meets it")
    func anUndeclaredNameTouchesOnlyItsOwnJudgments() {
        // Given. A table with one bad row beside a good one
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
        // Given. A table built by hand, which the build's refusals never saw
        let table = TypeTable(
            types: [
                "app.M": .nullable(.named("app.M")),
                "app.A": .variable(.named("app.B")),
                "app.B": .inout(.named("app.A")),
                "app.T": .nullable(.named("app.Leaf")),
                "app.Leaf": .int
            ]
        )

        // When / Then. Each cycle is refused where a value meets it, and a
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
