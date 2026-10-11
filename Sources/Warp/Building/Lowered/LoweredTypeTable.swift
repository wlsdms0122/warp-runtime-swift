//
//  LoweredTypeTable.swift
//  Warp
//
//  Created by JSilver on 9/3/26.
//

import Foundation

// The declared types as the run reads them: by row. A declared record survives
// into the run as a row rather than being expanded, since it is nominal and may
// name itself, and a row is read by number. An alias is a spelling: a mention
// of it lowers to what it stands for, so no judgement meets one, and a row a
// type stands on is always a record's. The spellings ride along for a refusal
// and for a record's name. A class, so a judgement that recurses passes one
// reference down rather than a copy of every array the table holds.
final class LoweredTypeTable: Sendable {
    // What a reading standing where a contract is asked comes to. What the
    // type alone decides is decided here; a named type decides nothing,
    // since which types answer a contract is read off the claims of the whole
    // list, so the names come back and the asker writes them down. Asked
    // rigidly, the documents decide it.
    enum Answering {
        case decided(Bool)
        case leansOn([Name])

        // MARK: - Property
        // MARK: - Initializer
        // MARK: - Public
        // What a reading comes to where it answers only if both parts do.
        func and(_ other: Answering) -> Answering {
            switch (self, other) {
            case (.decided(false), _), (_, .decided(false)):
                return .decided(false)

            case (.decided(true), _):
                return other

            case (_, .decided(true)):
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
    let holdsEveryClaim: Bool

    // Where a pair this table cannot decide is written down, so it goes to
    // the list that can answer it. Nothing at the run, where the table is
    // the whole list's and decides everything it is asked.
    let fulfillment: Fulfillment?

    private let rows: [Name: Int]

    // A table declaring nothing, for a judgement asked with no declarations
    // behind it. It belongs to no link, so no row belongs to it.
    static let empty = LoweredTypeTable(
        loweredTypes: [],
        labels: [],
        of: Linkage()
    )

    // MARK: - Initializer
    init(
        loweredTypes: [LoweredType],
        labels: [Name],
        satisfying: [Name: Set<Name>] = [:],
        holdsEveryClaim: Bool = true,
        fulfillment: Fulfillment? = nil,
        of linkage: Linkage
    ) {
        self.loweredTypes = loweredTypes
        self.labels = labels
        self.satisfying = satisfying
        self.holdsEveryClaim = holdsEveryClaim
        self.fulfillment = fulfillment
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

    // The record a value under this name is a value of: the record it
    // declares, or the one an alias of a record stands for. Nil where the
    // name declares no record.
    func record(named name: Name) -> Int? {
        guard let row = row(named: name) else { return nil }

        switch loweredTypes[row] {
        case .record:
            return row

        case let .named(record):
            return record

        default:
            return nil
        }
    }

    // A value from outside with every record it holds under a name, at any
    // depth, held to the record the name declares: an alias's name is its
    // record's, the record is fitted to its declaration and judged against
    // it, and a name that declares no record is the name of no type here.
    // So every record the run holds under a name is a value of that record,
    // whatever slot it came in at.
    func resolvingNames(in value: Value, at path: @autoclosure () -> String) throws -> Value {
        guard value.holdsName else { return value }

        switch value {
        case let .array(items):
            return .array(try items.enumerated().map { index, item in try resolvingNames(in: item, at: "\(path())[\(index)]") })

        case let .dictionary(entries):
            return .dictionary(try entries.mapValues { _, item in try resolvingNames(in: item, at: path()) })

        case let .record(record):
            let fields = try record.mapValues { field, held in try resolvingNames(in: held, at: "\(path()).\(field)") }

            guard let name = record.name else { return .record(fields) }

            guard let row = self.record(named: name) else {
                throw ArgumentError("\(path()): is a \(name), which no document declares as a record")
            }

            let declared = LoweredType.named(row)

            return try declared.settling(declared.fitted(.record(fields.named(labels[row])), in: self), at: path(), in: self)

        default:
            return value
        }
    }

    // Whether a row is a declared record's.
    func declaresRecord(_ row: Int) -> Bool {
        if case .record = loweredTypes[row] { true } else { false }
    }

    // What a mention of a row lowers to: the row, where it is a record's,
    // and what the alias stands for otherwise. A table whose rows are not
    // lowered yet keeps every mention a row.
    func mention(of row: Int) -> LoweredType {
        guard loweredTypes.indices.contains(row), !declaresRecord(row) else { return .named(row) }

        return loweredTypes[row]
    }

    // Whether a type answers every procedure a contract asks, by what the
    // documents claim about it. Nil where nothing declares the contract, what
    // an undeclared name means being for whoever asked to say, and where the
    // table does not hold every claim there is.
    func answers(contract name: Name, arrived type: Name) -> Bool? {
        guard let claimed = satisfying[name] else { return nil }
        guard holdsEveryClaim else { return nil }

        return claimed.contains(type)
    }

    // Whether a name is a declared contract, which is the one thing a bound
    // names.
    func declaresContract(_ name: Name) -> Bool {
        satisfying[name] != nil
    }

    // Whether a reading answers a contract, by what the documents claim
    // about its type: decided, or leaning on the claims about the types that
    // come back, for whoever asked to write down. A reading whose type the
    // build does not know answers none until a cast says what it is.
    // `orNull` is a slot taking null as well: what arrives is null or
    // answers.
    func answering(
        contract name: Name,
        reading given: LoweredType,
        rigid: Bool,
        orNull: Bool
    ) -> Answering {
        guard let reading = read(given, orNull: orNull) else { return .decided(true) }

        switch reading {
        case .never:
            return .decided(true)

        case .any, .projection:
            return .decided(false)

        // A parameter stands for whatever fills it, and a call fills it with
        // something every bound was asked of, so one bounded by the contract
        // answers and one bounded by nothing that answers is refused: a slot
        // says what a call may fill it with. A composition is read as the
        // contracts it names, so it answers those alone.
        case let .parameter(_, bounds), let .composition(bounds):
            return .decided(bounds.contains(name))

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
            guard let type = reading.nominal(in: self) else { return .decided(true) }
            guard !rigid, !holdsEveryClaim else { return .decided(answers(contract: name, arrived: type) != false) }

            return .leansOn([type])
        }
    }

    // Why a reading provably does not answer a contract, after `label`, which
    // says what was read, or nil where it answers. What leans on a claim goes
    // to `leaning`, for the asker to write down where it stands. The one
    // sentence the build and a door refuse such a reading in.
    func refusal(
        of reading: LoweredType,
        answering name: Name,
        orNull: Bool,
        as label: String,
        leaning: (Claim) -> Void
    ) -> String? {
        switch answering(contract: name, reading: reading, rigid: false, orNull: orNull) {
        case let .leansOn(types):
            for type in types {
                leaning(Claim(type: type, contract: name))
            }

            return nil

        case .decided(true):
            return nil

        case .decided(false):
            return "\(label) \(reading.rendered(in: self)),"
                + " which does not answer every procedure '\(name)' asks"
        }
    }

    // The declarations as the run reads them. A link says which order its rows
    // stand in, so a document's types take a run of rows the way its
    // declarations do; where nothing says, the declared spellings order them.
    //
    // A run that stands where its document does is a run a later document
    // cannot move, which is what lets a document already lowered keep the
    // numbers it was lowered with. Either way a row is a row of one table and
    // nothing a link concludes reads one to decide what to say.
    static func lowering(
        _ types: [Name: TypeExpression],
        satisfying: [Name: Set<Name>] = [:],
        holdsEveryClaim: Bool,
        fulfillment: Fulfillment? = nil,
        standing: [Name]? = nil,
        of linkage: Linkage
    ) -> LoweredTypeTable {
        let labels = standing ?? types.keys.sorted()

        // The index first, every mention kept as a row, so a declaration
        // naming another lowers against rows that already exist whichever is
        // declared first. The contracts stand in it too: a field naming one
        // is a slot the contract fills.
        let index = LoweredTypeTable(loweredTypes: [], labels: labels, satisfying: satisfying, of: linkage)

        var loweredTypes = labels.map { label in (types[label] ?? .any).lowered(in: index) }

        let records = Set(loweredTypes.indices.filter { row in
            if case .record = loweredTypes[row] { true } else { false }
        })

        // An alias is what it stands for, worked out once each. None comes
        // back to itself, which the load and an object's reading refuse, so
        // the expansion ends.
        var expanded: [Int: LoweredType] = [:]

        func mention(of row: Int) -> LoweredType {
            guard !records.contains(row) else { return .named(row) }

            if let known = expanded[row] { return known }

            let expansion = loweredTypes[row].replacingRows(by: mention)

            expanded[row] = expansion

            return expansion
        }

        loweredTypes = loweredTypes.map { type in type.replacingRows(by: mention) }

        return LoweredTypeTable(
            loweredTypes: loweredTypes,
            labels: labels,
            satisfying: satisfying,
            holdsEveryClaim: holdsEveryClaim,
            fulfillment: fulfillment,
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

        default:
            return reading
        }
    }
}
