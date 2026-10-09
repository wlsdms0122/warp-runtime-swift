//
//  LoweredTypeTable.swift
//  Warp
//
//  Created by JSilver on 9/3/26.
//

import Foundation

// The declared types as the run reads them: by row. A declared record
// survives into the run as a row rather than being expanded, since it is
// nominal and may name itself, and a row is read by number. An alias is a
// spelling: a mention of it lowers to what it stands for, so no judgement
// meets one, and only an alias that comes back to itself through a
// structure stays a row, since no finite type spells it. The spellings ride
// along for a refusal and for a record's name. A class, so a judgement that
// recurses passes one reference down rather than a copy of every array the
// table holds.
final class LoweredTypeTable: Sendable {
    // What a reading standing where a contract is asked comes to. What the
    // type alone settles is settled here; a named type settles nothing,
    // since which types answer a contract is read off the claims of the whole
    // list, so the names come back and the asker writes them down. Asked
    // rigidly, the documents settle it.
    enum Answering {
        case settled(Bool)
        case leansOn([Name])

        // MARK: - Property
        // MARK: - Initializer
        // MARK: - Public
        // What a reading comes to where it answers only if both parts do.
        func and(_ other: Answering) -> Answering {
            switch (self, other) {
            case (.settled(false), _), (_, .settled(false)):
                return .settled(false)

            case (.settled(true), _):
                return other

            case (_, .settled(true)):
                return self

            case let (.leansOn(mine), .leansOn(theirs)):
                return .leansOn(mine + theirs)
            }
        }

        // MARK: - Private
    }

    // MARK: - Property
    // The declared types, in the order of their spellings.
    let loweredTypes: [LoweredType]

    let labels: [Name]

    // What this table's rows are numbered against. A compile or a link owns
    // one; a table a caller assembled is a place of its own.
    let linkage: Linkage

    // The row of the record a row names: its own where it is a record, and
    // the record's where it is an alias of one, so a value from outside
    // under an alias's spelling is that record's. Nil where a row stands for
    // no record.
    let recordRows: [Int?]

    // The rows that name themselves through a chain of names, and so stand
    // for no type. The lowering is where that is worked out, so it is what
    // says so.
    let cycling: [Int]

    // The rows a mention keeps as a row: every declared record, and every
    // alias that comes back to itself through a structure.
    let namedRows: Set<Int>

    // Which types satisfy each declared contract, by the contract's own
    // spelling. Which types those are is no type the table lowers: what puts
    // a type under a contract is a document's claim, held to the declarations
    // that answer the procedures, which the link works out rather than the
    // type language.
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

    // A table declaring nothing, for a judgement asked with no declarations
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
        namedRows: Set<Int> = [],
        satisfying: [Name: Set<Name>] = [:],
        settled: Bool = true,
        unsettled: Fulfillment? = nil,
        of linkage: Linkage
    ) {
        self.loweredTypes = loweredTypes
        self.labels = labels
        self.recordRows = recordRows
        self.cycling = cycling
        self.namedRows = namedRows
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

    // What a mention of a row lowers to: the row, where it is kept as one,
    // and what the alias stands for otherwise.
    func mention(of row: Int) -> LoweredType {
        namedRows.contains(row) ? .named(row) : loweredTypes[row]
    }

    // Whether a type answers every procedure a contract asks, by what the
    // documents claim about it. Nil where nothing declares the contract, what
    // an undeclared name means being for whoever asked to say, and where the
    // table does not hold every claim there is.
    func settles(contract name: Name, arrived type: Name) -> Bool? {
        guard let claimed = satisfying[name] else { return nil }
        guard settled else { return nil }

        return claimed.contains(type)
    }

    // Whether a name is a declared contract, which is the one thing a bound
    // names.
    func declaresContract(_ name: Name) -> Bool {
        satisfying[name] != nil
    }

    // Whether a reading answers a contract, by what the documents claim
    // about its type. A reading whose type the build does not know answers
    // none until a cast says what it is. `orNull` is a slot taking null as
    // well: what arrives is null or answers.
    func answering(contract name: Name, reading: LoweredType, orNull: Bool) -> Answering {
        answering(contract: name, reading: reading, rigid: false, orNull: orNull)
    }

    // Whether a reading stands where a contract bounds a slot. A claim this
    // table cannot settle passes, for the link to settle, unless `rigid`:
    // then a named type is held to what the documents standing so far say.
    func satisfies(contract name: Name, reading: LoweredType, rigid: Bool, orNull: Bool) -> Bool {
        if case .settled(false) = answering(contract: name, reading: reading, rigid: rigid, orNull: orNull) { false } else { true }
    }

    // The record a type names through the row it stands on, or nil where it
    // names none.
    func record(of type: LoweredType) -> Int? {
        type.row.flatMap { row in recordRows[row] }
    }

    // The declarations as the run reads them. A link says which order its rows
    // stand in, so a document's types take a run of rows the way its
    // declarations do; where nothing says, the declared spellings order them.
    //
    // A run that stands where its document does is a run a later document
    // cannot move, which is what lets a document already lowered keep the
    // numbers it was lowered with. Either way a row is a row of one table and
    // nothing a link concludes reads one to decide what to say. A name that
    // names itself through a chain of names stands for no type and lowers to
    // `Never`, so a chain of names is always finite; `cycling` keeps which
    // ones did, for the build to refuse.
    static func lowering(
        _ types: [Name: TypeExpression],
        satisfying: [Name: Set<Name>] = [:],
        settled: Bool,
        unsettled: Fulfillment? = nil,
        standing: [Name]? = nil,
        of linkage: Linkage
    ) -> LoweredTypeTable {
        let labels = standing ?? types.keys.sorted()

        // The index first, every mention kept as a row, so a declaration
        // naming another lowers against rows that already exist whichever is
        // declared first. The contracts stand in it too: a field naming one
        // is a slot the contract fills.
        let index = LoweredTypeTable(
            loweredTypes: [],
            labels: labels,
            recordRows: [],
            namedRows: Set(labels.indices),
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
            loweredTypes[row] = .never
        }

        let records = Set(loweredTypes.indices.filter { row in
            if case .record = loweredTypes[row] { true } else { false }
        })

        // Whether an alias comes back to itself through the aliases it
        // mentions, at any depth. A record on the way is a row of its own,
        // so the walk stops there.
        func comesBackThroughStructure(from start: Int) -> Bool {
            var walked: Set<Int> = []
            var waiting = [start]

            while let row = waiting.popLast() {
                var mentioned: Set<Int> = []

                loweredTypes[row].standing(into: &mentioned)

                for next in mentioned.subtracting(records) {
                    guard next != start else { return true }

                    if walked.insert(next).inserted {
                        waiting.append(next)
                    }
                }
            }

            return false
        }

        let namedRows = records.union(
            loweredTypes.indices.filter { row in !records.contains(row) && comesBackThroughStructure(from: row) }
        )

        // Every other alias is what it stands for, worked out once each. No
        // such alias reaches itself, so the expansion is finite.
        var expanded: [Int: LoweredType] = [:]

        func mention(of row: Int) -> LoweredType {
            guard !namedRows.contains(row) else { return .named(row) }

            if let known = expanded[row] { return known }

            let expansion = loweredTypes[row].replacingRows(by: mention)

            expanded[row] = expansion

            return expansion
        }

        loweredTypes = loweredTypes.map { type in type.replacingRows(by: mention) }

        let recordRows = loweredTypes.indices.map { row -> Int? in
            if records.contains(row) { return row }
            guard case let .named(record) = loweredTypes[row], records.contains(record) else { return nil }

            return record
        }

        return LoweredTypeTable(
            loweredTypes: loweredTypes,
            labels: labels,
            recordRows: recordRows,
            cycling: cycling,
            namedRows: namedRows,
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
        case .never:
            return .settled(true)

        case .any, .projection:
            return .settled(false)

        // A name that stands for no record answers as what it stands for,
        // since a value of it is an instance of that.
        case let .named(row) where recordRows[row] == nil:
            return answering(contract: name, reading: loweredTypes[row], rigid: rigid, orNull: orNull)

        // A parameter stands for whatever fills it, and a call fills it with
        // something every bound was asked of, so one bounded by the contract
        // answers and one bounded by nothing that answers is refused: a slot
        // says what a call may fill it with. A composition is read as the
        // contracts it names, so it answers those alone.
        case let .parameter(_, bounds), let .composition(bounds):
            return .settled(bounds.contains(name))

        // What may be null is a value of the type or null, so it answers
        // where both do.
        case let .nullable(inner):
            return answering(contract: name, reading: inner, rigid: rigid, orNull: false)
                .and(answering(contract: name, reading: .null, rigid: rigid, orNull: false))

        // A reading of a type a value is an instance of answers as that type
        // does: by what the documents claim about it, so the type comes back
        // and the asker writes it down. Asked rigidly, or where the table
        // holds every claim there is, it is held to what the documents say.
        default:
            guard let type = reading.nominal(in: self) else { return .settled(true) }
            guard !rigid, !settled else { return .settled(settles(contract: name, arrived: type) != false) }

            return .leansOn([type])
        }
    }
}
