//
//  LoweredType.swift
//  Warp
//
//  Created by JSilver on 9/3/26.
//

import Foundation

// A type as the run reads it: the declaration's type with every name the
// build resolved written in as a row of the lowered type table. What a document
// spells stays `TypeExpression`; this is the build's product, the way `Operation`
// is the product of an `Expression`. Every judgment over a value or a
// reading lives here, and the document's type reaches it by lowering.
indirect enum LoweredType: Sendable, Equatable {
    case any
    case never
    case null
    case bool
    case int
    case double
    case string
    case ranged(TypeExpression.Refinement)
    case array(LoweredType)
    case dictionary(LoweredType)

    case record(LoweredRecord)

    // What a slot asks of a procedure value: the types it is applied with, in
    // position order, and what it must answer. Nil where nothing was
    // declared. Constness and isolation are the slot's requirements.
    case procedure(
        parameters: [LoweredType]?,
        returns: LoweredType?,
        constness: Constness,
        isolation: Isolation
    )

    case variable(LoweredType)
    case `inout`(LoweredType)
    case nullable(LoweredType)

    // A declared type, by its row in the table.
    case named(Int)

    // A type parameter the call fills, and what the signature held it to.
    // The label is the spelling that ties one mention to another.
    case parameter(label: Name, bounds: [Bound])

    // A value of whatever type answers every bound, which no call fills and
    // no other mention shares: what a contract's name, or `A & B`, stands
    // for where a type is written. Apart from a parameter, so that what
    // fills a parameter cannot pass for what holds a value to its bounds.
    case composition([Bound])

    // The type a walk reached by taking a path through one a call decides.
    // The root is the type parameter's spelling and the path is what was
    // walked from it, so two walks landing on one field land on one type.
    // Nothing is proven about what it holds, so every judgment answers it the
    // way it answers `any`; it stands apart for the walk's own naming.
    case reading(of: Name, path: Path)

    // A name the table does not answer, and why. Nothing can be said about
    // it, so every judgment over readings lets it pass, and the value judge
    // refuses it with the reason. A table a host built by hand answers instead
    // of failing to lower, and only the judgments that reach the name are
    // touched by it. The build refuses such a name as it lowers the table, so a
    // run never meets one.
    case undeclared(label: String, because: Undeclared)

    // What a type parameter is held to. Two, because the two are answered
    // differently: a membership lists types and the table lowered them into
    // rows, a contract lists procedures and what answers it is a type's own name.
    enum Bound: Sendable, Equatable, Comparable {
        case membership(Int)
        case contract(Name)

        // MARK: - Property
        // MARK: - Initializer
        // MARK: - Public
        // Whether null is a value of what this holds to: a membership's
        // where a member admits one, and a contract's never, since a
        // contract is answered by a type and null wears none.
        func admitsNull(in table: LoweredTypeTable) -> Bool {
            guard case let .membership(constraint) = self else { return false }

            return table.constraints[constraint].contains { member in member.admitsNull(in: table) }
        }

        // Memberships first, by row; contracts behind, by name. One order,
        // so one set of bounds has one writing.
        static func < (lhs: Bound, rhs: Bound) -> Bool {
            switch (lhs, rhs) {
            case let (.membership(mine), .membership(theirs)): mine < theirs
            case (.membership, .contract): true
            case (.contract, .membership): false
            case let (.contract(mine), .contract(theirs)): mine < theirs
            }
        }

        // MARK: - Private
    }

    // Why a name is not answered: nothing declares it as a type, nothing
    // declares it as a membership or a contract, or it names itself.
    enum Undeclared: Sendable, Equatable {
        case noTypeNamed(Name)
        case noBoundNamed(Name)
        case namesItself
    }

    // MARK: - Property
    // What a field a declaration wrote `var` holds. The mark is a fact about
    // the field, and what is read out of it is the type inside.
    //
    // No `default` on either below: a mark nobody thought about must be a
    // compile error here rather than an answer of "no mark".
    var fieldUnwrapped: LoweredType {
        switch self {
        case let .variable(inner):
            return inner

        case .any, .never, .null, .bool, .int, .double, .string,
            .ranged, .array, .dictionary, .record, .procedure, .inout, .nullable,
            .named, .parameter, .composition, .reading, .undeclared:
            return self
        }
    }

    // Whether a slot holding this may be written through.
    var isVariable: Bool {
        if case .variable = self { return true }

        return false
    }

    // What a slot holds, through the two marks that say how it is held
    // rather than what it is.
    var slotUnwrapped: LoweredType {
        switch self {
        case let .variable(inner), let .inout(inner):
            return inner.slotUnwrapped

        case .any, .never, .null, .bool, .int, .double, .string,
            .ranged, .array, .dictionary, .record, .procedure, .nullable,
            .named, .parameter, .composition, .reading, .undeclared:
            return self
        }
    }

    // The row this stands on, through `?`, `var` and `inout`, which hold no
    // value of their own. Nil for a type that names no row. What follows a
    // chain of names follows this, so a name reached under a wrapper is a
    // link of the chain and not its end.
    var row: Int? {
        switch self {
        case let .named(row):
            return row

        case let .nullable(inner), let .variable(inner), let .inout(inner):
            return inner.row

        default:
            return nil
        }
    }

    // The spelling with its conditions dropped: a range is its kind.
    var unrefined: LoweredType {
        switch self {
        case let .ranged(refinement):
            return refinement.lowered

        default:
            return self
        }
    }

    // Whether what this stands for is settled at the call.
    var decidedAtCall: Bool {
        switch self {
        case .parameter, .reading:
            return true

        default:
            return false
        }
    }

    // What a judgment sees. A reading says a path was taken through a type
    // the call decides, which proves nothing about what it holds, and that is
    // what `any` says.
    var judged: LoweredType {
        if case .reading = self { return .any }

        return self
    }

    // Whether this type proves nothing about the value it holds.
    var provesNothing: Bool {
        self == .any || self == .never || decidedAtCall
    }

    // Whether this names one of the kinds a value simply is.
    var isDecidedKind: Bool {
        switch self {
        case .bool, .int, .double, .string, .null, .array, .dictionary, .record:
            return true

        default:
            return false
        }
    }

    // What a reading that went past a possible absence holds. Wrapping what
    // already admits null would say the one fact twice.
    var admittingNull: LoweredType {
        switch self {
        case .any, .null, .nullable:
            return self

        default:
            return .nullable(self)
        }
    }

    // What a slot said about the procedures it holds. A body applying a name a
    // slot declared this way is judged on the slot's word, since the slot is what
    // says which values may arrive there. An array or a dictionary of them says it
    // about every element.
    var isConstProcedure: Bool {
        switch self {
        case .procedure(_, _, .const, _):
            return true

        case let .array(element), let .dictionary(element):
            return element.isConstProcedure

        default:
            return false
        }
    }

    var isIsolatedProcedure: Bool {
        switch self {
        case .procedure(_, _, _, .isolated):
            return true

        case let .array(element), let .dictionary(element):
            return element.isIsolatedProcedure

        default:
            return false
        }
    }

    // One value of every kind a decided type can hold, for asking the judge
    // rather than restating it.
    private static let witnesses: [Value] = [
        .null, .bool(false), .int(0), .double(0), .string(""),
        .array([]), .dictionary([:]), .bytes([])
    ]

    // MARK: - Initializer
    // What a settled value reads as.
    init(of value: Value, in table: LoweredTypeTable) {
        switch value {
        case .null:
            self = .null

        case .bool:
            self = .bool

        case .int:
            self = .int

        case .double:
            self = .double

        case .string:
            self = .string

        case .bytes:
            self = TypeExpression.bytes.lowered(in: table)

        // A procedure that already exists as a value says nothing about itself
        // that a walk can read.
        case .procedure:
            self = .procedure(parameters: nil, returns: nil, constness: .unstated, isolation: .unstated)

        case let .array(elements):
            self = .array(LoweredType(joining: elements.map { element in LoweredType(of: element, in: table) }))

        // A record under a name reads as that name; the type is the
        // declaration's, and the name is what the value fits. A document's
        // type names its fields by Swift's equality, so two spellings the
        // value keeps apart are one field here, the first by bytes.
        case let .record(record):
            self = record.name.flatMap { name in table.row(named: name).map(LoweredType.named) }
                ?? .record(
                    Dictionary(
                        zip(record.names, record.values).map { name, value in (name, LoweredType(of: value, in: table)) }
                    ) { first, _ in first }
                )

        // A dictionary's names are data, so what it reads as is what its
        // entries hold, not which names it holds them under today.
        case let .dictionary(dictionary):
            self = .dictionary(
                LoweredType(joining: dictionary.entries.map { entry in LoweredType(of: entry.value, in: table) })
            )
        }
    }

    // What every one of these readings joins to, and `any` where there are
    // none.
    private init(joining readings: [LoweredType]) {
        self = readings.dropFirst().reduce(readings.first ?? .any) { joined, next in joined.joined(next) }
    }

    // MARK: - Public
    // What a walk through this type reaches by taking those segments. Nil
    // where this is not a type a call decides, which is where a walk has a
    // type to read the segments against and no need for one of these.
    //
    // Asked of the type rather than assembled at the walk, because the root
    // is the type's own fact: a parameter roots a reading at itself, and a
    // reading already rooted extends the path it carries.
    //
    // The marks come off on the way in: what a mark says is expected of the
    // value, and where the walk landed is the same field either way.
    func reaching(_ path: Path) -> LoweredType? {
        switch self {
        case let .parameter(name, _):
            return .reading(of: name, path: path.unmarked)

        case let .reading(of, walked):
            return .reading(of: of, path: walked.appending(contentsOf: path.unmarked.segments))

        default:
            return nil
        }
    }

    // Where a field stands in this type, and what stands there. Nil where
    // the build did not prove a layout: a dictionary, a value that arrived
    // through `any`, or a type a call still decides. A box is read through,
    // since a path reads what the box holds.
    //
    // The place is the value's, not only the type's. A value settling to a
    // record type is built on that type's layout, so a field the link
    // proved stands where the layout puts it.
    func place(of field: Name, in table: LoweredTypeTable) -> (position: Int, type: LoweredType)? {
        switch self {
        case let .record(held):
            guard let position = held.layout.position(of: field) else { return nil }

            return (position, held.fields[position])

        case let .named(row):
            return table.loweredTypes[row].place(of: field, in: table)

        case let .variable(inner), let .inout(inner):
            return inner.place(of: field, in: table)

        default:
            return nil
        }
    }

    // What an element of this stands as, for a walk taking an index. Nil
    // where the build proved no element type.
    func element(in table: LoweredTypeTable) -> LoweredType? {
        switch self {
        case let .array(element):
            return element

        // A dictionary's names are data, so a key the run computes reads an
        // entry the way an index reads an element.
        case let .dictionary(entry):
            return entry

        case let .named(row):
            return table.loweredTypes[row].element(in: table)

        case let .variable(inner), let .inout(inner):
            return inner.element(in: table)

        default:
            return nil
        }
    }

    // Two readings of one slot. Where they disagree the slot holds neither,
    // which is what `any` says. A join that guessed would be a refusal an
    // author cannot act on.
    //
    // A reading that leaves is not one of the two. It contributes no value, so
    // it cannot disagree with the reading that stays, and the slot holds what
    // the other one said.
    func joined(_ other: LoweredType) -> LoweredType {
        guard self != .never else { return other }
        guard other != .never else { return self }

        // Null beside a value is absence beside presence, and a slot that may
        // hold either is what `T?` says. A nullable side joins by what it
        // holds, so the one fact (null may be here) is said once.
        if self == .null { return other.admittingNull }
        if other == .null { return admittingNull }

        if case let .nullable(mine) = self {
            return mine.joined(other).admittingNull
        }

        if case let .nullable(theirs) = other {
            return joined(theirs).admittingNull
        }

        // Two procedures join to a procedure rather than to `any`, keeping the
        // constness both of them have. Collapsing here would let one body that
        // runs, in a list of them, pass a slot that asked for none, because
        // `any` is accepted everywhere.
        if
            case let .procedure(mine, myAnswer, wanted, wantedIsolation) = self,
            case let .procedure(_, _, offered, offeredIsolation) = other
        {
            let agreed = sameProcedure(as: other)

            return .procedure(
                parameters: agreed ? mine : nil,
                returns: agreed ? myAnswer : nil,
                constness: wanted == .const && offered == .const ? .const : .unstated,
                isolation: wantedIsolation == .isolated && offeredIsolation == .isolated ? .isolated : .unstated
            )
        }

        guard self != other else { return self }

        // Unequal spellings may still be one type: the equations (a range is an
        // int with a condition, bytes are `array<byte>`) are read through their
        // normal forms before the join gives up, and two arrays join by their
        // elements so the equation holds inside one.
        let mine = unrefined
        let theirs = other.unrefined

        if case let .array(myElement) = mine, case let .array(theirElement) = theirs {
            return .array(myElement.joined(theirElement))
        }

        return mine == theirs ? mine : .any
    }

    // Whether two procedure types declare the same slots and the same answer.
    // What each requires of the value is beside that, so a join may keep the
    // slots while reading the two requirements together.
    func sameProcedure(as other: LoweredType) -> Bool {
        guard
            case let .procedure(mine, myAnswer, _, _) = self,
            case let .procedure(theirs, theirAnswer, _, _) = other
        else {
            return false
        }

        guard myAnswer == theirAnswer else { return false }

        switch (mine, theirs) {
        case (nil, nil):
            return true

        case let (mine?, theirs?):
            return mine == theirs

        default:
            return false
        }
    }

    // A record of these fields, laid out the way the build lays every record
    // out: by the order of the field spellings.
    static func record(_ fields: [Name: LoweredType]) -> LoweredType {
        let ordered = fields.sorted { left, right in left.key < right.key }

        return .record(
            LoweredRecord(
                layout: Layout(name: nil, ordered: ordered.map(\.key)),
                fields: ordered.map(\.value)
            )
        )
    }

    // The reading judges: whether one type may stand where another is
    // declared, whether two types are one type, whether some value could
    // satisfy two types at once, and whether a candidate spelling could ever be
    // a value of a type. The build
    // asks them of readings; the run asks the first of a closure value that
    // reached a procedure slot through `any`. A name the table does not answer
    // passes every one of them: nothing is knowable about it here, and the
    // value judge refuses it where a value arrives.
    //
    // Whether a value of `other` may stand where this is declared.
    // Structural, and one-directional: `any` on the left accepts anything
    // because nothing was declared, and `any` on the right is accepted by
    // anything because nothing is known.
    func accepts(_ other: LoweredType, in table: LoweredTypeTable) -> Bool {
        accepts(other, in: table, assuming: [])
    }

    // The same question, carrying which pairs are already being asked. A
    // named type may reach itself through a type, so comparing one
    // structurally walks back to the comparison it is inside, and a
    // recursive type agrees with itself precisely when assuming it does
    // uncovers no disagreement. Only the two `named` doors record the pair.
    func accepts(_ other: LoweredType, in table: LoweredTypeTable, assuming: [(LoweredType, LoweredType)]) -> Bool {
        // Two declared records under two names are two types, whatever their
        // structure: a value settled under one name fits only that name.
        if
            case let .named(mine) = self,
            case let .named(theirs) = other,
            let myRecord = table.recordRows[mine],
            let theirRecord = table.recordRows[theirs],
            myRecord != theirRecord
        {
            return false
        }

        switch (self, other) {
        // What answers `never` never arrives, so it cannot be the value that
        // disagrees with a declaration. The other way round it fits nowhere.
        case (_, .never):
            return true

        // A type parameter accepts whatever fills it, and what fills it is
        // worked out at the call rather than here. In the other direction a
        // parameter stands for some type and this one is that type.
        case (.parameter, _), (_, .parameter):
            return true

        // A composition takes what is not provably outside any of its
        // bounds: a membership refuses what none of its members admit, a
        // contract refuses what the table settles as not answering. In the
        // other direction a composition stands for some type nothing here
        // lists.
        case let (.composition(bounds), _):
            guard !assuming.contains(where: { pair in pair.0 == self && pair.1 == other }) else { return true }

            return bounds.allSatisfy { bound in
                switch bound {
                case let .membership(row):
                    table.admits(constraint: row, reading: other, assuming: [], asking: assuming + [(self, other)])

                case let .contract(name):
                    if case .settled(false) = table.answering(contract: name, reading: other) { false } else { true }
                }
            }

        // In the other direction a value of a composition is one of every
        // membership's members and nothing says which, so it stands where
        // every member of some membership would. One bounded by contracts
        // alone stands for a type nothing here lists, so nothing is
        // provable and it passes to be judged where it arrives.
        case let (_, .composition(bounds)):
            let memberships = bounds.compactMap { bound -> Int? in
                guard case let .membership(row) = bound else { return nil }

                return row
            }

            guard !memberships.isEmpty else { return true }

            return memberships.contains { row in
                table.constraints[row].allSatisfy { member in accepts(member, in: table, assuming: assuming) }
            }

        // `var` is a fact about a slot, and fitting is asked of the inner
        // type.
        case let (.variable(inner), _):
            return inner.accepts(other, in: table, assuming: assuming)

        // A slot handed a variable in place is the two sides being one type,
        // not one that fits the other. The body writes through the caller's box
        // and the caller reads back what the body wrote, so a type that merely
        // fits would let the two disagree about what is there. The body writing
        // what its own declaration allows and the caller reading what its own
        // declaration promised.
        case let (.inout(inner), _):
            return inner.same(other.slotUnwrapped, in: table, assuming: assuming)

        case let (_, .variable(inner)), let (_, .inout(inner)):
            return accepts(inner, in: table, assuming: assuming)

        case (.any, _), (_, .any), (.reading, _), (_, .reading):
            return true

        case (.never, _):
            return false

        case (.undeclared, _), (_, .undeclared):
            return true

        case let (.named(row), _):
            guard !assuming.contains(where: { pair in pair.0 == self && pair.1 == other }) else { return true }

            return table.loweredTypes[row].accepts(other, in: table, assuming: assuming + [(self, other)])

        case let (_, .named(row)):
            guard !assuming.contains(where: { pair in pair.0 == self && pair.1 == other }) else { return true }

            return accepts(table.loweredTypes[row], in: table, assuming: assuming + [(self, other)])

        // A nullable slot takes null, the declared half, and anything
        // nullable whose declared half it takes. What may be null does not
        // stand where null was never declared.
        case (.nullable, .null):
            return true

        case let (.nullable(mine), .nullable(theirs)):
            return mine.accepts(theirs, in: table, assuming: assuming)

        case let (.nullable(mine), _):
            return mine.accepts(other, in: table, assuming: assuming)

        case let (.array(mine), .array(theirs)):
            return mine.accepts(theirs, in: table, assuming: assuming)

        case let (.dictionary(mine), .dictionary(theirs)):
            return mine.accepts(theirs, in: table, assuming: assuming)

        // A record is a dictionary whose fields happen to be known: a record
        // whose every field is the entry type is such a mapping. Not the
        // other way round, since a `dictionary` promises nothing about which
        // fields exist.
        case let (.dictionary(mine), .record(theirs)):
            return theirs.fields.allSatisfy { field in mine.accepts(field, in: table, assuming: assuming) }

        // Width: what stands here must declare at least the fields this one
        // names, and may declare more.
        case let (.record(mine), .record(theirs)):
            return mine.named.allSatisfy { name, field in
                theirs[name].map { given in field.accepts(given, in: table, assuming: assuming) } ?? false
            }

        case let (.procedure(required, wanted, wantedConstness, wantedIsolation),
                  .procedure(given, offered, offeredConstness, offeredIsolation)):
            // A slot asking for constness takes only what says it is const, and one
            // asking for isolation only what says it is isolated. The two are
            // separate claims: a const body answers without running and can
            // still reach a native procedure that holds state.
            guard wantedConstness != .const || offeredConstness == .const else { return false }
            guard wantedIsolation != .isolated || offeredIsolation == .isolated else { return false }

            // Nothing was said on one side or the other, so nothing is refused.
            guard let required, let given else { return true }

            // What stands here takes exactly the positions the slot hands: an
            // application gives every position, so a value of another count
            // is refused by every one of them.
            guard given.count == required.count else { return false }

            // The directions are opposite on purpose: what is given must
            // accept everything that will be passed to it, and what is
            // required must accept everything it will get back.
            for (parameter, taken) in zip(required, given) {
                guard taken.accepts(parameter, in: table, assuming: assuming) else { return false }
            }

            return (wanted ?? .any).accepts(offered ?? .any, in: table, assuming: assuming)

        // Two ranges are the one meeting where both sides are the text's
        // fact: the kinds under them decide which way a value may widen, and
        // bounds that cannot overlap are provably apart.
        case let (.ranged(mine), .ranged(theirs)):
            return mine.lowered.accepts(theirs.lowered, in: table, assuming: assuming)
                && mine.overlaps(theirs)

        // A range against anything else is its kind against that: the bounds
        // speak where a value is settled.
        case let (.ranged(mine), _):
            return mine.lowered.accepts(other, in: table, assuming: assuming)

        case let (_, .ranged(theirs)):
            return accepts(theirs.lowered, in: table, assuming: assuming)

        // The one conversion the language has, the way that cannot lose
        // anything.
        case (.double, .int):
            return true

        default:
            return self == other
        }
    }

    // The same type with every row it holds walked through to what that row
    // stands for. At every depth, not only the outermost.
    //
    // A row is a spelling, and two spellings of one type are one type: a
    // reading of `{ inner: Person }` and a claim of `{ inner: { name: string } }`
    // are the same thing said twice.
    func resolved(in table: LoweredTypeTable) -> LoweredType {
        resolved(in: table, assuming: [])
    }

    // Whether some value could satisfy both types at once. Not `accepts`:
    // two records that name no field in common accept each other in neither
    // direction and are still both satisfied by a value carrying every
    // field. The bias is deliberate: a refusal is earned only where the
    // types provably disagree, and everything else is left to the run.
    func couldBothHold(_ other: LoweredType, in table: LoweredTypeTable) -> Bool {
        couldBothHold(other, in: table, assuming: [])
    }

    // Whether an `enum` candidate could ever be a spelling of a value of this
    // type. Candidates are written as the scalar spellings arguments are
    // compared under, so a type with no scalar spelling spells none of
    // them, and a number is read by the spelling the boundary reads: `1e0`
    // is a fraction no fraction spells, so no call could ever match it.
    func spells(_ candidate: String, in table: LoweredTypeTable) -> Bool {
        switch self {
        case .any, .reading, .string, .undeclared:
            return true

        case .int, .double:
            return numeral(candidate, in: table) != nil

        // A candidate has to be a value the range itself would admit.
        case let .ranged(refinement):
            guard let value = refinement.lowered.numeral(candidate, in: table) else { return false }
            guard case .settled = refinement.settling(value) else { return false }

            return true

        case .bool:
            return candidate == "true" || candidate == "false"

        // An unbounded type parameter is filled by the call, so nothing about
        // the candidates is knowable here. A bounded one takes only what some
        // member of each of its memberships could spell.
        case let .parameter(_, bounds), let .composition(bounds):
            return bounds.allSatisfy { bound in
                guard case let .membership(constraint) = bound else { return true }

                return table.constraints[constraint].contains { member in member.spells(candidate, in: table) }
            }

        case let .named(row):
            return table.loweredTypes[row].spells(candidate, in: table)

        // A candidate spells a value, and null is not one an `enum` lists, so
        // a nullable slot's candidates are the declared half's.
        case let .nullable(inner), let .variable(inner), let .inout(inner):
            return inner.spells(candidate, in: table)

        case .null, .never, .array, .dictionary, .record, .procedure:
            return false
        }
    }

    // Whether two types are one type, names resolved. `any` is no wildcard
    // here and neither is a type parameter: standing for anything is what
    // `accepts` reads, and a body free to write anything into a variable the
    // caller declared is the disagreement this refuses.
    func same(_ other: LoweredType, in table: LoweredTypeTable) -> Bool {
        same(other, in: table, assuming: [])
    }

    func same(_ other: LoweredType, in table: LoweredTypeTable, assuming: [(LoweredType, LoweredType)]) -> Bool {
        if assuming.contains(where: { mine, theirs in mine == self && theirs == other }) { return true }

        let walked = assuming + [(self, other)]

        switch (self, other) {
        case (.undeclared, _), (_, .undeclared), (.parameter, _), (_, .parameter):
            return true

        // A record under a name is that name, so two names are two types
        // however alike. Every other name is what it names.
        case let (.named(mine), .named(theirs)):
            guard mine != theirs else { return true }

            return table.recordRows[mine] == nil
                && table.recordRows[theirs] == nil
                && table.loweredTypes[mine].same(table.loweredTypes[theirs], in: table, assuming: walked)

        case let (.named(mine), _):
            return table.recordRows[mine] == nil
                && table.loweredTypes[mine].same(other, in: table, assuming: walked)

        case let (_, .named(theirs)):
            return table.recordRows[theirs] == nil
                && same(table.loweredTypes[theirs], in: table, assuming: walked)

        case let (.nullable(mine), .nullable(theirs)),
            let (.array(mine), .array(theirs)),
            let (.dictionary(mine), .dictionary(theirs)),
            let (.variable(mine), .variable(theirs)),
            let (.inout(mine), .inout(theirs)):
            return mine.same(theirs, in: table, assuming: walked)

        case let (.record(mine), .record(theirs)):
            return mine.layout == theirs.layout
                && zip(mine.fields, theirs.fields).allSatisfy { one, other in
                    one.same(other, in: table, assuming: walked)
                }

        case let (.procedure(mine, myAnswer, myConstness, myIsolation),
                  .procedure(theirs, theirAnswer, theirConstness, theirIsolation)):
            guard myConstness == theirConstness, myIsolation == theirIsolation else { return false }

            switch (myAnswer, theirAnswer) {
            case (nil, nil):
                break

            case let (myAnswer?, theirAnswer?):
                guard myAnswer.same(theirAnswer, in: table, assuming: walked) else { return false }

            default:
                return false
            }

            switch (mine, theirs) {
            case (nil, nil):
                return true

            case let (mine?, theirs?):
                return mine.count == theirs.count
                    && zip(mine, theirs).allSatisfy { one, other in
                        one.same(other, in: table, assuming: walked)
                    }

            default:
                return false
            }

        // Every type that holds another is answered above; what is left
        // holds nothing.
        default:
            return self == other
        }
    }

    // The judge asked as a question. Settling is the one rule for what a
    // type holds, so whether it holds something is that rule run with its
    // refusal dropped rather than a second rule written beside it. The path
    // is empty because nothing reads the refusal.
    func settles(_ value: Value, in table: LoweredTypeTable, assuming: [Int] = []) -> Bool {
        (try? settling(value, at: "", in: table, assuming: assuming)) != nil
    }

    // What the type parameters in this declaration stand for, given what
    // arrived. Walked in step: where the declaration has a parameter, whatever
    // sits opposite it is what the parameter stands for; where both have a
    // type, the walk goes inside. Nothing infers across statements: a call
    // site is one place, and what it hands over is already known there.
    //
    // A parameter reached twice has to be read the same both times, so two
    // readings are a disagreement, written into `disagreeing`, rather than
    // widened to `any`.
    func binding(
        against given: LoweredType,
        into bound: inout [Name: LoweredType],
        disagreeing: inout [Name: LoweredType],
        holding: inout [Substitution.Held],
        in table: LoweredTypeTable,
        assuming: [Int] = []
    ) {
        switch (self, given) {
        // A composition has no name to be read under: what arrived is held
        // to its bounds where it arrived, wherever in the slot that was.
        case let (.composition(bounds), _):
            holding.append(Substitution.Held(reading: given, bounds: bounds))

        case let (.parameter(name, _), _):
            guard let already = bound[name] else {
                bound[name] = given

                return
            }

            guard already != given else { return }

            // Two readings agree when one takes the other. A list of numbers
            // and a whole number are not a disagreement, they are a parameter
            // read once loosely and once tightly, and the loose reading is the
            // one that holds both. `any` first, because it is the loosest
            // reading there is and `accepts` cannot order it: everything takes
            // `any` and `any` takes everything, so asking which is looser
            // answers yes both ways and whichever was read first would win. A
            // parameter read as `any` anywhere is `any`, which is what a list
            // of anything says about what may be put in it.
            guard already != .any else { return }

            guard given != .any else {
                bound[name] = .any

                return
            }

            // With the table, because a reading may stand on a row and the
            // type that row holds. Asking without it would call those two a
            // disagreement, which is the same question the build asks elsewhere
            // and answers correctly.
            // A range meets anything by its kind, so a range and the plain
            // kind under it take each other both ways, and so do two ranges
            // that overlap. Which was read first says nothing, so the reading
            // that holds both is the kind under them.
            if already.accepts(given, in: table) {
                switch (already, given) {
                case let (.ranged(mine), .ranged):
                    bound[name] = mine.lowered

                case (.ranged, _) where given.accepts(already, in: table):
                    bound[name] = given

                default:
                    break
                }

                return
            }

            if given.accepts(already, in: table) {
                bound[name] = given

                return
            }

            // The first reading is kept so that what is reported names both,
            // and so that everything downstream sees one answer rather than a
            // parameter that is two things.
            disagreeing[name] = given

        // A name on either side is walked through to the type it declares,
        // once, since a type may name itself. Behind a parameter, so that a
        // parameter reads a name as the name and not as what it declares.
        case let (.named(row), _) where !assuming.contains(row):
            table.loweredTypes[row].binding(
                against: given,
                into: &bound,
                disagreeing: &disagreeing,
                holding: &holding,
                in: table,
                assuming: assuming + [row]
            )

        case let (_, .named(row)) where !assuming.contains(row):
            binding(
                against: table.loweredTypes[row],
                into: &bound,
                disagreeing: &disagreeing,
                holding: &holding,
                in: table,
                assuming: assuming + [row]
            )

        // A parameter inside a nullable slot is read from the declared half.
        // Null carries no reading, and a nullable arrival reads by its own
        // declared half for the same reason.
        // A nullable slot takes null whole: it carries no reading and leaves
        // nothing to hold.
        case (.nullable, .null):
            return

        case let (.nullable(mine), .nullable(theirs)):
            mine.binding(against: theirs, into: &bound, disagreeing: &disagreeing, holding: &holding, in: table, assuming: assuming)

        case let (.nullable(mine), _):
            mine.binding(against: given, into: &bound, disagreeing: &disagreeing, holding: &holding, in: table, assuming: assuming)

        case let (.array(mine), .array(theirs)):
            mine.binding(against: theirs, into: &bound, disagreeing: &disagreeing, holding: &holding, in: table, assuming: assuming)

        case let (.dictionary(mine), .dictionary(theirs)):
            mine.binding(against: theirs, into: &bound, disagreeing: &disagreeing, holding: &holding, in: table, assuming: assuming)

        case let (.record(mine), .record(theirs)):
            for (name, field) in mine.named {
                guard let opposite = theirs[name] else { continue }

                field.binding(against: opposite, into: &bound, disagreeing: &disagreeing, holding: &holding, in: table, assuming: assuming)
            }

        case let (.variable(mine), _), let (.inout(mine), _):
            mine.binding(against: given, into: &bound, disagreeing: &disagreeing, holding: &holding, in: table, assuming: assuming)

        case let (_, .variable(theirs)), let (_, .inout(theirs)):
            binding(against: theirs, into: &bound, disagreeing: &disagreeing, holding: &holding, in: table, assuming: assuming)

        case let (.procedure(.some(mine), myAnswer, _, _), .procedure(.some(theirs), theirAnswer, _, _)):
            for (parameter, against) in zip(mine, theirs) {
                parameter.binding(against: against, into: &bound, disagreeing: &disagreeing, holding: &holding, in: table, assuming: assuming)
            }

            (myAnswer ?? .any).binding(
                against: theirAnswer ?? .any,
                into: &bound,
                disagreeing: &disagreeing,
                holding: &holding,
                in: table,
                assuming: assuming
            )

        default:
            return
        }
    }

    // This type with every parameter replaced by what it was read as. A
    // parameter nothing filled reads `any`, which is what a declaration says
    // when it says nothing.
    func filling(_ bound: [Name: LoweredType]) -> LoweredType {
        switch self {
        case let .parameter(name, _):
            return bound[name] ?? .any

        // Nothing fills a walk through a parameter. It is named for a path only
        // the body that wrote it can read, and no call site says anything about
        // that. So the caller reads what a declaration saying nothing says.
        case .reading:
            return .any

        case let .array(element):
            return .array(element.filling(bound))

        case let .dictionary(entry):
            return .dictionary(entry.filling(bound))

        case let .record(fields):
            return .record(
                LoweredRecord(
                    layout: fields.layout,
                    fields: fields.fields.map { field in field.filling(bound) }
                )
            )

        case let .procedure(parameters, returns, constness, isolation):
            return .procedure(
                parameters: parameters?.map { parameter in parameter.filling(bound) },
                returns: returns?.filling(bound),
                constness: constness,
                isolation: isolation
            )

        case let .variable(inner):
            return .variable(inner.filling(bound))

        case let .inout(inner):
            return .inout(inner.filling(bound))

        case let .nullable(inner):
            return .nullable(inner.filling(bound))

        default:
            return self
        }
    }

    // Whether a value read as this type could be a procedure: the question a
    // call of a value asks before the run. A reading no procedure could stand in
    // is a call every run refuses.
    func couldBeProcedure(in table: LoweredTypeTable) -> Bool {
        couldBeProcedure(in: table, assuming: [])
    }

    // Which rows this type stands on, in the two tables it names. Read by
    // answering every number with itself, so the walk over the tree stays
    // written once.
    func standing(into types: inout Set<Int>, and memberships: inout Set<Int>) {
        _ = renumbered(
            type: { row in
                types.insert(row)

                return row
            },
            membership: { row in
                memberships.insert(row)

                return row
            }
        )
    }

    // The same type with every row it stands on answered again. A type is a
    // tree and its rows stand at the leaves, so a caller that can answer one
    // number answers the whole of it, and the walk over the tree is written
    // once. Two answers, because a type names two tables: a declared type and
    // a membership are numbered in separate spaces, so which of them a number
    // counts in is a fact of the case it stands in.
    func renumbered(
        type: (Int) throws -> Int,
        membership: (Int) throws -> Int
    ) rethrows -> LoweredType {
        switch self {
        case let .array(element):
            return .array(try element.renumbered(type: type, membership: membership))

        case let .dictionary(entry):
            return .dictionary(try entry.renumbered(type: type, membership: membership))

        case let .record(held):
            return .record(
                LoweredRecord(
                    layout: held.layout,
                    fields: try held.fields.map { field in
                        try field.renumbered(type: type, membership: membership)
                    }
                )
            )

        case let .procedure(parameters, returns, constness, isolation):
            return .procedure(
                parameters: try parameters?.map { parameter in
                    try parameter.renumbered(type: type, membership: membership)
                },
                returns: try returns?.renumbered(type: type, membership: membership),
                constness: constness,
                isolation: isolation
            )

        case let .variable(inner):
            return .variable(try inner.renumbered(type: type, membership: membership))

        case let .inout(inner):
            return .inout(try inner.renumbered(type: type, membership: membership))

        case let .nullable(inner):
            return .nullable(try inner.renumbered(type: type, membership: membership))

        case let .named(row):
            return .named(try type(row))

        case let .parameter(label, bounds):
            return .parameter(label: label, bounds: try Self.renumbered(bounds, membership: membership))

        case let .composition(bounds):
            return .composition(try Self.renumbered(bounds, membership: membership))

        // Every case that stands on no row, listed rather than let through:
        // a case added here has to say whether it holds one.
        case .any, .never, .null, .bool, .int, .double, .string,
            .ranged, .reading, .undeclared:
            return self
        }
    }

    // The value judge: what a type accepts, settled to the declared
    // representation, or a refusal saying which part disagreed. The one judge
    // for a value crossing a declaration, at the build and at the run alike.
    //
    // `at` is the path into the value so the message names the field rather
    // than the whole argument. `assuming` is which constraints are already
    // being asked of this value: a bounded parameter's membership test
    // settles the value against each member, and a member reaching a
    // bounded parameter again walks back into the same question, so met
    // again it is assumed rather than asked.
    func settling(
        _ value: Value,
        at path: @autoclosure () -> String,
        in table: LoweredTypeTable,
        assuming: [Int] = []
    ) throws -> Value {
        switch self {
        case .any, .reading:
            return value

        // Both ask the membership and neither settles: a value stands as what
        // it arrived as, and which member it matched is a question a cast asks.
        case let .parameter(_, bounds), let .composition(bounds):
            return try bounds.reduce(value) { value, bound in
                try standing(value, boundBy: bound, at: path(), in: table, assuming: assuming)
            }

        default:
            return try judging(value, at: path(), in: table, assuming: assuming)
        }
    }

    // A value handed to a slot of this type: a null where the type admits
    // one, and otherwise the value settled. `locus` is where a refusal says
    // the value stood, in the caller's terms.
    func checking(_ value: Value, at locus: String, in table: LoweredTypeTable) throws -> Value {
        guard value != .null else {
            guard admitsNull(in: table) else {
                throw ArgumentError("\(locus): expected \(rendered(in: table)), got null")
            }

            return value
        }

        return try settling(value, at: locus, in: table)
    }

    // What a cast does, said once. The judgment is `settling`'s; what this
    // adds is the one thing the cast spelling decides: what a mismatch means.
    func reading(_ value: Value, optional: Bool, in table: LoweredTypeTable) throws -> Value {
        do {
            return try settling(value, at: "as \(rendered(in: table))", in: table)
        } catch let mismatch as ArgumentError {
            // Only a mismatch is read as the author's expectation. Naming what
            // is absorbed rather than what is not keeps the default closed:
            // an error kind added later surfaces instead of quietly becoming
            // null.
            guard optional else {
                // Recoverable, unlike the same refusal at a parameter's
                // boundary: a cast is the author expecting a kind of data
                // that came from outside, and being wrong about that is what
                // the world does. An `attempt` catches it.
                throw CastRefused(
                    mismatch.message,
                    expected: rendered(in: table),
                    actual: "\(value.type)"
                )
            }

            return .null
        }
    }

    // Whether a scalar member admits a value: by kind, with the one widening,
    // and without settling. Nil for a member that is not a scalar, which is
    // judged by settling the value against it.
    func admitsAsScalar(_ value: Value) -> Bool? {
        switch (self, value) {
        case (.null, .null), (.bool, .bool), (.int, .int), (.double, .double), (.double, .int),
            (.string, .string):
            return true

        case (.null, _), (.bool, _), (.int, _), (.double, _), (.string, _):
            return false

        default:
            return nil
        }
    }

    // Whether a null that arrives is one of this type's values. `any` is
    // here and not below: it accepts what it is handed, null included.
    func admitsNull(in table: LoweredTypeTable) -> Bool {
        switch self {
        case .any:
            return true

        case let .named(row):
            return table.loweredTypes[row].admitsNull(in: table)

        // A parameter stands for what arrived and does not settle it, so an
        // unbounded one holds a null the way it holds anything; a bounded
        // one, and a composition, hold null only where every bound does.
        case let .parameter(_, bounds), let .composition(bounds):
            return bounds.allSatisfy { bound in bound.admitsNull(in: table) }

        default:
            return declaresNull(in: table)
        }
    }

    // Whether null is one of this type's values rather than an absence: the
    // fact `T?` exists to declare, and the boundary reads it. `any` is not
    // this: an undeclared type accepts a null that arrives, but it does not
    // spell null as a value.
    func declaresNull(in table: LoweredTypeTable) -> Bool {
        switch self {
        case .null, .nullable:
            return true

        case let .named(row):
            return table.loweredTypes[row].declaresNull(in: table)

        // A value of a composition is one of every membership's members, so
        // null is spelled here where every membership has a member spelling it.
        case let .composition(bounds):
            return bounds.allSatisfy { bound in
                guard case let .membership(constraint) = bound else { return false }

                return table.constraints[constraint].contains { member in member.declaresNull(in: table) }
            }

        default:
            return false
        }
    }

    // Whether every byte settles into this element declaration as itself,
    // unchanged and with nothing asked of any one of them. This is what lets
    // a compact spelling cross a boundary whole. It says the same thing
    // `settling` says one byte at a time, and a test holds the two together.
    //
    // The two sets are two number spaces: a type row and a constraint row
    // may carry the same number, and folding the guards into one would let a
    // type's row end a constraint's question by assuming it.
    func holdsEveryByte(
        in table: LoweredTypeTable,
        namedAssuming: [Int] = [],
        boundAssuming: [Int] = []
    ) -> Bool {
        switch self {
        case .any, .reading, .int:
            return true

        case let .variable(inner), let .inout(inner), let .nullable(inner):
            return inner.holdsEveryByte(in: table, namedAssuming: namedAssuming, boundAssuming: boundAssuming)

        // A parameter stands for what arrived and does not settle it. A
        // bounded one still asks each value for its membership, and a member
        // that takes every byte answers that question for all of them at
        // once.
        case let .parameter(_, bounds), let .composition(bounds):
            return bounds.allSatisfy { bound in
                guard case let .membership(constraint) = bound else { return true }

                return holdsEveryByte(
                    of: constraint,
                    in: table,
                    namedAssuming: namedAssuming,
                    boundAssuming: boundAssuming
                )
            }

        case let .ranged(refinement):
            return refinement.holdsEveryByte

        case let .named(row):
            guard !namedAssuming.contains(row) else { return false }

            return table.loweredTypes[row].holdsEveryByte(
                in: table,
                namedAssuming: namedAssuming + [row],
                boundAssuming: boundAssuming
            )

        // `double` is the one widening the language has, so it changes every
        // byte it takes; the rest take no byte at all. Named rather than left
        // to a default, so that a kind added to the type language has to be
        // answered for here too.
        case .never, .null, .bool, .double, .string,
             .array, .dictionary, .record, .procedure, .undeclared:
            return false
        }
    }

    // A candidate of an `enum` read as the number its canonical spelling names
    // for this slot: a fraction slot reads only fraction spellings, so the
    // boundary and the build agree on which members exist. Nil where the
    // spelling names no number the slot takes.
    func numeral(_ candidate: String, in table: LoweredTypeTable) -> Value? {
        switch self {
        case .int:
            return Int(spelling: candidate).map(Value.int)

        // A range is a condition on a number, so the spelling it reads is the
        // spelling of the kind under it.
        case let .ranged(refinement):
            return refinement.lowered.numeral(candidate, in: table)

        case .double:
            return Double(spelling: candidate).map(Value.double)

        case let .named(row):
            return table.loweredTypes[row].numeral(candidate, in: table)

        case let .nullable(inner):
            return inner.numeral(candidate, in: table)

        // A parameter a constraint bounds, and the slots that declare no
        // numeric type at all: the slot does not name one kind,
        // so a numeral is whichever kind's one spelling the text is.
        default:
            if let whole = Int(spelling: candidate) { return .int(whole) }

            return Double(spelling: candidate).map(Value.double)
        }
    }

    // How the type reads in a message: the spelling the author wrote, with
    // a row's label standing where the author wrote the name.
    func rendered(in table: LoweredTypeTable) -> String {
        switch self {
        case .any:
            return "any"

        // Spelled as what it is: the type reached by that path. No document
        // writes this, so the spelling answers to the message alone, and an
        // author reading a refusal about `item.a` sees where it came from.
        case let .reading(of, path):
            return "some \(Path([.key(of)] + path.segments).rendered)"

        case .never:
            return "never"

        case .null:
            return "null"

        case .bool:
            return "bool"

        case .int:
            return "int"

        case .double:
            return "double"

        case .string:
            return "string"

        case let .ranged(refinement):
            return refinement.rendered

        case let .parameter(label, bounds):
            return bounds.isEmpty ? "some \(label)" : "some \(label): \(Self.rendered(bounds, in: table))"

        case let .composition(bounds):
            return Self.rendered(bounds, in: table)

        case let .variable(inner):
            return "var \(inner.rendered(in: table))"

        case let .inout(inner):
            return "inout \(inner.rendered(in: table))"

        case let .procedure(parameters, returns, constness, isolation):
            let spelling = [
                constness == .const ? "const" : nil,
                isolation == .isolated ? "isolated" : nil,
                "procedure"
            ]
            .compactMap { part in part }
            .joined(separator: " ")

            guard let parameters else { return spelling }

            let written = parameters.map { parameter in parameter.rendered(in: table) }

            return "\(spelling)<(\(written.joined(separator: ", ")))"
                + " -> \((returns ?? .any).rendered(in: table))>"

        case let .array(element):
            return "array<\(element.rendered(in: table))>"

        case let .dictionary(entry):
            return "dictionary<\(entry.rendered(in: table))>"

        case let .record(held):
            let written = held.named.map { name, field in
                "\(name): \(field.rendered(in: table))"
            }

            return "{ \(written.joined(separator: ", ")) }"

        case let .named(row):
            return table.labels[row].spelling

        case let .undeclared(label, _):
            return label

        case let .nullable(inner):
            return "\(inner.rendered(in: table))?"
        }
    }

    static func == (lhs: LoweredType, rhs: LoweredType) -> Bool {
        switch (lhs, rhs) {
        case (.any, .any), (.never, .never), (.null, .null), (.bool, .bool), (.int, .int),
            (.double, .double), (.string, .string):
            return true

        case let (.ranged(mine), .ranged(theirs)):
            return mine == theirs

        case let (.array(mine), .array(theirs)), let (.dictionary(mine), .dictionary(theirs)),
            let (.variable(mine), .variable(theirs)), let (.inout(mine), .inout(theirs)),
            let (.nullable(mine), .nullable(theirs)):
            return mine == theirs

        case let (.record(mine), .record(theirs)):
            return mine == theirs

        case let (.procedure(_, _, myConstness, myIsolation),
                  .procedure(_, _, theirConstness, theirIsolation)):
            return myConstness == theirConstness
                && myIsolation == theirIsolation
                && lhs.sameProcedure(as: rhs)

        case let (.named(mine), .named(theirs)):
            return mine == theirs

        case let (.parameter(myLabel, mine), .parameter(theirLabel, theirs)):
            return myLabel == theirLabel && mine == theirs

        case let (.composition(mine), .composition(theirs)):
            return mine == theirs

        case let (.reading(myRoot, myPath), .reading(theirRoot, theirPath)):
            return myRoot == theirRoot && myPath == theirPath

        case let (.undeclared(mine, _), .undeclared(theirs, _)):
            return mine == theirs

        default:
            return false
        }
    }

    // MARK: - Private
    // A row already being walked through stands as itself. A type may name
    // itself (`Tree` holding `array<Tree>` is a declared type) so a walk that
    // expanded every row at every depth would chase one forever.
    private func resolved(in table: LoweredTypeTable, assuming: [Int]) -> LoweredType {
        switch self {
        case let .named(row):
            guard !assuming.contains(row) else { return self }

            return table.loweredTypes[row].resolved(in: table, assuming: assuming + [row])

        case let .array(element):
            return .array(element.resolved(in: table, assuming: assuming))

        case let .dictionary(element):
            return .dictionary(element.resolved(in: table, assuming: assuming))

        case let .nullable(element):
            return .nullable(element.resolved(in: table, assuming: assuming))

        case let .record(fields):
            return .record(
                LoweredRecord(
                    layout: fields.layout,
                    fields: fields.fields.map { field in field.resolved(in: table, assuming: assuming) }
                )
            )

        default:
            return self
        }
    }

    // Names are peeled one layer at a time, with the rows already being
    // asked about remembered, because this walk is the one that recurses.
    private func couldBothHold(_ other: LoweredType, in table: LoweredTypeTable, assuming: [Int]) -> Bool {
        if
            case let .named(mine) = self,
            case let .named(theirs) = other,
            let myRecord = table.recordRows[mine],
            let theirRecord = table.recordRows[theirs],
            myRecord != theirRecord
        {
            return false
        }

        if case let .named(row) = self {
            guard !assuming.contains(row) else { return true }

            return table.loweredTypes[row].couldBothHold(other, in: table, assuming: assuming + [row])
        }

        if case let .named(row) = other {
            guard !assuming.contains(row) else { return true }

            return couldBothHold(table.loweredTypes[row], in: table, assuming: assuming + [row])
        }

        if provesNothing || other.provesNothing { return true }

        // A value of a composition is one of every membership's members, so
        // a value could be both wherever one member could.
        if case let .composition(bounds) = self {
            return bounds.allSatisfy { bound in
                guard case let .membership(row) = bound else { return true }

                return table.constraints[row].contains { member in
                    member.couldBothHold(other, in: table, assuming: assuming)
                }
            }
        }

        if case let .composition(bounds) = other {
            return bounds.allSatisfy { bound in
                guard case let .membership(row) = bound else { return true }

                return table.constraints[row].contains { member in
                    couldBothHold(member, in: table, assuming: assuming)
                }
            }
        }

        if case .undeclared = self { return true }
        if case .undeclared = other { return true }

        // Null is a value both hold, so one exists whatever else they say.
        if declaresNull(in: table), other.declaresNull(in: table) { return true }

        // Two ranges are asked of the judge that decides them, the way
        // `accepts` asks it: what is provably apart is refused here.
        if case let .ranged(mine) = self, case let .ranged(theirs) = other {
            return mine.lowered.couldBothHold(theirs.lowered, in: table, assuming: assuming)
                && mine.overlaps(theirs)
        }

        // Refinements and compact spellings are dropped first: whether a
        // value could be both is a question about kinds.
        switch (unrefined, other.unrefined) {
        case let (.nullable(inner), side), let (side, .nullable(inner)):
            return inner.couldBothHold(side, in: table, assuming: assuming)

        // What both name has to be able to hold at once; what only one names
        // is data the other lets ride through.
        case let (.record(mine), .record(theirs)):
            return mine.named.allSatisfy { name, field in
                theirs[name].map { given in field.couldBothHold(given, in: table, assuming: assuming) } ?? true
            }

        // A dictionary and a record are one value at run time read two ways, so
        // every field the record names must be able to be an entry. A list
        // and a map are not asked about their elements: an empty one is of
        // every element type there is.
        case let (.dictionary(entry), .record(held)), let (.record(held), .dictionary(entry)):
            return held.fields.allSatisfy { field in field.couldBothHold(entry, in: table, assuming: assuming) }

        // Two decided kinds, which is where a value either is both or is
        // neither. Anything else this walk does not read into is the run's.
        case let (mine, theirs):
            guard mine.isDecidedKind, theirs.isDecidedKind else { return true }

            // Asked of the judge that will settle it, not of a second opinion
            // about what it would say. One witness per kind is enough here.
            return LoweredType.witnesses.contains { witness in
                mine.settles(witness, in: table) && theirs.settles(witness, in: table)
            }
        }
    }

    // Names are peeled one layer at a time, with the rows already being asked
    // about remembered, since a membership may name itself through a row.
    private func couldBeProcedure(in table: LoweredTypeTable, assuming: [Int]) -> Bool {
        switch self {
        case .procedure, .any, .never, .reading, .undeclared:
            return true

        case let .nullable(inner), let .variable(inner), let .inout(inner):
            return inner.couldBeProcedure(in: table, assuming: assuming)

        case let .named(row):
            guard !assuming.contains(row) else { return false }

            return table.loweredTypes[row].couldBeProcedure(in: table, assuming: assuming + [row])

        // A value of a type parameter or a composition is one of every
        // bound's members at once. A contract is answered by declared types,
        // and a procedure wears no name to answer one.
        case let .parameter(_, bounds), let .composition(bounds):
            return bounds.allSatisfy { bound in
                switch bound {
                case let .membership(row):
                    return table.constraints[row].contains { member in
                        member.couldBeProcedure(in: table, assuming: assuming)
                    }

                case .contract:
                    return false
                }
            }

        case .null, .bool, .int, .double, .string, .ranged, .array, .dictionary, .record:
            return false
        }
    }

    // The same bounds over the rows the transform answers: a membership
    // stands on a row and a contract on a name. Sorted again, since the
    // order is the rows' and the rows moved.
    private static func renumbered(_ bounds: [Bound], membership: (Int) throws -> Int) rethrows -> [Bound] {
        try bounds.map { bound in
            guard case let .membership(row) = bound else { return bound }

            return .membership(try membership(row))
        }
        .sorted()
    }

    // Whether the types a membership admits take every byte between them.
    private func holdsEveryByte(
        of constraint: Int,
        in table: LoweredTypeTable,
        namedAssuming: [Int],
        boundAssuming: [Int]
    ) -> Bool {
        guard !boundAssuming.contains(constraint) else { return true }

        let deeper = boundAssuming + [constraint]

        if table.constraints[constraint].contains(where: { member in
            member.holdsEveryByte(in: table, namedAssuming: namedAssuming, boundAssuming: deeper)
        }) {
            return true
        }

        // No one member covers it, so the complete question is asked with the
        // boundary's own primitive: members that divide the range between them
        // still take every byte.
        return (0 ... 255).allSatisfy { byte in
            table.admits(constraint: constraint, value: .int(byte), assuming: deeper)
        }
    }

    // The names joined with `&`, as a composition or a bound is spelled.
    private static func rendered(_ bounds: [Bound], in table: LoweredTypeTable) -> String {
        bounds.map { bound -> String in
            switch bound {
            case let .membership(row): table.constraintLabels[row].spelling
            case let .contract(name): name.spelling
            }
        }.joined(separator: " & ")
    }

    // Every type that reads the value it is given. The rest are answered by
    // `settling` and never arrive here; reaching this by another
    // door sends them back to it.
    private func judging(
        _ value: Value,
        at path: @autoclosure () -> String,
        in table: LoweredTypeTable,
        assuming: [Int]
    ) throws -> Value {
        switch self {
        case .any, .reading, .parameter, .composition:
            return try settling(value, at: path(), in: table, assuming: assuming)

        // A value arrived where nothing was supposed to, so the arrival is the
        // refusal: there is no type to compare it against.
        case .never:
            throw ArgumentError("\(path()): declares never, and nothing is ever that")

        case let .undeclared(label, because):
            switch because {
            case let .noTypeNamed(name):
                throw UndeclaredTypeError("\(path()): declares type '\(name)', which nothing declares")

            case let .noBoundNamed(name):
                throw UndeclaredTypeError("\(path()): declares '\(name)', which nothing declares as a membership or a contract")

            case .namesItself:
                throw UndeclaredTypeError("\(path()): declares type '\(label)', which names itself")
            }

        // A declared record is nominal. A record arriving without a name
        // settles to the declared type and takes the name; one arriving
        // under this name is settled again and keeps it; one arriving under
        // another name is refused, whatever its type. A declared name that is
        // not a record type settles as the type it stands for.
        case let .named(row):
            return try settlingNamed(value, row: row, at: path(), in: table, assuming: assuming)

        // Null arrives as itself; anything else is held to the declared half.
        case let .nullable(inner):
            guard value != .null else { return value }

            return try inner.settling(value, at: path(), in: table, assuming: assuming)

        case let .array(element):
            // Bytes are an array of bytes in a compact spelling, so they arrive
            // here as the array they are. Where the declaration leaves every
            // byte as it is, the compact spelling crosses whole: the slot
            // asked for an array and one is what it has, and unpacking it would
            // spend an element per byte to answer nothing.
            if case .bytes = value, element.holdsEveryByte(in: table, boundAssuming: assuming) {
                return value
            }

            // An element nothing was declared for passes as it is, so the
            // array does too: settling each element to itself would copy the
            // array to say nothing.
            if element == .any, case .array = value { return value }

            // Otherwise the slot's spelling wins the way `double` settles a
            // whole number, and both spellings are read through the one
            // projection that owns the equation.
            guard let items = value.elements else { throw mismatch(value, at: path(), in: table) }

            return .array(
                try items.enumerated().map { index, item in
                    try element.settling(item, at: "\(path())[\(index)]", in: table, assuming: assuming)
                }
            )

        // A dictionary slot holds the names as data, so a record settling
        // here becomes one, its layout's names written beside their values.
        case let .dictionary(entry):
            guard let held = value.asDictionary else { throw mismatch(value, at: path(), in: table) }

            if entry == .any { return .dictionary(held) }

            return .dictionary(
                try held.mapValues { _, item in
                    try entry.settling(item, at: path(), in: table, assuming: assuming)
                }
            )

        // An inline record is structural: a value holding at least these
        // fields fits it, whatever else it holds and whatever it is named.
        // Settling builds the slot's layout, so what settles here holds these
        // fields and no others.
        case let .record(held):
            return try settlingFields(value, of: held, at: path(), in: table, assuming: assuming)

        // A slot writes `var` or `inout` about itself; what stands in it is a
        // value of the inner type.
        case let .variable(inner), let .inout(inner):
            return try inner.settling(value, at: path(), in: table, assuming: assuming)

        // A closure carries what the build derived about its text, its constness
        // and its isolation, and a slot that asks for either reads the
        // carried fact. A closure that reached here through `any` or through
        // an undeclared field is judged here for the first time.
        case let .procedure(required, returns, constness, isolation):
            return try settlingProcedure(
                value,
                parameters: required,
                returns: returns,
                constness: constness,
                isolation: isolation,
                at: path(),
                in: table
            )

        // The bounds speak where the value does: a number inside them settles
        // as the kind's own value, and one outside is refused by the range
        // the declaration wrote.
        case let .ranged(refinement):
            switch refinement.settling(value) {
            case let .settled(settled):
                return settled

            case .otherKind:
                throw mismatch(value, at: path(), in: table)

            case let .outside(number):
                throw ArgumentError("\(path()): \(number) is outside \(rendered(in: table))")
            }

        // The scalars, plus the one widening the language has, one way only:
        // an int where a double is declared. Nothing narrows; an int slot
        // refuses every fraction, `2.0` included.
        case .null, .bool, .int, .double, .string:
            guard let settled = scalar(value) else { throw mismatch(value, at: path(), in: table) }

            return settled
        }
    }

    // A type parameter the call site filled, and the build is where it was
    // filled. Unbounded, there is nothing left to compare against. A bounded
    // one still holds its constraint here: what arrived through `any` was
    // never read at the build, so membership is judged against the types the
    // constraint admits, and the value passes untouched. A parameter stands
    // for what arrived; it does not settle it.
    private func standing(
        _ value: Value,
        boundBy bound: LoweredType.Bound,
        at path: @autoclosure () -> String,
        in table: LoweredTypeTable,
        assuming: [Int]
    ) throws -> Value {
        // A contract is answered by the value's own name: what the link found
        // to satisfy it is what a value may arrive as.
        //
        // A table that cannot say which types answer writes the pair down and
        // lets the value pass, so the list that holds every claim answers for
        // it. Where there is nowhere to write, there is nothing to wait for
        // and the value is held to what this table knows.
        if case let .contract(name) = bound {
            switch table.settles(contract: name, arrived: value.nominal) {
            case true?:
                return value

            case nil:
                guard let type = value.nominal, let unsettled = table.unsettled else {
                    throw ArgumentError(
                        "\(path()): expected \(rendered(in: table)), and"
                            + " \(value.nominal.map { held in "'\(held)'" } ?? "\(value.type)")"
                            + " does not answer every procedure '\(name)' asks"
                    )
                }

                unsettled.require(folded: Claim(type: type, contract: name))

                return value

            case false?:
                let arrived = value.nominal.map { held in "'\(held)'" } ?? "\(value.type)"

                throw ArgumentError(
                    "\(path()): expected \(rendered(in: table)), and \(arrived)"
                        + " does not answer every procedure '\(name)' asks"
                )
            }
        }

        guard case let .membership(constraint) = bound, !assuming.contains(constraint) else { return value }

        guard table.admits(constraint: constraint, value: value, assuming: assuming) else {
            throw ArgumentError(
                "\(path()): expected \(rendered(in: table)), and nothing"
                    + " '\(table.constraintLabels[constraint])' admits takes \(value.type)."
                    + " \(refused(value, by: constraint, at: path(), in: table, assuming: assuming))"
            )
        }

        return value
    }

    // Why each member of a membership said no, in one line. A membership
    // holding one type of collection refuses a bad element, and the element
    // is what the author has to go and fix.
    private func refused(
        _ value: Value,
        by constraint: Int,
        at path: String,
        in table: LoweredTypeTable,
        assuming: [Int]
    ) -> String {
        let deeper = assuming + [constraint]

        return table.constraints[constraint]
            .map { member in
                // A scalar member says only that the kind is wrong, and the
                // kind is already in front of the reader.
                if member.admitsAsScalar(value) != nil {
                    return "as \(member.rendered(in: table)), got \(value.type)"
                }

                do {
                    _ = try member.settling(value, at: path, in: table, assuming: deeper)

                    return "as \(member.rendered(in: table)), got \(value.type)"
                } catch {
                    return "as \(member.rendered(in: table)), \(error)"
                }
            }
            .joined(separator: ". ")
    }

    private func settlingNamed(
        _ value: Value,
        row: Int,
        at path: @autoclosure () -> String,
        in table: LoweredTypeTable,
        assuming: [Int]
    ) throws -> Value {
        let declared = table.loweredTypes[row]

        guard value.holdsFields, let nominal = table.record(of: self) else {
            return try declared.settling(value, at: path(), in: table, assuming: assuming)
        }

        let label = table.labels[nominal]

        // A tag already canonical is the same spelling. One that is not
        // is an alias or another record, told apart by the table once.
        if case let .record(record) = value, let tag = record.name, tag != label {
            guard let spelled = table.row(named: tag), table.recordRows[spelled] == nominal else {
                throw ArgumentError("\(path()): is a \(tag), and the slot declares \(label)")
            }
        }

        guard case let .record(settled) = try declared.settling(value, at: path(), in: table, assuming: assuming) else {
            throw mismatch(value, at: path(), in: table)
        }

        return .record(settled.named(label))
    }

    private func settlingFields(
        _ value: Value,
        of held: LoweredRecord,
        at path: @autoclosure () -> String,
        in table: LoweredTypeTable,
        assuming: [Int]
    ) throws -> Value {
        guard value.holdsFields else { throw mismatch(value, at: path(), in: table) }

        return .record(
            Record(
                layout: held.layout,
                values: try held.named.map { name, field in
                    guard let given = value[name] else {
                        throw ArgumentError(
                            "\(path()).\(name): required by \(rendered(in: table)), and nothing was given"
                        )
                    }

                    return try field.settling(given, at: "\(path()).\(name)", in: table, assuming: assuming)
                }
            )
        )
    }

    private func settlingProcedure(
        _ value: Value,
        parameters required: [LoweredType]?,
        returns: LoweredType?,
        constness: Constness,
        isolation: Isolation,
        at path: @autoclosure () -> String,
        in table: LoweredTypeTable
    ) throws -> Value {
        guard case let .procedure(closure) = value else { throw mismatch(value, at: path(), in: table) }

        // Its rows are numbered by the table of the build that made it, and a
        // closure no build answered is refused here in this door's words.
        guard let linked = closure.linked else {
            throw ArgumentError("\(path()): a closure no link answered")
        }

        guard linked.readable(in: table) else {
            throw ArgumentError("\(path()): \(Linked.unreadable)")
        }

        if constness == .const, linked.constness != .const {
            throw ArgumentError(
                "\(path()): expected \(rendered(in: table)), got a procedure that runs"
            )
        }

        if isolation == .isolated, linked.isolation != .isolated {
            throw ArgumentError(
                "\(path()): expected \(rendered(in: table)), got a procedure that writes"
                    + " what another body could touch"
            )
        }

        let given = LoweredType.procedure(
            parameters: linked.slots.map(\.type),
            returns: linked.returns,
            constness: linked.constness,
            isolation: linked.isolation
        )

        guard LoweredType.procedure(parameters: required, returns: returns, constness: .unstated, isolation: .unstated).accepts(given, in: table) else {
            throw ArgumentError(
                "\(path()): expected \(rendered(in: table)), got \(given.rendered(in: table))"
            )
        }

        return value
    }

    // The one conversion the language performs, and it goes one way: every
    // whole number is a fraction, so a slot asking for a fraction can take a
    // whole one and lose nothing.
    private func scalar(_ value: Value) -> Value? {
        switch (self, value) {
        case (.null, .null), (.bool, .bool), (.int, .int), (.double, .double),
            (.string, .string):
            return value

        // The widening is binary64's own rounding, and every int has
        // a fraction near it: the conversion cannot fail, only round.
        case let (.double, .int(integer)):
            return .double(Double(integer))

        default:
            return nil
        }
    }

    private func mismatch(_ value: Value, at path: String, in table: LoweredTypeTable) -> ArgumentError {
        ArgumentError("\(path): expected \(rendered(in: table)), got \(value.type)")
    }
}
