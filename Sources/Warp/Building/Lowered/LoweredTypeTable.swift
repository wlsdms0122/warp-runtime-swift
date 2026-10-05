//
//  LoweredTypeTable.swift
//  Warp
//
//  Created by JSilver on 9/3/26.
//

import Foundation

// The declared types and constraints as the run reads them: by row. A
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
        case leansOn([Name])

        // MARK: - Property
        // MARK: - Initializer
        // MARK: - Public
        // Two answers about one contract from two memberships one value belongs
        // to, read as one: what either settles is settled, what both refuse is
        // refused, and what one alone leans on is leaned on. Where both lean, a
        // claim written down is one every name has to answer, and one of the
        // two would do, so nothing is written and the value is judged where it
        // arrives.
        func either(_ other: LoweredTypeTable.Answering) -> LoweredTypeTable.Answering {
            switch (self, other) {
            case (.settled(true), _), (_, .settled(true)), (.leansOn, .leansOn):
                .settled(true)

            case let (.leansOn(names), .settled(false)), let (.settled(false), .leansOn(names)):
                .leansOn(names)

            case (.settled(false), .settled(false)):
                .settled(false)
            }
        }

        // Two answers about one contract read as one: a refusal on either side
        // refuses, what either side leans on is leaned on, and settled otherwise.
        func joined(_ other: LoweredTypeTable.Answering) -> LoweredTypeTable.Answering {
            switch (self, other) {
            case (.settled(false), _), (_, .settled(false)):
                .settled(false)

            case let (.leansOn(mine), .leansOn(theirs)):
                .leansOn(mine + theirs)

            case let (.leansOn(names), .settled), let (.settled, .leansOn(names)):
                .leansOn(names)

            case (.settled, .settled):
                .settled(true)
            }
        }

        // MARK: - Private
    }

    // MARK: - Property
    // The declared types, in the order of their spellings.
    let loweredTypes: [LoweredType]

    // The members of each declared constraint, in the order of their
    // spellings.
    let constraints: [[LoweredType]]

    let labels: [Name]
    let constraintLabels: [Name]

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
    private let constraintRows: [Name: Int]

    // A table declaring nothing, for a judgment asked with no declarations
    // behind it. It belongs to no link, so no row belongs to it.
    static let empty = LoweredTypeTable(
        loweredTypes: [],
        constraints: [],
        labels: [],
        constraintLabels: [],
        recordRows: [],
        of: Linkage()
    )

    // MARK: - Initializer
    init(
        loweredTypes: [LoweredType],
        constraints: [[LoweredType]],
        labels: [Name],
        constraintLabels: [Name],
        recordRows: [Int?],
        cycling: [Int] = [],
        satisfying: [Name: Set<Name>] = [:],
        settled: Bool = true,
        unsettled: Fulfillment? = nil,
        of linkage: Linkage
    ) {
        self.loweredTypes = loweredTypes
        self.constraints = constraints
        self.labels = labels
        self.constraintLabels = constraintLabels
        self.recordRows = recordRows
        self.cycling = cycling
        self.satisfying = satisfying
        self.settled = settled
        self.unsettled = unsettled
        self.linkage = linkage
        self.rows = Dictionary(uniqueKeysWithValues: labels.enumerated().map { row, label in (label, row) })
        self.constraintRows = Dictionary(
            uniqueKeysWithValues: constraintLabels.enumerated().map { row, label in (label, row) }
        )
    }

    // MARK: - Public
    // The row a spelling declares, or nil where nothing declares it. For
    // lowering a document's type and for a record that arrived under an
    // alias; the run reads rows by number otherwise.
    func row(named name: Name) -> Int? {
        rows[name]
    }

    func constraintRow(named name: Name) -> Int? {
        constraintRows[name]
    }

    // Whether the type a value arrived wearing answers every procedure a contract
    // asks. Nil where nothing declares the contract, the way an undeclared
    // constraint answers nil: what an undeclared name means is the asking
    // surface's.
    //
    // For a value already in hand and nothing else: a reading before the run
    // is not a name yet.
    func settles(contract name: Name, arrived type: Name?) -> Bool? {
        guard let members = satisfying[name] else { return nil }

        // A value wearing no name answers no contract, and no claim anywhere
        // changes that, so a partial table settles this one too.
        guard let type else { return false }
        guard settled else { return nil }

        return members.contains(type)
    }

    // The bound a name stands for: a membership by its row, a contract by
    // its name, and nothing where the name is neither.
    func bound(named name: Name) -> LoweredType.Bound? {
        if let row = constraintRow(named: name) {
            return .membership(row)
        }

        return satisfying[name] != nil ? .contract(name) : nil
    }

    // One-sided the way every judgment before the run is: only what is
    // provably outside is refused, and a reading nothing can be said about
    // passes here and is judged again where the value arrives. `orNull` is
    // a slot taking null as well: what arrives is null or answers.
    func answering(contract name: Name, reading: LoweredType, orNull: Bool) -> Answering {
        answering(contract: name, reading: reading, assumingRows: [], rigid: false, orNull: orNull)
    }

    // Whether a reading stands where a contract bounds a slot. One-sided as
    // `answering` is, unless `rigid`: then nothing is judged where the value
    // arrives, so a named type is held to what the documents say, and a
    // parameter or a composition to what its bounds prove.
    func satisfies(contract name: Name, reading: LoweredType, rigid: Bool, orNull: Bool) -> Bool {
        if case .settled(false) = answering(contract: name, reading: reading, assumingRows: [], rigid: rigid, orNull: orNull) { false } else { true }
    }

    // Whether a value is a member of a constraint. A member speaks through
    // the same settlement a declared type applies, so what `int` admits as a
    // slot it admits as a member, widening included. `asking` is what the
    // caller was already asking; this constraint joins it only where a
    // member has to be settled to answer, since a scalar member answers by
    // kind.
    func admits(constraint row: Int, value: Value, asking: [Int]) -> Bool {
        constraints[row].contains { member in
            member.admitsAsScalar(value)
                ?? member.settles(value, in: self, asking: asking + [row])
        }
    }

    // Whether a reading could be a member of a constraint. Membership is
    // one-sided the way every judgment before the run is: only what is
    // provably outside is refused, and a reading nothing can be said about
    // passes here and is judged again where the value arrives. `rigid` turns
    // it the other way for a parameter no call fills, as `accepts` does: such
    // a parameter is known by its bounds alone and no value of it is judged
    // where it arrives, so it is a member only where its bounds prove it.
    //
    // A constrained reading is judged by its own membership rather than by
    // its name: it stands for some member of its constraint, so it fits
    // where every one of those members would. `orNull` is a slot taking null
    // as well, so a reading that may be null is held by what it is besides.
    func admits(constraint row: Int, reading given: LoweredType, rigid: Bool, orNull: Bool) -> Bool {
        admits(constraint: row, reading: given, assumingRows: [], assumingPairs: [], asking: [], rigid: rigid, orNull: orNull)
    }

    // The same question, carrying what is already being asked. Three lists
    // ride along. `assumingRows` is the memberships a constrained reading
    // came through, whose members met again add nothing. `assumingPairs` and
    // `asking` are what `accepts` carries, the pairs met on the way, which
    // hold met again, and the memberships asked of this very reading, which
    // refuse met again.
    func admits(
        constraint row: Int,
        reading given: LoweredType,
        assumingRows: [Int],
        assumingPairs: [(LoweredType, LoweredType)],
        asking: [Int],
        rigid: Bool,
        orNull: Bool
    ) -> Bool {
        guard let reading = read(given, orNull: orNull) else { return true }

        switch reading {
        case .any, .projection:
            return true

        // A parameter bounded by a membership stands for some member of it, so
        // it fits where every one of those would. One bounded by contracts
        // alone stands for a type nothing here lists, so nothing is provable
        // and it passes the way an unbounded one does, unless `rigid`. A
        // membership already being asked answers yes.
        case let .parameter(_, bounds), let .composition(bounds):
            let bounded = bounds.contains { bound in
                if case .membership = bound { true } else { false }
            }

            guard bounded || !rigid else { return false }

            let memberships = bounds.compactMap { bound -> Int? in
                guard case let .membership(constraint) = bound, !assumingRows.contains(constraint) else { return nil }

                return constraint
            }

            guard !memberships.isEmpty else { return true }

            return memberships.contains { constraint in
                constraints[constraint].allSatisfy { member in
                    admits(constraint: row, reading: member, assumingRows: assumingRows + [constraint], assumingPairs: assumingPairs, asking: [], rigid: rigid, orNull: orNull)
                }
            }

        // A reading that may be null is a member where null is one and what it
        // is besides is too, since its value is one or the other. A name that
        // stands for no record is read as what it stands for.
        case let .nullable(inner):
            return admits(constraint: row, reading: .null, assumingRows: assumingRows, assumingPairs: assumingPairs, asking: [], rigid: rigid, orNull: false)
                && admits(constraint: row, reading: inner, assumingRows: assumingRows, assumingPairs: assumingPairs, asking: asking, rigid: rigid, orNull: false)

        case .named where reading.throughAliases(in: self) != reading:
            return admits(
                constraint: row,
                reading: reading.throughAliases(in: self),
                assumingRows: assumingRows,
                assumingPairs: assumingPairs,
                asking: asking,
                rigid: rigid,
                orNull: false
            )

        // Nothing can be said about a reading the table does not answer, so
        // it passes here and is refused where the name is met.
        case .undeclared:
            return true

        // Each member is asked with what is being asked here: the pairs, and
        // this membership joining the memberships asked of this reading.
        default:
            let asked = asking + [row]

            return constraints[row].contains { member in
                member.accepts(reading, in: self, assuming: assumingPairs, asking: asked, rigid: rigid)
            }
        }
    }

    // The record a type names through the row it stands on, or nil where it
    // names none. The one reading of `recordRows` for a type that is not
    // itself a row.
    func record(of type: LoweredType) -> Int? {
        type.row.flatMap { row in recordRows[row] }
    }

    // The declarations as the run reads them. A link says which order its rows
    // stand in, so a document's types and its memberships each take a run of
    // rows the way its declarations do; where nothing says, the declared
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
        constraints: [Name: [TypeExpression]],
        satisfying: [Name: Set<Name>] = [:],
        settled: Bool,
        unsettled: Fulfillment? = nil,
        standing: [Name]? = nil,
        constraintStanding: [Name]? = nil,
        of linkage: Linkage
    ) -> LoweredTypeTable {
        // A table of its own even where nothing is declared: a body carried
        // out of such a link holds rows a shared table would let be read
        // elsewhere.
        guard !types.isEmpty || !constraints.isEmpty else {
            return LoweredTypeTable(
                loweredTypes: [],
                constraints: [],
                labels: [],
                constraintLabels: [],
                recordRows: [],
                satisfying: satisfying,
                settled: settled,
                unsettled: unsettled,
                of: linkage
            )
        }

        let labels = standing ?? types.keys.sorted()
        let constraintLabels = constraintStanding ?? constraints.keys.sorted()

        // The index first, so a declaration naming another lowers against
        // rows that already exist whichever is declared first. The contracts
        // stand in it too: a field naming one is a slot the contract fills.
        let index = LoweredTypeTable(
            loweredTypes: [],
            constraints: [],
            labels: labels,
            constraintLabels: constraintLabels,
            recordRows: [],
            satisfying: satisfying,
            of: linkage
        )

        var loweredTypes = labels.map { label in (types[label] ?? .any).lowered(in: index) }
        let members = constraintLabels.map { label in
            (constraints[label] ?? []).map { member in member.lowered(in: index) }
        }

        // The end of each row's chain of names, or nil where the chain comes
        // back on itself.
        func end(of start: Int) -> Int? {
            var row = start
            var walked: [Int] = [start]

            while let next = loweredTypes[row].row {
                guard !walked.contains(next) else { return nil }

                walked.append(next)
                row = next
            }

            return row
        }

        // Marked before any is replaced, so each row in a cycle is named
        // as itself rather than as whichever the replacement reached first.
        let cycling = loweredTypes.indices.filter { row in end(of: row) == nil }

        for row in cycling {
            loweredTypes[row] = .undeclared(label: labels[row].spelling, because: .namesItself)
        }

        // The record a row names: the last row on the way to a record type.
        let recordRows = loweredTypes.indices.map { start -> Int? in
            guard let row = end(of: start), case .record = loweredTypes[row] else { return nil }

            return row
        }

        return LoweredTypeTable(
            loweredTypes: loweredTypes,
            constraints: members,
            labels: labels,
            constraintLabels: constraintLabels,
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

    // What a reading is besides null, or nil where null is all it is. A
    // membership with a member that may be null stands as it is, and is
    // asked member by member.
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
        assumingRows: [Int],
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
        // the rest answers. A membership with a member that may be null is
        // asked member by member below.
        case _ where !orNull && reading.declaresNull(in: self):
            return .settled(false)

        // A name for a record answers as that record, since a value settled
        // under it wears the record's name; where nothing is judged on
        // arrival, it is held to what the documents say about it. Any other
        // name answers as what it stands for, since a value of it wears none.
        case let .named(row) where recordRows[row] == nil:
            return answering(contract: name, reading: loweredTypes[row], assumingRows: assumingRows, rigid: rigid, orNull: orNull)

        case let .named(row) where rigid:
            return .settled(settles(contract: name, arrived: labels[recordRows[row] ?? row]) != false)

        case let .named(row):
            return .leansOn([labels[recordRows[row] ?? row]])

        // A parameter stands for whatever fills it, and a call fills it with
        // something every bound was asked of. A composition bounded by the
        // contract answers; one bounded by memberships answers where every
        // member of some membership does, since its value is one of them.
        // A parameter bounded by nothing that answers is refused, since a
        // slot says what a call may fill it with; a composition bounded by
        // contracts alone stands for a type nothing here lists, so nothing
        // is provable and it passes to be judged where the value arrives,
        // unless `rigid`.
        case let .parameter(_, bounds):
            return answering(contract: name, boundedBy: bounds, assumingRows: assumingRows, rigid: rigid, orNull: orNull) ?? .settled(false)

        case let .composition(bounds):
            return answering(contract: name, boundedBy: bounds, assumingRows: assumingRows, rigid: rigid, orNull: orNull) ?? .settled(!rigid)

        default:
            return .settled(false)
        }
    }

    // What bounds answer about a contract, or nothing where none of them
    // says anything: a bound naming the contract settles it, and a
    // membership answers where every member does. Memberships are asked
    // apart, since a value is a member of each of them: one that settles the
    // contract settles it for all, and what leans on claims is leaned on only
    // where no membership settles it.
    private func answering(
        contract name: Name,
        boundedBy bounds: [LoweredType.Bound],
        assumingRows: [Int],
        rigid: Bool,
        orNull: Bool
    ) -> Answering? {
        guard !bounds.contains(.contract(name)) else { return .settled(true) }

        var answers: [Answering] = []

        for bound in bounds {
            guard case let .membership(row) = bound, !assumingRows.contains(row) else { continue }

            answers.append(constraints[row].reduce(.settled(true)) { answered, member in
                answered.joined(answering(contract: name, reading: member, assumingRows: assumingRows + [row], rigid: rigid, orNull: orNull))
            })
        }

        return answers.reduce(nil) { answered, next in answered.map { answered in answered.either(next) } ?? next }
    }
}

