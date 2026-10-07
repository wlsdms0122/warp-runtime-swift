//
//  LoweredTypeTable.swift
//  Warp
//
//  Created by JSilver on 9/3/26.
//

import Foundation

// The declared types as the run reads them: by row. A
// declared name survives into the run as a row rather than being expanded,
// so a self-naming type is a type and not a regress, and a row is read
// by number. The spellings ride along for a refusal and for a record's
// name, and the one lookup by spelling left is a record that arrived under
// an alias, which is resolved once and then carries the canonical spelling.
// A class, so a judgment that recurses passes one reference down rather than
// a copy of every array the table holds.
final class LoweredTypeTable: Sendable {
    // What a reading standing where a contract is asked comes to. What the
    // type alone settles is settled here; a named type settles nothing,
    // since which types answer a contract is read off the claims of the whole
    // list, so the name comes back and the asker writes it down. Asked
    // rigidly, the documents settle it.
    enum Answering {
        case settled(Bool)
        case leansOn(Name)

        // MARK: - Property
        // MARK: - Initializer
        // MARK: - Public
        // MARK: - Private
    }

    // MARK: - Property
    // The declared types, in the order of their spellings.
    let loweredTypes: [LoweredType]

    let labels: [Name]

    // What this table's rows are numbered against. A compile or a link owns
    // one; a table a caller assembled is a place of its own.
    let linkage: Linkage

    // The row of the record a row names: the last declared name on the way
    // to a record type, so an alias of a declared record is that record
    // and not a second type. Nil where a row stands for no record.
    let recordRows: [Int?]

    // The rows that name themselves through a chain of names, and so stand
    // for no type. The lowering is where that is worked out, so it is what
    // says so.
    let cycling: [Int]

    // Which types satisfy each declared contract, by the contract's own
    // spelling. A contract's members are not a type the table lowers: what
    // puts a type in one is a document's claim, held to the declarations that
    // answer the procedures, which the link works out rather than the type
    // language.
    //
    // Every declared contract has an entry, so a name with none is a name no
    // document declared as a contract at all.
    let satisfying: [Name: Set<Name>]

    // Whether the claims above are the whole list's. A table a compile reads
    // is built from the documents standing so far, and a claim it never saw
    // may be what answers, so it says nothing about a contract and writes the
    // pair down instead. A table with nowhere to write is the link's, which
    // has every claim there is.
    let settled: Bool

    // Where a value this table cannot settle is written down, so the pair goes
    // to the list that can answer it. Nothing at the run, where the table is
    // the whole list's and settles everything it is asked.
    let unsettled: Fulfillment?

    private let rows: [Name: Int]

    // A table declaring nothing, for a judgment asked with no declarations
    // behind it. It belongs to no link, so no row belongs to it.
    static let empty = LoweredTypeTable(
        loweredTypes: [],
        labels: [],
        recordRows: [],
        of: Linkage()
    )

    // MARK: - Initializer
    init(
        loweredTypes: [LoweredType],
        labels: [Name],
        recordRows: [Int?],
        cycling: [Int] = [],
        satisfying: [Name: Set<Name>] = [:],
        settled: Bool = true,
        unsettled: Fulfillment? = nil,
        of linkage: Linkage
    ) {
        self.loweredTypes = loweredTypes
        self.labels = labels
        self.recordRows = recordRows
        self.cycling = cycling
        self.satisfying = satisfying
        self.settled = settled
        self.unsettled = unsettled
        self.linkage = linkage
        self.rows = Dictionary(uniqueKeysWithValues: labels.enumerated().map { row, label in (label, row) })
    }

    // MARK: - Public
    // The row a spelling declares, or nil where nothing declares it. For
    // lowering a document's type and for a record that arrived under an
    // alias; the run reads rows by number otherwise.
    func row(named name: Name) -> Int? {
        rows[name]
    }

    // Whether the type a value that arrived is an instance of answers every
    // procedure a contract asks. Nil where nothing declares the contract:
    // what an undeclared name means is the asking surface's.
    //
    // For a value already in hand and nothing else: a reading before the run
    // is not a name yet.
    func settles(contract name: Name, arrived type: Name?) -> Bool? {
        guard let members = satisfying[name] else { return nil }

        // A value that is an instance of no type a claim names answers no
        // contract, and no claim anywhere changes that, so a partial table
        // settles this one too.
        guard let type else { return false }
        guard settled else { return nil }

        return members.contains(type)
    }

    // Whether a name is a declared contract, which is the one thing a bound
    // names.
    func declaresContract(_ name: Name) -> Bool {
        satisfying[name] != nil
    }

    // One-sided the way every judgment before the run is: only what is
    // provably outside is refused, and a reading nothing can be said about
    // passes here and is judged again where the value arrives. `orNull` is
    // a slot taking null as well: what arrives is null or answers.
    func answering(contract name: Name, reading: LoweredType, orNull: Bool) -> Answering {
        answering(contract: name, reading: reading, rigid: false, orNull: orNull)
    }

    // Whether a reading stands where a contract bounds a slot. One-sided as
    // `answering` is, unless `rigid`: then nothing is judged where the value
    // arrives, so a named type is held to what the documents say, and a
    // parameter or a composition to what its bounds prove.
    func satisfies(contract name: Name, reading: LoweredType, rigid: Bool, orNull: Bool) -> Bool {
        if case .settled(false) = answering(contract: name, reading: reading, rigid: rigid, orNull: orNull) { false } else { true }
    }

    // The record a type names through the row it stands on, or nil where it
    // names none. An alias names what it stands for, so `App.A?` and an alias
    // of it name `App.A` alike. The one reading of `recordRows` for a type
    // that is not itself a row.
    func record(of type: LoweredType) -> Int? {
        guard let row = type.row else { return nil }

        return recordRows[row] ?? record(of: loweredTypes[row])
    }

    // The declarations as the run reads them. A link says which order its rows
    // stand in, so a document's types take a run of rows the way its
    // declarations do; where nothing says, the declared
    // spellings order them.
    //
    // Both spaces read the order from the same place. A run that stands where
    // its document does is a run a later document cannot move, which is what
    // lets a document already lowered keep the numbers it was lowered with.
    // Either way a row is a row of one table and nothing a link concludes
    // reads one to decide what to say. A name that names itself through a
    // chain of names stands for no type and lowers to the type every
    // judgment refuses, so a chain of names is always finite.
    static func lowering(
        _ types: [Name: TypeExpression],
        satisfying: [Name: Set<Name>] = [:],
        settled: Bool,
        unsettled: Fulfillment? = nil,
        standing: [Name]? = nil,
        of linkage: Linkage
    ) -> LoweredTypeTable {
        // A table of its own even where nothing is declared: a body carried
        // out of such a link holds rows a shared table would let be read
        // elsewhere.
        guard !types.isEmpty else {
            return LoweredTypeTable(
                loweredTypes: [],
                labels: [],
                recordRows: [],
                satisfying: satisfying,
                settled: settled,
                unsettled: unsettled,
                of: linkage
            )
        }

        let labels = standing ?? types.keys.sorted()

        // The index first, so a declaration naming another lowers against
        // rows that already exist whichever is declared first. The contracts
        // stand in it too: a field naming one is a slot the contract fills.
        let index = LoweredTypeTable(
            loweredTypes: [],
            labels: labels,
            recordRows: [],
            satisfying: satisfying,
            of: linkage
        )

        var loweredTypes = labels.map { label in (types[label] ?? .any).lowered(in: index) }

        // Whether a row's chain of names comes back on itself, a `?` on the
        // way included.
        func comesBack(from start: Int) -> Bool {
            var row = start
            var walked: [Int] = [start]

            while let next = loweredTypes[row].row {
                guard !walked.contains(next) else { return true }

                walked.append(next)
                row = next
            }

            return false
        }

        // Marked before any is replaced, so each row in a cycle is named
        // as itself rather than as whichever the replacement reached first.
        let cycling = loweredTypes.indices.filter { row in comesBack(from: row) }

        for row in cycling {
            loweredTypes[row] = .undeclared(label: labels[row].spelling, because: .namesItself)
        }

        // The record a row names: the last row on the way to a record type,
        // along names alone, since a name for what may be null names no
        // record. Every chain is finite by now.
        let recordRows = loweredTypes.indices.map { start -> Int? in
            var row = start

            while case let .named(next) = loweredTypes[row] {
                row = next
            }

            guard case .record = loweredTypes[row] else { return nil }

            return row
        }

        return LoweredTypeTable(
            loweredTypes: loweredTypes,
            labels: labels,
            recordRows: recordRows,
            cycling: cycling,
            satisfying: satisfying,
            settled: settled,
            unsettled: unsettled,
            of: linkage
        )
    }

    // MARK: - Private
    // What a slot reads a value as: its own marks off, and where it takes null
    // as well, null off too, nil where null is all the value is.
    private func read(_ given: LoweredType, orNull: Bool) -> LoweredType? {
        let reading = given.slotUnwrapped

        return orNull ? besidesNull(reading) : reading
    }

    // What a reading is besides null, or nil where null is all it is.
    private func besidesNull(_ reading: LoweredType) -> LoweredType? {
        switch reading {
        case .null:
            return nil

        case let .nullable(inner):
            return besidesNull(inner)

        case let .named(row) where reading.declaresNull(in: self):
            return besidesNull(loweredTypes[row])

        default:
            return reading
        }
    }

    private func answering(
        contract name: Name,
        reading given: LoweredType,
        rigid: Bool,
        orNull: Bool
    ) -> Answering {
        guard let reading = read(given, orNull: orNull) else { return .settled(true) }

        switch reading {
        case .any, .projection, .undeclared, .never:
            return .settled(true)

        // A contract is answered by a type, and null wears none, so what may
        // be null answers no contract, a name for such a type included,
        // unless the slot takes null as well: then null was taken above and
        // the rest answers.
        case _ where !orNull && reading.declaresNull(in: self):
            return .settled(false)

        // A name that stands for no record answers as what it stands for,
        // since a value of it is an instance of that.
        case let .named(row) where recordRows[row] == nil:
            return answering(contract: name, reading: loweredTypes[row], rigid: rigid, orNull: orNull)

        // A parameter stands for whatever fills it, and a call fills it with
        // something every bound was asked of, so one bounded by the contract
        // answers and one bounded by nothing that answers is refused: a slot
        // says what a call may fill it with. A composition bounded by the
        // contract answers too; one bounded by other contracts alone stands
        // for a type nothing here lists, so nothing is provable and it passes
        // to be judged where the value arrives, unless `rigid`.
        case let .parameter(_, bounds):
            return .settled(bounds.contains(name))

        case let .composition(bounds):
            return .settled(bounds.contains(name) || !rigid)

        // A reading of a type a value is an instance of answers as that type
        // does: by what the documents claim about it, so the type comes back
        // and the asker writes it down. Where nothing is judged on arrival, or
        // the table holds every claim there is, it is held to what the
        // documents say. A reading that is an instance of no type a claim
        // names answers nothing.
        default:
            guard let type = reading.nominal(in: self) else { return .settled(false) }
            guard !rigid, !settled else { return .settled(settles(contract: name, arrived: type) != false) }

            return .leansOn(type)
        }
    }
}
