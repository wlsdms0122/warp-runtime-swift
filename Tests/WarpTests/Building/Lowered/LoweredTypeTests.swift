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
            "Bank.Account": .struct(["balance": .int, "owner": .named("Bank.Owner")]),
            "Bank.Owner": .struct(["name": .string]),
            "Bank.Acct": .alias(.named("Bank.Account")),
            "App.Whole": .alias(.int),
            "App.Maybe": .alias(.nullable(.int))
        ],
        contracts: ["App.Ordered": [:]],
        satisfying: ["App.Ordered": ["Int": "Int", "Double": "Double", "String": "String"]],
        of: Linkage()
    )

    // Every declared type as a document writes it where it is read: a struct
    // by its name, and an alias as what it stands for.
    private var declaredTypes: [TypeExpression] {
        types.types.map { name, declared in
            guard case let .alias(type) = declared else { return .named(name) }

            return type
        }
    }

    // MARK: - Initializer
    // MARK: - Test
    @Test("a lowered type renders as the author wrote it, an alias as what it stands for")
    func aLoweredTypeRendersAsWritten() throws {
        // Given. Every declared type, and a few that name them
        let table = types.loweredTypes
        let written: [TypeExpression] = declaredTypes + [
            .nullable(.named("Bank.Owner")),
            .parameter(name: "T"),
            .procedure(ProcedureType(parameters: [.named("Bank.Account")], returns: .int), .const)
        ]

        // When / Then
        for type in written {
            #expect(type.lowered(in: table).rendered(in: table) == type.rendered, "\(type.rendered)")
        }

        #expect(TypeExpression.array(.named("Bank.Acct")).lowered(in: table).rendered(in: table) == "Array<Bank.Account>")
        #expect(TypeExpression.dictionary(key: .string, value: .named("App.Maybe")).lowered(in: table).rendered(in: table) == "Dictionary<String, Int?>")
    }

    @Test("a lowered type spells back to a type that lowers to it")
    func aLoweredTypeSpellsBack() throws {
        // Given. Every declared type, and a few that name them, a procedure
        // type among them
        let table = types.loweredTypes
        let written: [TypeExpression] = declaredTypes + [
            .array(.named("Bank.Acct")),
            .nullable(.named("Bank.Owner")),
            .parameter(name: "T"),
            .procedure(ProcedureType(parameters: [.named("Bank.Account")], returns: .int), .const),
            .procedure(nil),
            .named("App.Ordered")
        ]

        // When / Then
        for type in written {
            let lowered = type.lowered(in: table)

            #expect(lowered.spelled(in: table).lowered(in: table) == lowered, "\(type.rendered)")
        }
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
        #expect(LoweredType.any.accepts(parameter, in: table))
        #expect(LoweredType.nullable(parameter).accepts(parameter, in: table))
        #expect(LoweredType.array(.nullable(parameter)).accepts(.array(parameter), in: table))

        // Then. A type it may not be, and another parameter, do not
        #expect(!LoweredType.int.accepts(parameter, in: table))
        #expect(!LoweredType.nullable(.int).accepts(parameter, in: table))
        #expect(!other.accepts(parameter, in: table))
    }

    @Test("a contract standing as a type takes a parameter no call fills only where the parameter's own bounds prove it")
    func aRigidParameterStandsInAContractByItsBounds() {
        // Given. Int, Double and String answer `App.Ordered`
        let table = types.loweredTypes
        let ordered = TypeExpression.composition(["App.Ordered"]).lowered(in: table)
        let bounded = TypeExpression.parameter(name: "T").lowered(in: table, bounds: ["T": ["App.Ordered"]])
        let unbounded = TypeExpression.parameter(name: "T").lowered(in: table)

        // When / Then. A parameter bounded by it answers it, and one bounded
        // by nothing may be anything
        #expect(ordered.accepts(bounded, in: table))
        #expect(!ordered.accepts(unbounded, in: table))
    }

    @Test("a struct's name lowers to its row, and an alias to what it stands for")
    func aNameLowersToARow() throws {
        // Given
        let table = types.loweredTypes

        // When
        let account = try #require(table.row(named: "Bank.Account"))

        // Then. The alias is the account's struct, and a name for a type the
        // language names names none
        #expect(TypeExpression.named("Bank.Acct").lowered(in: table) == .named(account))
        #expect(TypeExpression.named("App.Whole").lowered(in: table) == .int)
        #expect(table.structRow(named: "Bank.Acct") == account)
        #expect(table.structRow(named: "Bank.Account") == account)
        #expect(table.structRow(named: "App.Whole") == nil)
    }

    @Test("a struct handed in under an alias's name takes its struct's name, settles again by comparison, and a map is refused")
    func aStructSettlesUnderTheCanonicalName() throws {
        // Given. A slot spelled with the alias, and a struct a door is handed
        // under the alias's name
        let table = types.loweredTypes
        let slot = TypeExpression.named("Bank.Acct").lowered(in: table)
        let owner = Value.struct(Struct(name: "Bank.Owner", ["name": .string("a")]))

        // When
        let settled = try slot.settling(
            outside: .struct(Struct(name: "Bank.Acct", ["balance": .int(1), "owner": owner])),
            at: "input",
            in: table
        )
        let again = try slot.settling(settled, at: "input", in: table)

        // Then
        #expect(
            settled == .struct(
                Struct(name: "Bank.Account", ["balance": .int(1), "owner": .struct(Struct(name: "Bank.Owner", ["name": .string("a")]))])
            )
        )
        #expect(again == settled)
        #expect {
            try slot.settling(.struct(Struct(name: "Bank.Owner", ["balance": .int(1), "owner": owner])), at: "input", in: table)
        } throws: { error in
            "\(error)".contains("is a Bank.Owner, and the slot declares Bank.Account")
        }
        #expect(throws: ArgumentError.self) {
            try slot.settling(.dictionary(["balance": .int(1), "owner": owner]), at: "input", in: table)
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
        // Given. A declared struct holding a procedure type whose parameter
        // names a declared nullable type.
        let module = try Module(
            types: [
                "App.Maybe": .alias(.nullable(.int)),
                "App.Kinds": .struct([
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
        guard case let .struct(fields, _, _)? = table["App.Kinds"],
            case let .procedure(soft?, _, _)? = fields["soft"]
        else {
            Issue.record("the declared struct holds its procedure type")

            return
        }

        #expect(soft.parameters.first?.declaresNull(in: try TypeTable(types: module.types)) == true)
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
                    signature: Signature(parameters: [Parameter(name: "held", type: .procedure(ProcedureType(returns: .int)))]),
                    body: [],
                    result: .apply(.reference([.name("held")]), arguments: [])
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
                    signature: Signature(parameters: [Parameter(name: "held", type: .procedure(ProcedureType(returns: .int)))]),
                    body: [],
                    result: .apply(.reference([.name("held")]), arguments: [])
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

    @Test("a judgement says the rule, rather than naming a link nobody named")
    func aJudgementWithNoLinkSaysTheRule() async throws {
        // Given. A closure out of a run, judged with no declarations behind
        // the judgement. Which link this one came from is not knowable where
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
            try TypeExpression.procedure(nil).settling(made, at: "input 'held'")
        } throws: { error in
            "\(error)".contains("read where the link that made it is being read")
        }
    }

    // MARK: - Public
    // MARK: - Private
}
