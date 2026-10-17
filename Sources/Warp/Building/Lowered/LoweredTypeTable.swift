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
    // MARK: - Property
    // The declared types, in the order of their spellings.
    let loweredTypes: [LoweredType]

    let labels: [Name]

    // What this table's rows are numbered against. A compile or a link owns
    // one; a table a caller assembled is a place of its own.
    let linkage: Linkage

    // Which types satisfy each declared contract, by the contract's own
    // spelling, each beside the values of it that do: the head its claim was
    // written under, lowered, or nil where the head is bare and every value
    // does. Which types those are is no type the table lowers: what puts a
    // type under a contract is a document's claim, held to the declarations
    // that answer the procedures, which the link works out rather than the
    // type language.
    //
    // Every declared contract has an entry, so a name with none is a name no
    // document declared as a contract at all.
    //
    // The claims are the ones the asker stands on: a compile's are those made
    // within the reach of the document it judges, and the link's and the
    // run's are every claim in the link.
    let satisfying: [Name: [Name: LoweredType?]]

    // The types each declared contract asks, by the contract's spelling and
    // then the type's name, beside the contracts the contract holds each to,
    // in name order. What an associated type of a type parameter the contract bounds
    // is held to.
    let asking: [Name: [Name: [Name]]]

    // What each type gives under each name, by the type's name and the
    // member's: what an associated type of a type parameter the type fills reads as,
    // where a claim within reach says the type answers a contract asking it.
    // Every type member of the link, since a type gives one member under a
    // name whichever document gave it.
    let typeMembers: [Name: [Name: LoweredTypeMember]]

    // Whether the claims above are every claim the link holds: the link's
    // and the run's are, and a compile's are those within the reach of the
    // document it judges, which a fold runs against too.
    let holdsEveryClaim: Bool

    // Whether a type no claim here is about answers every contract, which is
    // what a table holding one reach asks to see whether an answer turns on
    // claims beyond it.
    private let assumesUnseenClaims: Bool

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
        satisfying: [Name: [Name: LoweredType?]] = [:],
        asking: [Name: [Name: [Name]]] = [:],
        typeMembers: [Name: [Name: LoweredTypeMember]] = [:],
        of linkage: Linkage
    ) {
        self.loweredTypes = loweredTypes
        self.labels = labels
        self.satisfying = satisfying
        self.asking = asking
        self.typeMembers = typeMembers
        self.holdsEveryClaim = true
        self.assumesUnseenClaims = false
        self.linkage = linkage
        self.rows = Dictionary(uniqueKeysWithValues: labels.enumerated().map { row, label in (label, row) })
    }

    // The same rows answering with other claims, the index carried over.
    private init(
        _ table: LoweredTypeTable,
        satisfying: [Name: [Name: LoweredType?]],
        holdsEveryClaim: Bool,
        assumesUnseenClaims: Bool = false
    ) {
        self.loweredTypes = table.loweredTypes
        self.labels = table.labels
        self.satisfying = satisfying
        self.asking = table.asking
        self.typeMembers = table.typeMembers
        self.holdsEveryClaim = holdsEveryClaim
        self.assumesUnseenClaims = assumesUnseenClaims
        self.linkage = table.linkage
        self.rows = table.rows
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
        // in an entry is. That can make two keys one, which refuses: a map
        // value holds its keys in the key order, so neither is the later one.
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

    // Whether a reading answers every procedure a contract asks, by what the
    // documents claim about its type: a claim whose head takes it, the way a
    // parameter written as the head takes an argument. Nil where nothing
    // declares the contract, what an undeclared name means being for whoever
    // asked to say.
    func answers(contract name: Name, reading: LoweredType, of type: Name) -> Bool? {
        guard let claimed = satisfying[name] else { return nil }
        guard let entry = claimed[type] else { return assumesUnseenClaims }
        guard let head = entry else { return true }

        return refusal(of: reading, under: head) == nil
    }

    // What a value reads as where a contract is asked of it. A value carries
    // no type's arguments, so where the claim about its type stands under a
    // head applying the type, the value is held to the head the way a door
    // holds one to a slot writing the struct: the head's own type parameters
    // filled by what its parts read as, and the value settling into what that
    // fills. A value that does not settle reads as its parts, which the head
    // does not take.
    func reading(of value: Value, answering contract: Name) -> LoweredType {
        let read = LoweredType(of: value, in: self)

        guard
            let type = read.nominal(in: self),
            case let head?? = satisfying[contract]?[type]
        else {
            return read
        }

        let filled = head.filling(Substitution(filling: [head], against: [read], in: self).readings)

        return filled.settles(value, in: self) ? filled : read
    }

    // Why a parameter written as `head` does not take a value read as
    // `reading`, or nil where it does: what the reading puts in the head's
    // type parameters, each read one way and held to its bounds, and the
    // head filled with that taking the reading. The one judgement a claim's
    // head is held to, wherever a reading meets one.
    func refusal(of reading: LoweredType, under head: LoweredType) -> String? {
        let substitution = Substitution(filling: [head], against: [reading], in: self)

        for (parameter, bounds) in head.typeParameters.sorted(by: { $0.key < $1.key }) {
            let refused = substitution.disagreement(of: parameter, in: self)
                ?? substitution.severalTypes(of: parameter, bounds: Set(bounds), over: [head], in: self)
                ?? substitution.unanswered(parameter, bounds: Set(bounds), in: self)

            if let refused {
                return refused
            }
        }

        let filled = head.filling(substitution.readings)

        guard filled.takes(reading, in: self) else {
            return "\(reading.rendered(in: self)) is no \(filled.rendered(in: self))"
        }

        return nil
    }

    // The contracts bounding what a label stands for under `bounds`, a
    // signature's or a head's: a type parameter's bounds, and an associated
    // type's what the contracts bounding what it stands on hold it to beside
    // its own.
    func contracts(bounding label: Name, under bounds: [Name: Set<Name>]) -> Set<Name> {
        let own = bounds[label] ?? []

        guard
            let standing = label.associated,
            let asked = self.bounds(of: standing.name, askedBy: contracts(bounding: standing.of, under: bounds))
        else {
            return own
        }

        return asked.union(own)
    }

    // What an associated type `name` of a type parameter bounded by `contracts`
    // is held to: what each of them asking a type under the name holds it to,
    // or nil where none asks one.
    func bounds(of name: Name, askedBy contracts: some Collection<Name>) -> Set<Name>? {
        let asking = contracts.compactMap { contract in self.asking[contract]?[name] }

        guard !asking.isEmpty else { return nil }

        return Set(asking.joined())
    }

    // What an associated type `name` of a type parameter bounded by `contracts`
    // reads as where `base` fills the parameter, or nil where nothing says.
    // A type parameter's associated type is its own, held to what those contracts
    // hold it to; a reading of a type a value is an instance of gives the
    // type member under the name, where a claim within reach says the type
    // answers one of them asking it, filled by what the reading puts in the
    // head the member was given under. A value of a contract, of what may be
    // null, or of `Any`, is of no one type, and gives none; what holds no
    // value gives what holds none.
    func associatedType(_ name: Name, of base: LoweredType, among contracts: [Name]) -> LoweredType? {
        switch base {
        case .never:
            return .never

        case let .parameter(label, bounds):
            return self.bounds(of: name, askedBy: bounds).map { held in
                .parameter(label: name.spelled(under: label), bounds: held.sorted())
            }

        default:
            guard
                let type = base.nominal(in: self),
                contracts.contains(where: { contract in
                    asking[contract]?[name] != nil && answers(contract: contract, reading: base, of: type) == true
                }),
                let given = typeMembers[type]?[name]
            else {
                return nil
            }

            guard let head = given.head else { return given.type }

            var substitution = Substitution(filling: [head], against: [base], in: self)

            substitution.derive(given.associatedTypes, bounds: given.bounds, in: self)

            return given.type.filling(substitution.readings)
        }
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
    func answering(contract name: Name, reading given: LoweredType, orNull: Bool) -> Bool {
        guard let reading = read(given, orNull: orNull) else { return true }

        switch reading {
        case .never:
            return true

        // A procedure answers no contract: no claim is about one.
        case .any, .procedure:
            return false

        // A parameter stands for whatever fills it, and a call fills it with
        // something every bound was asked of, so one bounded by the contract
        // answers and one bounded by nothing that answers is refused: a slot
        // says what a call may fill it with. A composition is read as the
        // contracts it names, so it answers those alone.
        case let .parameter(_, bounds), let .composition(bounds):
            return bounds.contains(name)

        // What may be null is a value of the type or null, so it answers
        // where both do.
        case let .nullable(inner):
            return answering(contract: name, reading: inner, orNull: false)
                && answering(contract: name, reading: .null, orNull: false)

        // A reading of a type a value is an instance of answers as that type
        // does: by what the documents claim about it.
        default:
            guard let type = reading.nominal(in: self) else { return true }

            return answers(contract: name, reading: reading, of: type) != false
        }
    }

    // Why a reading does not answer a contract, after `label`, which says
    // what was read, or nil where it answers. The one sentence the build and
    // a door refuse such a reading in. A reading of a type a value is an
    // instance of says which claim it missed: none about the type among the
    // claims the asker stands on, or one whose head does not take it.
    func refusal(of reading: LoweredType, answering name: Name, orNull: Bool, as label: String) -> String? {
        guard !answering(contract: name, reading: reading, orNull: orNull) else { return nil }

        let read = "\(label) \(reading.rendered(in: self))"

        guard
            let held = self.read(reading, orNull: orNull),
            case .some = satisfying[name],
            let type = held.nominal(in: self)
        else {
            return read + ", which does not answer every procedure '\(name)' asks"
        }

        guard case let head?? = satisfying[name]?[type], let reason = refusal(of: held, under: head) else {
            guard holdsEveryClaim else {
                return read + ", and no claim within reach says '\(type)' answers '\(name)'."
                    + " A type answers a contract where a document the asker stands on says so"
            }

            return read + ", and no document in this link says '\(type)' answers '\(name)'"
        }

        return read + ", and '\(type)' answers '\(name)' as \(head.rendered(in: self)), which does not take it: \(reason)"
    }

    // Why a map keyed by `key` is no map type the language has, or nil
    // where the key answers `Hashable`: by what the documents claim about
    // its type, and a type parameter through its bounds. The one sentence a
    // map type is refused in, written or read.
    func keyRefusal(of key: LoweredType) -> String? {
        guard !answering(contract: TypeSpelling.hashable, reading: key, orNull: false) else { return nil }

        return "keys a map by \(key.rendered(in: self)), which does not answer `\(TypeSpelling.hashable)`."
            + " A map's key is of a type that answers `\(TypeSpelling.hashable)`, and a type parameter"
            + " answers what its bounds name"
    }

    // The same rows with these claims answering: each head lowered against
    // the rows, as a parameter written as it would.
    func satisfying(_ heads: [Name: [Name: Head]], holdsEveryClaim: Bool) -> LoweredTypeTable {
        let declaring = LoweredTypeTable(self, satisfying: heads.mapValues { _ in [:] }, holdsEveryClaim: holdsEveryClaim)

        return LoweredTypeTable(
            self,
            satisfying: heads.mapValues { held in held.mapValues { head in head.lowered(in: declaring) } },
            holdsEveryClaim: holdsEveryClaim
        )
    }

    // The same claims, with a type none of them is about answering every
    // contract: a reach's answer that holds here and fails in the table it
    // came from is one that claims beyond the reach decide.
    func assumingUnseenClaims() -> LoweredTypeTable {
        LoweredTypeTable(self, satisfying: satisfying, holdsEveryClaim: holdsEveryClaim, assumesUnseenClaims: true)
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
        contracts: [Name: Contract] = [:],
        satisfying: [Name: [Name: Head]] = [:],
        typeMembers: [TypeMember] = [],
        standing: [Name]? = nil,
        of linkage: Linkage
    ) -> LoweredTypeTable {
        let labels = standing ?? types.keys.sorted()

        // The index first, every mention kept as a row, so a declaration
        // naming another lowers against rows that already exist whichever is
        // declared first. The contracts stand in it too: a field naming one
        // is a slot the contract fills.
        let declaring = satisfying.mapValues { _ in [Name: LoweredType?]() }
        let index = LoweredTypeTable(loweredTypes: [], labels: labels, satisfying: declaring, of: linkage)

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

        // A head lowers against the rows, as a parameter written as it would,
        // and a type member against what the contracts ask, since it may
        // name an associated type of one of its head's parameters.
        let asking = contracts.mapValues { contract in
            contract.types.reduce(into: [Name: [Name]]()) { asked, name in
                asked[name] = (contract.bounds[name] ?? []).sorted()
            }
        }
        let rows = LoweredTypeTable(
            loweredTypes: loweredTypes,
            labels: labels,
            satisfying: declaring,
            asking: asking,
            of: linkage
        )

        return LoweredTypeTable(
            loweredTypes: loweredTypes,
            labels: labels,
            satisfying: satisfying.mapValues { heads in heads.mapValues { head in head.lowered(in: rows) } },
            asking: asking,
            typeMembers: typeMembers.reduce(into: [:]) { given, member in
                given[member.head.type, default: [:]][member.name] = LoweredTypeMember(
                    member.type,
                    under: member.head.applying(types[member.head.type]),
                    in: rows
                )
            },
            of: linkage
        )
    }

    // MARK: - Private
    // What a struct from outside is applied to where its place does not say:
    // what the value reads as, each parameter its fields' readings joined. A
    // bounded one is one type, and a value says of its type the struct it is
    // and not what that is applied to, so one whose fields are of no one
    // type, `Any`, answers none, and one that is stands, each field holding
    // it held to the bounds by what it is as the struct settles.
    private func arguments(of row: Int, holding instance: Struct, at path: String) throws -> [LoweredType] {
        guard case let .struct(declared) = loweredTypes[row] else { return [] }

        let readings = instance.values.map { field in LoweredType(of: field, in: self) }
        let arguments = self.arguments(of: row, joining: Dictionary(uniqueKeysWithValues: zip(instance.names, readings)))
        let unapplied = self.arguments(
            of: row,
            joining: Dictionary(uniqueKeysWithValues: zip(instance.names, instance.values.map { field in
                LoweredType(unapplied: field, in: self)
            }))
        )
        let bounds = declared.fields.reduce(into: [Name: [Name]]()) { found, field in
            found.merge(field.typeParameters) { first, _ in first }
        }

        return try zip(declared.typeParameters, zip(arguments, unapplied)).map { parameter, read in
            guard let held = bounds[parameter], !held.isEmpty else { return read.0 }

            guard read.1.nominal(in: self) == nil else { return .parameter(label: parameter, bounds: held) }

            for contract in held {
                if let refusal = refusal(of: read.1, answering: contract, orNull: false, as: "'\(parameter)' is read as") {
                    throw ArgumentError("\(path): \(refusal)")
                }
            }

            return read.1
        }
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
