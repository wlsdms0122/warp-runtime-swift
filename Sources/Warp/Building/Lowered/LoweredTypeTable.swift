//
//  LoweredTypeTable.swift
//  Warp
//
//  Created by JSilver on 9/3/26.
//

import Foundation

// The declared types as the run reads them: by row. A declared struct survives
// into the run as a row rather than being expanded, since it is nominal and may
// name itself, and a row is read by number. An alias is a spelling: a mention
// of it lowers to what it stands for, so no judgement meets one, and a row a
// type stands on is always a struct's. The spellings ride along for a refusal
// and for a struct's name. A class, so a judgement that recurses passes one
// reference down rather than a copy of every array the table holds.
final class LoweredTypeTable: Sendable {
    // What a reading standing where a contract is asked comes to. What the
    // type alone decides is decided here; a named type decides nothing,
    // since which types answer a contract is read off the claims of the whole
    // list, so the names come back and the asker writes them down.
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
    // lowering a document's type and for a struct that arrived under an
    // alias; the run reads rows by number otherwise.
    func row(named name: Name) -> Int? {
        rows[name]
    }

    // The struct a value under this name is a value of: the struct it
    // declares, or the one an alias of a struct stands for. Nil where the
    // name declares no struct.
    func structRow(named name: Name) -> Int? {
        guard let row = row(named: name), case let .named(declared, _) = mention(of: row) else { return nil }

        return declared
    }

    // What a row stands for where a mention applies it to `arguments`: a
    // struct with each of its type parameters read as the type at its
    // position, and what an alias stands for otherwise.
    func declared(_ row: Int, applied arguments: [LoweredType]) -> LoweredType {
        guard case let .struct(declared) = loweredTypes[row] else { return loweredTypes[row] }

        return .struct(declared.applied(to: arguments))
    }

    // What a struct literal taking type parameters is applied to where its
    // fields read as `fields`: each parameter filled as a call's arguments
    // fill a declaration's, so a parameter read two ways is read as the
    // first and the other field is judged against it, and `Never` where no
    // field reads one, as an empty list's element is. Empty for a struct
    // taking none.
    func arguments(of row: Int, filling fields: [Name: LoweredType]) -> [LoweredType] {
        guard case let .struct(declared) = loweredTypes[row], !declared.typeParameters.isEmpty else { return [] }

        let read = declared.named.compactMap { name, field in fields[name].map { reading in (field.fieldUnwrapped, reading) } }
        let filled = Substitution(filling: read.map(\.0), against: read.map(\.1), in: self).readings

        return declared.typeParameters.map { parameter in filled[parameter] ?? .never }
    }

    // What a struct value taking type parameters is applied to where its
    // fields read as `fields`: each parameter as every reading of it joined,
    // as a list value reads as its elements joined, and `Never` where no
    // field reads one. Empty for a struct taking none.
    func arguments(of row: Int, joining fields: [Name: LoweredType]) -> [LoweredType] {
        guard case let .struct(declared) = loweredTypes[row], !declared.typeParameters.isEmpty else { return [] }

        var joined: [Name: LoweredType] = [:]

        for (name, field) in declared.named {
            guard let reading = fields[name] else { continue }

            let read = Substitution(filling: [field.fieldUnwrapped], against: [reading], in: self)

            for (parameter, type) in read.readings.merging(read.disagreeing, uniquingKeysWith: { first, second in first.joined(second) }) {
                joined[parameter] = joined[parameter].map { held in held.joined(type) } ?? type
            }
        }

        return declared.typeParameters.map { parameter in joined[parameter] ?? .never }
    }

    // A value from outside with every struct it holds, at any depth, held to
    // the struct its name declares: an alias's name is its struct's, the
    // fields its declaration does not name are left out, the struct is judged
    // against its declaration applied to what the name applies it to, or,
    // where the name applies it to nothing, to what its fields fill its type
    // parameters with, and a name that declares no struct is the name of no
    // type here. So every struct the run holds is a value of the struct
    // its name declares, whatever slot it came in at, and this is the one
    // place a value is fitted.
    //
    // `type` is what the place the value stands at declares, where one does,
    // walked in step with the value: a struct whose place applies it to
    // types is judged applied to them, and only where nothing says are its
    // arguments read off its fields.
    func resolvingNames(in value: Value, under type: LoweredType?, at path: @autoclosure () -> String) throws -> Value {
        guard value.holdsStruct else { return value }

        let place = type?.literalPlace

        switch value {
        case let .array(items):
            return .array(try items.enumerated().map { index, item in
                try resolvingNames(in: item, under: place?.element, at: "\(path())[\(index)]")
            })

        // A key is a value like any other, so a struct in it is held as one
        // in an entry is. That can make two keys one, which refuses as a map
        // written with one key twice does.
        case let .dictionary(entries):
            let resolved = try entries.entries.map { key, item in
                let at = "\(path())\(Path([.index(key)]).rendered)"

                guard case let .dictionary(keyType, valueType)? = place else {
                    return (key: try resolvingNames(in: key, under: nil, at: at), value: try resolvingNames(in: item, under: nil, at: at))
                }

                return (key: try resolvingNames(in: key, under: keyType, at: at), value: try resolvingNames(in: item, under: valueType, at: at))
            }

            do {
                return .dictionary(try Value.Dictionary(resolved))
            } catch let refused as ValueRefused {
                throw ArgumentError("\(path()): \(refused.message)")
            }

        case let .struct(instance):
            guard
                let named = self.row(named: instance.name).map(mention(of:)),
                case let .named(row, written) = named,
                case let .struct(declared) = loweredTypes[row]
            else {
                throw ArgumentError("\(path()): is a \(instance.name), which no document declares as a struct")
            }

            // What the name applies the struct to, an alias's arguments, or
            // what its place does where the place names no type parameter
            // in them, or nothing yet.
            let said: [LoweredType]? = if !written.isEmpty {
                written
            } else if case let .named(placed, arguments)? = place, placed == row, !arguments.isEmpty,
                !arguments.contains(where: \.namesParameter) {
                arguments
            } else {
                nil
            }

            let fields = said.map { said in declared.applied(to: said) } ?? declared
            let resolved = try instance.mapValues { field, held in
                try resolvingNames(in: held, under: fields[field], at: "\(path()).\(field)")
            }
            let kept = zip(resolved.names, resolved.values).filter { name, _ in declared[name] != nil }
            let fitted = Struct(layout: Layout(name: labels[row], ordered: kept.map(\.0)), values: kept.map(\.1))
            let arguments = try said ?? self.arguments(of: row, holding: fitted, at: path())

            return try LoweredType.named(row, arguments: arguments).settling(.struct(fitted), at: path(), in: self)

        default:
            return value
        }
    }

    // A struct the language declares itself, by its row. Every table a
    // compile or a link holds stands on the `Prelude`, and one a caller
    // assembled with nothing declared reads it as no value's type.
    func prelude(_ name: Name) -> LoweredType {
        row(named: name).map { row in .named(row) } ?? .never
    }

    // Whether a row is a declared struct's.
    func declaresStruct(_ row: Int) -> Bool {
        if case .struct = loweredTypes[row] { true } else { false }
    }

    // What a mention of a row lowers to: the row, where it is a struct's,
    // and what the alias stands for otherwise. A table whose rows are not
    // lowered yet keeps every mention a row.
    func mention(of row: Int) -> LoweredType {
        guard loweredTypes.indices.contains(row), !declaresStruct(row) else { return .named(row) }

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
        orNull: Bool
    ) -> Answering {
        guard let reading = read(given, orNull: orNull) else { return .decided(true) }

        switch reading {
        case .never:
            return .decided(true)

        // A procedure answers no contract: no claim is about one.
        case .any, .projection, .procedure:
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
            return answering(contract: name, reading: inner, orNull: false)
                .and(answering(contract: name, reading: .null, orNull: false))

        // A reading of a type a value is an instance of answers as that type
        // does: by what the documents claim about it, so the type comes back
        // and the asker writes it down. Where the table holds every claim
        // there is, it is held to what the documents say.
        default:
            guard let type = reading.nominal(in: self) else { return .decided(true) }
            guard !holdsEveryClaim else { return .decided(answers(contract: name, arrived: type) != false) }

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
        switch answering(contract: name, reading: reading, orNull: orNull) {
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

    // Why a map keyed by `key` is no map type the language has, or nil
    // where the key answers `Hashable`: by what the documents claim about
    // its type, and a type parameter through its bounds. What leans on a
    // claim goes to `leaning`, for the asker to write down where it stands.
    // The one sentence a map type is refused in, written or read.
    func keyRefusal(of key: LoweredType, leaning: (Claim) -> Void) -> String? {
        switch answering(contract: TypeSpelling.hashable, reading: key, orNull: false) {
        case let .leansOn(types):
            for type in types {
                leaning(Claim(type: type, contract: TypeSpelling.hashable))
            }

            return nil

        case .decided(true):
            return nil

        case .decided(false):
            return "keys a map by \(key.rendered(in: self)), which does not answer `\(TypeSpelling.hashable)`."
                + " A map's key is of a type that answers `\(TypeSpelling.hashable)`, and a type parameter"
                + " answers what its bounds name"
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
        _ types: [Name: TypeDeclaration],
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

        var loweredTypes = labels.map { label in types[label]?.lowered(as: label, in: index) ?? .any }

        let structs = Set(loweredTypes.indices.filter { row in
            if case .struct = loweredTypes[row] { true } else { false }
        })

        // An alias is what it stands for, worked out once each. None comes
        // back to itself: the load and an object's reading refuse that within
        // one document, and the documents of a build stand in an order where
        // each names only what it or one before it declares, so the expansion
        // ends.
        var expanded: [Int: LoweredType] = [:]

        func mention(of row: Int) -> LoweredType {
            guard !structs.contains(row) else { return .named(row) }

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
    // What a struct from outside is applied to where its place does not say:
    // what the value reads as, each parameter its fields' readings joined,
    // and a bounded one held to its bounds, which `Any`, what readings of
    // several types join to, answers none.
    private func arguments(of row: Int, holding instance: Struct, at path: String) throws -> [LoweredType] {
        guard case let .struct(declared) = loweredTypes[row] else { return [] }

        let arguments = self.arguments(
            of: row,
            joining: Dictionary(uniqueKeysWithValues: zip(instance.names, instance.values.map { field in LoweredType(of: field, in: self) }))
        )
        let bounds = declared.fields.reduce(into: [Name: [Name]]()) { found, field in
            found.merge(field.typeParameters) { first, _ in first }
        }

        for (parameter, argument) in zip(declared.typeParameters, arguments) {
            for contract in bounds[parameter] ?? [] {
                if let refusal = refusal(
                    of: argument,
                    answering: contract,
                    orNull: false,
                    as: "'\(parameter)' is read as",
                    leaning: { claim in fulfillment?.require(folded: claim) }
                ) {
                    throw ArgumentError("\(path): \(refusal)")
                }
            }
        }

        return arguments
    }

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
