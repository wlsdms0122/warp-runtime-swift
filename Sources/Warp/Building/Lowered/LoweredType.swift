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
    // way it answers `Any`; it stands apart for the walk's own naming.
    case projection(of: Name, path: Path)

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
        // contract is answered by a type and null wears none. A membership
        // already being asked adds no member.
        func admitsNull(in table: LoweredTypeTable, asking: Asking) -> Bool {
            guard case let .membership(constraint) = self else { return false }

            return table.someMember(of: constraint, asking: asking) { member, asked in member.admitsNull(in: table, asking: asked) }
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
            .named, .parameter, .composition, .projection, .undeclared:
            return self
        }
    }

    // Whether a slot holding this may be written through.
    var isVariable: Bool {
        if case .variable = self { return true }

        return false
    }

    // Whether a slot holding this takes a variable in place.
    var isInout: Bool {
        if case .inout = self { return true }

        return false
    }

    // Whether a type parameter stands anywhere in this type. A declared name
    // or a composition writes none.
    var namesParameter: Bool {
        switch self {
        case .parameter:
            return true

        case let .array(inner), let .dictionary(inner), let .nullable(inner), let .variable(inner), let .inout(inner):
            return inner.namesParameter

        case let .record(record):
            return record.fields.contains { field in field.namesParameter }

        case let .procedure(parameters, returns, _, _):
            return (parameters ?? []).contains { parameter in parameter.namesParameter }
                || (returns?.namesParameter ?? false)

        case .any, .never, .null, .bool, .int, .double, .string, .ranged, .named, .composition, .projection, .undeclared:
            return false
        }
    }

    // Whether this is a slot taking a variable in place whose type names a
    // type parameter: one a call hands back to be judged, where the body
    // writes it as the parameter and the caller holds it as what filled it.
    var handsBackParameter: Bool {
        guard case let .inout(held) = self else { return false }

        return held.namesParameter
    }

    // Every type parameter this names, by label, with the bounds it is held
    // to.
    var boundedParameters: [Name: [Bound]] {
        switch self {
        case let .parameter(label, bounds):
            return [label: bounds]

        case let .array(inner), let .dictionary(inner), let .nullable(inner), let .variable(inner), let .inout(inner):
            return inner.boundedParameters

        case let .record(record):
            return record.fields.reduce(into: [:]) { found, field in found.merge(field.boundedParameters) { first, _ in first } }

        case let .procedure(parameters, returns, _, _):
            return ((parameters ?? []) + [returns].compactMap { $0 }).reduce(into: [:]) { found, part in
                found.merge(part.boundedParameters) { first, _ in first }
            }

        case .any, .never, .null, .bool, .int, .double, .string, .ranged, .named, .composition, .projection, .undeclared:
            return [:]
        }
    }

    // What a slot holds, through the two marks that say how it is held
    // rather than what it is.
    var slotUnwrapped: LoweredType {
        switch self {
        case let .variable(inner), let .inout(inner):
            return inner.slotUnwrapped

        case .any, .never, .null, .bool, .int, .double, .string,
            .ranged, .array, .dictionary, .record, .procedure, .nullable,
            .named, .parameter, .composition, .projection, .undeclared:
            return self
        }
    }

    // The row this stands on, through `?`, `var` and `inout`, which hold no
    // value of their own. Nil for a type that names no row. Whether a chain
    // of names comes back on itself follows this, so a name reached under a
    // wrapper is a link of the chain and not its end.
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
        case .parameter, .projection:
            return true

        default:
            return false
        }
    }

    // What a judgment sees. A projection says a path was taken through a type
    // the call decides, which proves nothing about what it holds, and that is
    // what `Any` says.
    var judged: LoweredType {
        if case .projection = self { return .any }

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

    // What a slot said about the procedure it holds. A body applying a name a
    // slot declared this way is judged on the slot's word, since the slot is
    // what says which values may arrive there. A name says what the type it
    // stands for says.
    func isConstProcedure(in table: LoweredTypeTable) -> Bool {
        guard case .procedure(_, _, .const, _)? = procedureHeld(in: table) else { return false }

        return true
    }

    func isIsolatedProcedure(in table: LoweredTypeTable) -> Bool {
        guard case .procedure(_, _, _, .isolated)? = procedureHeld(in: table) else { return false }

        return true
    }

    // The positions a procedure a slot holding this holds takes in place.
    // Empty where the slot says nothing of the procedure's parameters.
    func inPlacePositions(in table: LoweredTypeTable) -> Set<Int> {
        guard case let .procedure(parameters?, _, _, _)? = procedureHeld(in: table) else { return [] }

        return Set(parameters.indices.filter { position in parameters[position].isInout })
    }

    // Whether a value this holds may carry a procedure that takes a parameter
    // in place: one written here, or one inside a `?`, an array, a dictionary,
    // a record's field or the type a name declares. A procedure's own
    // parameters and answer are that procedure's business and are not walked.
    func carriesProcedureTakingInPlace(in table: LoweredTypeTable, walked: Set<Int> = []) -> Bool {
        switch self {
        case let .procedure(parameters, _, _, _):
            return parameters?.contains { parameter in parameter.isInout } ?? false

        case let .nullable(inner), let .array(inner), let .dictionary(inner), let .variable(inner), let .inout(inner):
            return inner.carriesProcedureTakingInPlace(in: table, walked: walked)

        case let .record(record):
            return record.fields.contains { field in field.carriesProcedureTakingInPlace(in: table, walked: walked) }

        case let .named(row):
            guard !walked.contains(row) else { return false }

            return table.loweredTypes[row].carriesProcedureTakingInPlace(in: table, walked: walked.union([row]))

        case .any, .never, .null, .bool, .int, .double, .string, .ranged, .parameter, .composition, .projection,
            .undeclared:
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

    // What every one of these readings joins to, and `Any` where there are
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
    // is the type's own fact: a parameter roots a projection at itself, and a
    // projection already rooted extends the path it carries.
    //
    // The marks come off on the way in: what a mark says is expected of the
    // value, and where the walk landed is the same field either way.
    func reaching(_ path: Path) -> LoweredType? {
        switch self {
        case let .parameter(name, _):
            return .projection(of: name, path: path.unmarked)

        case let .projection(of, walked):
            return .projection(of: of, path: walked.appending(contentsOf: path.unmarked.segments))

        default:
            return nil
        }
    }

    // Where a field stands in this type, and what stands there. Nil where
    // the build did not prove a layout: a dictionary, a value that arrived
    // through `Any`, or a type a call still decides. A box is read through,
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

    // What a dot reading this name reaches: an entry, where this is a
    // dictionary, whose names are data, or the field a record type declares
    // under the name, as what the field holds. Nil where a dot reaches
    // nothing the type declares.
    func dotted(_ name: Name, in table: LoweredTypeTable) -> LoweredType? {
        switch self {
        case let .dictionary(entry):
            return entry

        case let .named(row):
            return table.loweredTypes[row].dotted(name, in: table)

        case let .variable(inner), let .inout(inner):
            return inner.dotted(name, in: table)

        default:
            return place(of: name, in: table)?.type.fieldUnwrapped
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

    // A settled value's type with each procedure it holds read by the type
    // the value's expression was judged at in that position (an element, an
    // entry, a field). A procedure value says nothing about its signature, and
    // the expression that made it wrote one; everything else is the value's.
    // The constness and isolation the build derived are facts of the one
    // value judged, so they come along only where the name holding it is
    // `fixed` and keeps that value; a box a write may fill again takes the
    // signature.
    func refined(by judged: LoweredType, fixed: Bool, in table: LoweredTypeTable) -> LoweredType {
        var written = judged.resolved(in: table)

        if case let .nullable(inner) = written {
            written = inner
        }

        switch (self, written) {
        case let (.procedure(nil, nil, .unstated, .unstated), .procedure(parameters, returns, constness, isolation)):
            guard fixed else {
                return .procedure(parameters: parameters, returns: returns, constness: .unstated, isolation: .unstated)
            }

            return .procedure(parameters: parameters, returns: returns, constness: constness, isolation: isolation)

        case let (.array(element), .array(judgedElement)):
            return .array(element.refined(by: judgedElement, fixed: fixed, in: table))

        case let (.dictionary(entry), .dictionary(judgedEntry)):
            return .dictionary(entry.refined(by: judgedEntry, fixed: fixed, in: table))

        case let (.record(record), .record(judgedRecord)):
            return .record(
                LoweredRecord(
                    layout: record.layout,
                    fields: record.named.map { name, field in
                        judgedRecord[name].map { judgedField in
                            field.refined(by: judgedField.fieldUnwrapped, fixed: fixed, in: table)
                        } ?? field
                    }
                )
            )

        default:
            return self
        }
    }

    // Two readings of one slot. Where they disagree the slot holds neither,
    // which is what `Any` says. A join that guessed would be a refusal an
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

        // Two procedures join to a procedure rather than to `Any`, keeping the
        // constness both of them have. Collapsing here would let one body that
        // runs, in a list of them, pass a slot that asked for none, because
        // `Any` is accepted everywhere.
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
        // int with a condition, bytes are `Array<Standard.Byte>`) are read through their
        // normal forms before the join gives up, and two arrays join by their
        // elements so the equation holds inside one.
        let mine = unrefined
        let theirs = other.unrefined

        if case let .array(myElement) = mine, case let .array(theirElement) = theirs {
            return .array(myElement.joined(theirElement))
        }

        return mine == theirs ? mine : .any
    }

    // Two parts held side by side, as one type: joined as two readings join,
    // and part by part where a reading's join gives up, lists by their
    // elements and records of the same fields field by field, inside what
    // may be null too. Records of other fields are `Any`, since a record slot
    // takes either while no one record type holds both.
    func joinedPartByPart(_ part: LoweredType) -> LoweredType {
        switch (self, part) {
        case let (.nullable(mine), _):
            return mine.joinedPartByPart(part).admittingNull

        case let (_, .nullable(theirs)):
            return joinedPartByPart(theirs).admittingNull

        case let (.array(mine), .array(theirs)):
            return .array(mine.joinedPartByPart(theirs))

        case let (.record(mine), .record(theirs)) where mine.layout.fields == theirs.layout.fields:
            return .record(
                LoweredRecord(layout: mine.layout, fields: zip(mine.fields, theirs.fields).map { field, given in field.joinedPartByPart(given) })
            )

        default:
            return joined(part)
        }
    }

    // The type a value read as this is an instance of, under the name a
    // claim writes and `Value.nominal` answers once the value arrives: a
    // declared record by its name, a range as its kind, bytes as the list
    // they are, and a record with no name as the map it is. Nil where the
    // reading names no such type: null, a procedure, and every reading that
    // stands for a type only a value decides.
    func nominal(in table: LoweredTypeTable) -> Name? {
        switch self {
        case .bool:
            return "Bool"

        case .int:
            return "Int"

        case .double:
            return "Double"

        case .string:
            return "String"

        case let .ranged(refinement):
            return refinement.lowered.nominal(in: table)

        case .array:
            return "Array"

        case .dictionary, .record:
            return "Dictionary"

        case let .named(row):
            guard let record = table.recordRows[row] else { return table.loweredTypes[row].nominal(in: table) }

            return table.labels[record]

        case let .variable(inner), let .inout(inner):
            return inner.nominal(in: table)

        case .any, .never, .null, .procedure, .nullable, .parameter, .composition, .projection, .undeclared:
            return nil
        }
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
    // reached a procedure slot through `Any`. A name the table does not answer
    // passes every judge but the second, which reads it as only itself:
    // nothing is knowable about it here, and the value judge refuses it where
    // a value arrives.
    //
    // Whether a value of `other` may stand where this is declared.
    // Structural, and one-directional: `Any` on the left accepts anything
    // because nothing was declared, and `Any` on the right is accepted by
    // anything because nothing is known.
    func accepts(_ other: LoweredType, in table: LoweredTypeTable) -> Bool {
        accepts(other, in: table, assumingPairs: [], asking: .nothing, rigid: false)
    }

    // The same question where `other` is a declaration's own, and no call
    // fills the type parameters it names: each is one type this knows
    // nothing about, so only that same parameter, or a slot its bounds prove
    // it fits by structure, takes it. What a declaration answering for
    // another is held to.
    func accepts(_ other: LoweredType, in table: LoweredTypeTable, rigid: Bool) -> Bool {
        accepts(other, in: table, assumingPairs: [], asking: .nothing, rigid: rigid)
    }

    // The same question, carrying what is already being asked. `assumingPairs`
    // is the pairs met on the way, and met again a pair holds: a named type may
    // reach itself through a type, so comparing one structurally walks back to
    // the comparison it is inside, and a recursive type agrees with itself
    // precisely when assuming it does uncovers no disagreement. The two `named`
    // doors and a composition record a pair. `asking` is the memberships asked
    // of this very reading. A reading taken apart (an element, a field, a
    // procedure's position, what a composition reading stands for) is another
    // reading and starts without them.
    func accepts(
        _ other: LoweredType,
        in table: LoweredTypeTable,
        assumingPairs: [(LoweredType, LoweredType)],
        asking: Asking,
        rigid: Bool
    ) -> Bool {
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
        // What answers `Never` never arrives, so it cannot be the value that
        // disagrees with a declaration. The other way round it fits nowhere.
        case (_, .never):
            return true

        // A slot handed a variable in place is the two sides being one type,
        // not one that fits the other. The body writes through the caller's box
        // and the caller reads back what the body wrote, so a type that merely
        // fits would let the two disagree about what is there. The body writing
        // what its own declaration allows and the caller reading what its own
        // declaration promised.
        case let (.inout(inner), _):
            return inner.identical(to: other.slotUnwrapped, in: table)

        // A type parameter is one type the declaration naming it does not
        // know, so a slot of it takes only that same parameter. A call fills
        // the parameters of what it calls before it asks this. In the other
        // direction a parameter stands for some type, and a value of it is
        // settled where it arrives, unless no call fills it: then only a slot
        // taking it by its structure does, which the branches below answer.
        case let (.parameter(mine, _), .parameter(theirs, _)):
            return mine == theirs

        case (_, .parameter) where !rigid:
            return true

        case let (.parameter, .variable(inner)), let (.parameter, .inout(inner)):
            return accepts(inner, in: table, assumingPairs: assumingPairs, asking: asking, rigid: rigid)

        case (.parameter, .any), (.parameter, .projection), (.parameter, .undeclared):
            return true

        // A parameter bounded by a membership is one of its members, so it
        // takes what every member of such a membership takes.
        case let (.parameter(_, bounds), _):
            return bounds.contains { bound in
                guard case let .membership(row) = bound else { return false }

                return table.constraints[row].allSatisfy { member in
                    member.accepts(other, in: table, assumingPairs: assumingPairs, asking: asking, rigid: rigid)
                }
            }

        // A slot's own wrapping comes off before what stands for it is taken
        // apart, since a name or a composition there is what a contract
        // reads. `var` is a fact about a slot; a nullable slot takes what
        // its declared half takes from what cannot be null, and what can is
        // answered below.
        case let (.variable(inner), _):
            return inner.accepts(other, in: table, assumingPairs: assumingPairs, asking: asking, rigid: rigid)

        // A nullable slot takes null, whatever it declares besides.
        case (.nullable, .null):
            return true

        // A composition takes what each of its bounds takes: a membership what
        // its members admit, a contract what answers it, each asked of the
        // table with the same rigidity, and, where the slot takes null as well,
        // knowing it does. In the other direction a composition stands for some
        // type nothing here lists. A membership already being asked of this
        // reading does not take it; asked again of a part of the reading that
        // is the reading itself through a name, it holds, a recursive type
        // meeting a recursive membership.
        case let (.composition(bounds), _), let (.nullable(.composition(bounds)), _):
            guard !bounds.contains(where: { bound in
                if case let .membership(row) = bound { asking.contains(row) } else { false }
            }) else {
                return false
            }

            guard !assumingPairs.contains(where: { pair in pair.0 == self && pair.1 == other }) else { return true }

            let orNull = if case .nullable = self { true } else { false }

            return bounds.allSatisfy { bound in
                switch bound {
                case let .membership(row):
                    table.admits(
                        constraint: row,
                        reading: other,
                        assumingRows: [],
                        assumingPairs: assumingPairs + [(self, other)],
                        asking: asking,
                        rigid: rigid,
                        orNull: orNull
                    )

                case let .contract(name):
                    table.satisfies(contract: name, reading: other, rigid: rigid, orNull: orNull)
                }
            }

        case let (.nullable(mine), _) where !other.slotUnwrapped.declaresNull(in: table):
            return mine.accepts(other, in: table, assumingPairs: assumingPairs, asking: asking, rigid: rigid)

        // In the other direction a value of a composition is one of every
        // membership's members and nothing says which, so it stands where
        // every member of some membership would. One bounded by contracts
        // alone stands for a type nothing here lists, so nothing is
        // provable and it passes to be judged where it arrives, unless
        // `rigid`, which the last branch answers. The pair is recorded: a
        // membership that comes back to itself through its members adds no
        // member that could disagree, so met again it holds.
        case let (_, .composition(bounds)) where !rigid || bounds.contains(where: { bound in
            if case .membership = bound { true } else { false }
        }):
            let memberships = bounds.compactMap { bound -> Int? in
                guard case let .membership(row) = bound else { return nil }

                return row
            }

            guard !memberships.isEmpty else { return true }
            guard !assumingPairs.contains(where: { pair in pair.0 == self && pair.1 == other }) else { return true }

            let assumed = assumingPairs + [(self, other)]

            return memberships.contains { row in
                table.constraints[row].allSatisfy { member in accepts(member, in: table, assumingPairs: assumed, asking: .nothing, rigid: rigid) }
            }

        case let (_, .variable(inner)), let (_, .inout(inner)):
            return accepts(inner, in: table, assumingPairs: assumingPairs, asking: asking, rigid: rigid)

        case (.any, _), (_, .any), (.projection, _), (_, .projection):
            return true

        case (.never, _):
            return false

        case (.undeclared, _), (_, .undeclared):
            return true

        case let (.named(row), _):
            guard !assumingPairs.contains(where: { pair in pair.0 == self && pair.1 == other }) else { return true }

            return table.loweredTypes[row].accepts(other, in: table, assumingPairs: assumingPairs + [(self, other)], asking: asking, rigid: rigid)

        case let (_, .named(row)):
            guard !assumingPairs.contains(where: { pair in pair.0 == self && pair.1 == other }) else { return true }

            return accepts(table.loweredTypes[row], in: table, assumingPairs: assumingPairs + [(self, other)], asking: asking, rigid: rigid)

        // A nullable slot takes anything nullable whose declared half it
        // takes; null and what cannot be null were taken above. What may be
        // null does not stand where null was never declared.
        case let (.nullable(mine), .nullable(theirs)):
            return mine.accepts(theirs, in: table, assumingPairs: assumingPairs, asking: asking, rigid: rigid)

        case let (.array(mine), .array(theirs)):
            return mine.accepts(theirs, in: table, assumingPairs: assumingPairs, asking: .nothing, rigid: rigid)

        case let (.dictionary(mine), .dictionary(theirs)):
            return mine.accepts(theirs, in: table, assumingPairs: assumingPairs, asking: .nothing, rigid: rigid)

        // A record is a dictionary whose fields happen to be known: a record
        // whose every field is the entry type is such a mapping. Not the
        // other way round, since a `dictionary` promises nothing about which
        // fields exist.
        case let (.dictionary(mine), .record(theirs)):
            return theirs.fields.allSatisfy { field in mine.accepts(field, in: table, assumingPairs: assumingPairs, asking: .nothing, rigid: rigid) }

        // Width: what stands here must declare at least the fields this one
        // names, and may declare more.
        case let (.record(mine), .record(theirs)):
            return mine.named.allSatisfy { name, field in
                theirs[name].map { given in field.accepts(given, in: table, assumingPairs: assumingPairs, asking: .nothing, rigid: rigid) } ?? false
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
                guard taken.takes(parameter, in: table, assumingPairs: assumingPairs, rigid: rigid) else { return false }
            }

            return (wanted ?? .any).accepts(offered ?? .any, in: table, assumingPairs: assumingPairs, asking: .nothing, rigid: rigid)

        // Two ranges are the one meeting where both sides are the text's
        // fact: the kinds under them decide which way a value may widen, and
        // bounds that cannot overlap are provably apart.
        case let (.ranged(mine), .ranged(theirs)):
            return mine.lowered.accepts(theirs.lowered, in: table, assumingPairs: assumingPairs, asking: asking, rigid: rigid)
                && mine.overlaps(theirs)

        // A range against anything else is its kind against that: the bounds
        // speak where a value is settled.
        case let (.ranged(mine), _):
            return mine.lowered.accepts(other, in: table, assumingPairs: assumingPairs, asking: asking, rigid: rigid)

        case let (_, .ranged(theirs)):
            return accepts(theirs.lowered, in: table, assumingPairs: assumingPairs, asking: asking, rigid: rigid)

        // The one conversion the language has, the way that cannot lose
        // anything.
        case (.double, .int):
            return true

        // A parameter no call fills, or a composition bounded by contracts
        // alone where nothing is judged on arrival, which no branch above
        // took by its structure (`Any`, a composition, a nullable or a name
        // around it). Last, because a refusal any earlier would answer for
        // those too.
        case (_, .parameter), (_, .composition):
            return false

        default:
            return self == other
        }
    }

    // Whether a write into a box handed in place, of this type, holds. The
    // caller reads its box as what filled each type parameter here, and a
    // write settles against this type and never against what filled one, so
    // where this writes a parameter only that parameter lands. Around one, a
    // nullable, a list or a dictionary takes what it takes anywhere, a record
    // as a dictionary included, which the write's settling makes one; a type
    // holding one some other way is written only as itself. A type naming
    // none takes what it accepts.
    func takesInPlace(_ written: LoweredType, in table: LoweredTypeTable) -> Bool {
        guard namesParameter else { return accepts(written, in: table) }

        switch (self, written) {
        case (_, .never):
            return true

        case let (.parameter(mine, _), .parameter(theirs, _)):
            return mine == theirs

        case (.parameter, _):
            return false

        case (.nullable, .null):
            return true

        case let (.nullable(mine), .nullable(theirs)),
            let (.array(mine), .array(theirs)),
            let (.dictionary(mine), .dictionary(theirs)):
            return mine.takesInPlace(theirs, in: table)

        // A record whose every field the entry takes is such a dictionary.
        case let (.dictionary(mine), .record(theirs)):
            return theirs.fields.allSatisfy { field in mine.takesInPlace(field, in: table) }

        case let (.nullable(mine), _):
            return mine.takesInPlace(written, in: table)

        // A procedure's positions and answer are written as themselves, and a
        // value saying it is const or isolated fits a slot that does not ask.
        case let (.procedure(parameters, returns, constness, isolation), .procedure(_, _, given, held)):
            guard constness != .const || given == .const, isolation != .isolated || held == .isolated else { return false }

            return LoweredType.procedure(parameters: parameters, returns: returns, constness: given, isolation: held)
                .identical(to: written, in: table)

        default:
            return identical(to: written, in: table)
        }
    }

    // Whether a position taking this may stand where a position handing
    // `handed` is: it accepts what is handed there, and a position taking a
    // place is handed one. A position taking a value may stand where a place
    // is handed, and reads what the place holds. Rigid as `accepts` is.
    func takes(_ handed: LoweredType, in table: LoweredTypeTable, rigid: Bool) -> Bool {
        takes(handed, in: table, assumingPairs: [], rigid: rigid)
    }

    private func takes(
        _ handed: LoweredType,
        in table: LoweredTypeTable,
        assumingPairs: [(LoweredType, LoweredType)],
        rigid: Bool
    ) -> Bool {
        accepts(handed, in: table, assumingPairs: assumingPairs, asking: .nothing, rigid: rigid) && (!isInout || handed.isInout)
    }

    // The same type through every name that stands for no record, at the
    // outermost only: a declared range or kind is what it stands for, and a
    // name for a record stays that record's.
    func throughAliases(in table: LoweredTypeTable) -> LoweredType {
        guard case let .named(row) = self, table.recordRows[row] == nil else { return self }

        return table.loweredTypes[row].throughAliases(in: table)
    }

    // The same type with every row it holds walked through to what that row
    // stands for, in its elements, entries, `?` and fields at every depth. A
    // procedure type stands as it is written, so what a call of one answers
    // keeps the record names its signature wrote.
    //
    // A row is a spelling, and two spellings of one type are one type: a
    // reading of `{ inner: Person }` and a claim of `{ inner: { name: string } }`
    // are the same thing said twice.
    func resolved(in table: LoweredTypeTable) -> LoweredType {
        resolved(in: table, assuming: [])
    }

    // Whether some value read as `reading` could be one of this type, which
    // a cast names. Not `accepts`: two records that name no field in common
    // accept each other in neither direction and are still both satisfied
    // by a value carrying every field. The bias is deliberate: a refusal is
    // earned only where the types provably disagree, and everything else is
    // left to the run.
    func couldBothHold(reading other: LoweredType, in table: LoweredTypeTable) -> Bool {
        couldBothHold(other, in: table, assumingQuestions: [], askingQuestions: [], nameless: false)
    }

    // Whether an `enum` candidate could ever be a spelling of a value of this
    // type. Candidates are written as the scalar spellings arguments are
    // compared under, so a type with no scalar spelling spells none of
    // them, and a number is read by the spelling the boundary reads: `1e0`
    // is a fraction no fraction spells, so no call could ever match it.
    func spells(_ candidate: String, in table: LoweredTypeTable) -> Bool {
        spells(candidate, in: table, asking: .nothing)
    }

    // The same question, carrying the memberships already being asked.
    func spells(_ candidate: String, in table: LoweredTypeTable, asking: Asking) -> Bool {
        switch self {
        case .any, .projection, .string, .undeclared:
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
        // member of each of its memberships could spell. A membership already
        // being asked adds no member.
        case let .parameter(_, bounds), let .composition(bounds):
            return bounds.allSatisfy { bound in
                guard case let .membership(constraint) = bound else { return true }

                return table.someMember(of: constraint, asking: asking) { member, asked in member.spells(candidate, in: table, asking: asked) }
            }

        case let .named(row):
            return table.loweredTypes[row].spells(candidate, in: table, asking: asking)

        // A candidate spells a value, and null is not one an `enum` lists, so
        // a nullable slot's candidates are the declared half's.
        case let .nullable(inner), let .variable(inner), let .inout(inner):
            return inner.spells(candidate, in: table, asking: asking)

        case .null, .never, .array, .dictionary, .record, .procedure:
            return false
        }
    }

    // Whether two types are one type exactly, names resolved. A name that
    // stands for a declared record is that record, and any other name is what
    // it names. Nothing stands for anything else: `Any` is no wildcard here,
    // since standing for anything is what `accepts` reads, and a type
    // parameter is itself, and so is a name the table does not answer.
    func identical(to other: LoweredType, in table: LoweredTypeTable) -> Bool {
        matches(other, in: table, assumingPairs: [])
    }

    private func matches(
        _ other: LoweredType,
        in table: LoweredTypeTable,
        assumingPairs: [(LoweredType, LoweredType)]
    ) -> Bool {
        if assumingPairs.contains(where: { mine, theirs in mine == self && theirs == other }) { return true }

        let walked = assumingPairs + [(self, other)]

        switch (self, other) {
        case (.undeclared, _), (_, .undeclared), (.parameter, _), (_, .parameter):
            return self == other

        // A record under a name is that name, so two names are two types
        // however alike, unless both name one declared record. Every other
        // name is what it names.
        case let (.named(mine), .named(theirs)):
            guard mine != theirs else { return true }

            if let myRecord = table.recordRows[mine], let theirRecord = table.recordRows[theirs] {
                return myRecord == theirRecord
            }

            return table.recordRows[mine] == nil
                && table.recordRows[theirs] == nil
                && table.loweredTypes[mine].matches(table.loweredTypes[theirs], in: table, assumingPairs: walked)

        case let (.named(mine), _):
            return table.recordRows[mine] == nil
                && table.loweredTypes[mine].matches(other, in: table, assumingPairs: walked)

        case let (_, .named(theirs)):
            return table.recordRows[theirs] == nil
                && matches(table.loweredTypes[theirs], in: table, assumingPairs: walked)

        case let (.nullable(mine), .nullable(theirs)),
            let (.array(mine), .array(theirs)),
            let (.dictionary(mine), .dictionary(theirs)),
            let (.variable(mine), .variable(theirs)),
            let (.inout(mine), .inout(theirs)):
            return mine.matches(theirs, in: table, assumingPairs: walked)

        case let (.record(mine), .record(theirs)):
            return mine.layout == theirs.layout
                && zip(mine.fields, theirs.fields).allSatisfy { one, other in
                    one.matches(other, in: table, assumingPairs: walked)
                }

        case let (.procedure(mine, myAnswer, myConstness, myIsolation),
                  .procedure(theirs, theirAnswer, theirConstness, theirIsolation)):
            guard myConstness == theirConstness, myIsolation == theirIsolation else { return false }

            switch (myAnswer, theirAnswer) {
            case (nil, nil):
                break

            case let (myAnswer?, theirAnswer?):
                guard myAnswer.matches(theirAnswer, in: table, assumingPairs: walked) else { return false }

            default:
                return false
            }

            switch (mine, theirs) {
            case (nil, nil):
                return true

            case let (mine?, theirs?):
                return mine.count == theirs.count
                    && zip(mine, theirs).allSatisfy { one, other in
                        one.matches(other, in: table, assumingPairs: walked)
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

    // The judge asked where a value is read and not rewritten: refused the
    // way settling refuses it, and kept as it came. Settling is the one rule
    // for what a type holds, so this is that rule with what it shapes left
    // behind.
    func admitting(_ value: Value, at path: String, in table: LoweredTypeTable) throws {
        _ = try settling(value, at: path, in: table)
    }

    // The judge asked as a question. Settling is the one rule for what a
    // type holds, so whether it holds something is that rule run with its
    // refusal dropped rather than a second rule written beside it. The path
    // is empty because nothing reads the refusal.
    func settles(_ value: Value, in table: LoweredTypeTable) -> Bool {
        (try? settling(value, at: "", in: table)) != nil
    }

    // The reading that holds two readings of one type parameter where one
    // takes the other, walked in step through lists, dictionaries, what may
    // be null and record fields, a record read as a dictionary by each of
    // its fields. Which was read first says nothing. At each position a
    // range meeting its kind or another range gives the kind, and a declared
    // record meeting a nameless record of its fields gives the nameless one,
    // which is the one a value is sure to fit; two records of other fields
    // give a nameless record of the looser one's fields, each merged with
    // the other's; a reading of `Any` makes its position `Any`; a name that
    // stands for no record meets the other reading as what it stands for.
    // Elsewhere it is the one that takes the other. Rigidly, because a
    // parameter read in a body is that body's own and nothing fills it. Nil
    // where neither takes the other.
    func holdingBoth(_ given: LoweredType, in table: LoweredTypeTable) -> LoweredType? {
        guard self != given else { return self }

        let takesGiven = accepts(given, in: table, rigid: true)

        guard takesGiven || given.accepts(self, in: table, rigid: true) else { return nil }

        return merged(with: given, takingGiven: takesGiven, in: table)
    }

    // What the type parameters in this declaration stand for, given what
    // arrived. Walked in step: where the declaration has a parameter, whatever
    // sits opposite it is what the parameter stands for; where both have a
    // type, the walk goes inside. Nothing infers across statements: a call
    // site is one place, and what it hands over is already known there.
    //
    // A parameter reached twice is read once more, and the substitution says
    // how the two readings become one.
    func binding(
        against given: LoweredType,
        into substitution: inout Substitution,
        holding: inout [Substitution.Held],
        in table: LoweredTypeTable,
        assuming: [Int] = []
    ) {
        switch (self, given) {
        // What arrived wears its slot's marks, which say nothing about its
        // value, so they come off before anything is bound or held.
        case let (_, .variable(theirs)), let (_, .inout(theirs)):
            binding(against: theirs, into: &substitution, holding: &holding, in: table, assuming: assuming)

        // A composition has no name to be read under: what arrived is held
        // to its bounds where it arrived, wherever in the slot that was.
        case let (.composition(bounds), _):
            holding.append(Substitution.Held(reading: given, bounds: bounds, orNull: false))

        // A reading that leaves, or an empty list's element, holds no value,
        // so it fills nothing.
        case (.parameter, .never):
            return

        case let (.parameter(name, _), _):
            substitution.read(name, as: given, in: table)

        // The slot's own wrapping comes off before what arrived is walked
        // through, so a name arriving is held to a composition as the name.
        // A nullable slot reads what cannot be null by its declared half, and
        // what can below.
        case let (.variable(mine), _), let (.inout(mine), _):
            mine.binding(against: given, into: &substitution, holding: &holding, in: table, assuming: assuming)

        // A composition or null holds what arrived as it stands, the table
        // answering whether it is null or held to the bounds, a membership
        // member by member.
        case let (.nullable(.composition(slot)), _):
            holding.append(Substitution.Held(reading: given, bounds: slot, orNull: true))

        case let (.nullable(mine), _) where !given.declaresNull(in: table):
            mine.binding(against: given, into: &substitution, holding: &holding, in: table, assuming: assuming)

        // A name on either side is walked through to the type it declares,
        // once, since a type may name itself. Behind a parameter, so that a
        // parameter reads a name as the name and not as what it declares.
        case let (.named(row), _) where !assuming.contains(row):
            table.loweredTypes[row].binding(
                against: given,
                into: &substitution,
                holding: &holding,
                in: table,
                assuming: assuming + [row]
            )

        case let (_, .named(row)) where !assuming.contains(row):
            binding(
                against: table.loweredTypes[row],
                into: &substitution,
                holding: &holding,
                in: table,
                assuming: assuming + [row]
            )

        // A nullable slot takes null whole: it carries no reading and leaves
        // nothing to hold. A nullable arrival reads by its own declared half,
        // and anything else that may be null by the slot's.
        case (.nullable, .null):
            return

        case let (.nullable(mine), .nullable(theirs)):
            mine.binding(against: theirs, into: &substitution, holding: &holding, in: table, assuming: assuming)

        case let (.nullable(mine), _):
            mine.binding(against: given, into: &substitution, holding: &holding, in: table, assuming: assuming)

        case let (.array(mine), .array(theirs)):
            mine.binding(against: theirs, into: &substitution, holding: &holding, in: table, assuming: assuming)

        case let (.dictionary(mine), .dictionary(theirs)):
            mine.binding(against: theirs, into: &substitution, holding: &holding, in: table, assuming: assuming)

        // A record read as a dictionary fills a parameter with each of its
        // fields, as a list literal fills one with each of its elements: what
        // each field reads a parameter as is read on its own, what two fields
        // read it as joins part by part, and that join is read as one more
        // reading of it. Each field's value is held to a composition where it
        // stands.
        case let (.dictionary(mine), .record(theirs)):
            var fields = Substitution()

            for field in theirs.fields {
                var fieldReadings = Substitution()

                mine.binding(against: field, into: &fieldReadings, holding: &holding, in: table, assuming: assuming)
                fields.read(fieldReadings, joining: .partByPart, in: table)
            }

            substitution.read(fields, in: table)

        case let (.record(mine), .record(theirs)):
            for (name, field) in mine.named {
                guard let opposite = theirs[name] else { continue }

                field.binding(against: opposite, into: &substitution, holding: &holding, in: table, assuming: assuming)
            }

        case let (.procedure(.some(mine), myAnswer, _, _), .procedure(.some(theirs), theirAnswer, _, _)):
            for (parameter, against) in zip(mine, theirs) {
                parameter.binding(against: against, into: &substitution, holding: &holding, in: table, assuming: assuming)
            }

            (myAnswer ?? .any).binding(
                against: theirAnswer ?? .any,
                into: &substitution,
                holding: &holding,
                in: table,
                assuming: assuming
            )

        default:
            return
        }
    }

    // The same walk read for the type parameters alone.
    func binding(against given: LoweredType, into substitution: inout Substitution, in table: LoweredTypeTable) {
        var unheld: [Substitution.Held] = []

        binding(against: given, into: &substitution, holding: &unheld, in: table)
    }

    // This type read by its bounded parameters alone: each as the
    // composition of its bounds, and every other position as `Any`. What is
    // handed where it stands at a call has to fit this, and what the call
    // filled the parameters with judges the rest.
    var boundedAlone: LoweredType {
        switch self {
        case let .parameter(_, bounds) where !bounds.isEmpty:
            return .composition(bounds.sorted())

        case let .array(element):
            let bounded = element.boundedAlone

            return bounded == .any ? .any : .array(bounded)

        case let .dictionary(entry):
            let bounded = entry.boundedAlone

            return bounded == .any ? .any : .dictionary(bounded)

        case let .record(record):
            let fields = record.fields.map(\.boundedAlone)

            guard fields.contains(where: { field in field != .any }) else { return .any }

            return .record(LoweredRecord(layout: record.layout, fields: fields))

        case let .nullable(inner):
            let bounded = inner.boundedAlone

            return bounded == .any ? .any : .nullable(bounded)

        case let .variable(inner):
            let bounded = inner.boundedAlone

            return bounded == .any ? .any : .variable(bounded)

        case let .inout(inner):
            let bounded = inner.boundedAlone

            return bounded == .any ? .any : .inout(bounded)

        // A procedure's answer stands where it is held, and is held there. Its
        // parameters are what it is handed and take `Never`, which every
        // parameter takes, so they ask nothing.
        case let .procedure(parameters, returns, _, _):
            let answer = (returns ?? .any).boundedAlone

            guard answer != .any else { return .any }

            return .procedure(
                parameters: parameters?.map { parameter in parameter.isInout ? .inout(.never) : .never },
                returns: answer,
                constness: .unstated,
                isolation: .unstated
            )

        default:
            return .any
        }
    }

    // This type with every parameter replaced by what it was read as. A
    // parameter nothing filled reads `Any`, which is what a declaration says
    // when it says nothing.
    func filling(_ bound: [Name: LoweredType]) -> LoweredType {
        switch self {
        case let .parameter(name, _):
            return bound[name] ?? .any

        // Nothing fills a walk through a parameter. It is named for a path only
        // the body that wrote it can read, and no call site says anything about
        // that. So the caller reads what a declaration saying nothing says.
        case .projection:
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
        couldBeProcedure(in: table, namedAsking: [], asking: .nothing)
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
            .ranged, .projection, .undeclared:
            return self
        }
    }

    // The value judge: what a type accepts, settled to the declared
    // representation, or a refusal saying which part disagreed. The one judge
    // for a value crossing a declaration, at the build and at the run alike.
    //
    // `at` is the path into the value so the message names the field rather
    // than the whole argument.
    func settling(_ value: Value, at path: @autoclosure () -> String, in table: LoweredTypeTable) throws -> Value {
        try settling(value, at: path(), in: table, asking: .nothing)
    }

    // The same judge, carrying the constraints already being asked of this
    // value: a membership test settles the value against each member, and a
    // member that is a membership reaching one of these again asks the same
    // question of the same value, so that member does not take it. A part of
    // the value is another value and starts with none.
    func settling(
        _ value: Value,
        at path: @autoclosure () -> String,
        in table: LoweredTypeTable,
        asking: Asking
    ) throws -> Value {
        switch self {
        case .any, .projection:
            return value

        // Both ask the membership and neither settles: a value stands as what
        // it arrived as, and which member it matched is a question a cast asks.
        case let .parameter(_, bounds), let .composition(bounds):
            return try bounds.reduce(value) { value, bound in
                try standing(value, boundBy: bound, at: path(), in: table, asking: asking)
            }

        default:
            return try judging(value, at: path(), in: table, asking: asking)
        }
    }

    // Whether settling here leaves every value already settled to `settled`
    // as it is, refusing none, read along the cases `settling` takes: yes,
    // no, or nil where the walk cannot tell. Each caller picks what it makes
    // of nil, since leaving out an answer is the careful side for one and
    // keeping it is for another. A pair met again is a type naming itself,
    // and holds.
    func settlesUnchanged(_ settled: LoweredType, in table: LoweredTypeTable) -> Bool? {
        settlesUnchanged(settled, in: table, assumingPairs: [], namesAside: false)
    }

    // Whether a value settled here, settled to `through` and then here
    // again, is the value it was: where `through` changes it at most by the
    // record names this puts back, at whatever depth.
    func settlesBack(through: LoweredType, in table: LoweredTypeTable) -> Bool {
        through.settlesUnchanged(self, in: table, assumingPairs: [], namesAside: true) == true
    }

    // The same walk, where `namesAside` lets a declared record and a record
    // of its fields stand for each other: settling one to the other takes a
    // name off or puts one on, and changes nothing else where each field
    // stays.
    private func settlesUnchanged(
        _ settled: LoweredType,
        in table: LoweredTypeTable,
        assumingPairs: [(LoweredType, LoweredType)],
        namesAside: Bool
    ) -> Bool? {
        if case .any = self { return true }
        if identical(to: settled, in: table) { return true }

        guard !assumingPairs.contains(where: { pair in pair.0 == self && pair.1 == settled }) else { return true }

        let assumed = assumingPairs + [(self, settled)]

        // Yes where every part answers yes, no as soon as one answers no,
        // and nil where none answers no and one cannot tell.
        func each(_ pairs: [(LoweredType, LoweredType)]) -> Bool? {
            var told = true

            for (mine, theirs) in pairs {
                switch mine.settlesUnchanged(theirs, in: table, assumingPairs: assumed, namesAside: namesAside) {
                case false?:
                    return false

                case nil:
                    told = false

                case true?:
                    break
                }
            }

            return told ? true : nil
        }

        switch (self, settled) {
        // What settles nothing leaves every value as it came.
        case (.projection, _):
            return true

        // A name that stands for no record is what it stands for, on either
        // side. Settling to a record's name gives the value that name, which
        // only a value of that record already has, and `identical` asked.
        case let (.named(row), _) where table.recordRows[row] == nil:
            return table.loweredTypes[row].settlesUnchanged(settled, in: table, assumingPairs: assumed, namesAside: namesAside)

        case let (_, .named(row)) where table.recordRows[row] == nil:
            return settlesUnchanged(table.loweredTypes[row], in: table, assumingPairs: assumed, namesAside: namesAside)

        // Null passes a nullable slot as it is; anything else meets what the
        // slot declares.
        case (.nullable, .null):
            return true

        case let (.nullable(mine), .nullable(theirs)):
            return mine.settlesUnchanged(theirs, in: table, assumingPairs: assumed, namesAside: namesAside)

        case let (.nullable(mine), _):
            return mine.settlesUnchanged(settled, in: table, assumingPairs: assumed, namesAside: namesAside)

        // A value held to a range is a value of the kind under it. Which
        // values two ranges hold is not read here.
        case (.ranged, .ranged):
            return nil

        case let (_, .ranged(theirs)):
            return settlesUnchanged(theirs.lowered, in: table, assumingPairs: assumed, namesAside: namesAside)

        case let (.array(mine), .array(theirs)), let (.dictionary(mine), .dictionary(theirs)):
            return mine.settlesUnchanged(theirs, in: table, assumingPairs: assumed, namesAside: namesAside)

        case let (.named, .record(inline)), let (.record(inline), .named):
            guard namesAside,
                  inline.layout.name == nil,
                  let mine = record(in: table),
                  let theirs = settled.record(in: table),
                  mine.layout.fields == theirs.layout.fields
            else { return false }

            return each(Array(zip(mine.fields, theirs.fields)))

        // A record is laid out on the slot's own fields, so one already laid
        // out on the same fields stays as it is where every field does.
        case let (.record(mine), .record(theirs)):
            guard mine.layout == theirs.layout else { return false }

            return each(Array(zip(mine.fields, theirs.fields)))

        // A composition, and a type parameter the run reads by its bounds,
        // settles nothing: a value it takes stands as it came, so it leaves
        // every value of a type it takes whole as it was. A type that proves
        // nothing is not taken whole.
        case let (.composition(bounds), _), let (.parameter(_, bounds), _):
            return !settled.provesNothing && LoweredType.composition(bounds).accepts(settled, in: table, rigid: true)

        // What a membership or a type parameter holds is not read here.
        case (_, .composition), (_, .parameter):
            return nil

        // A closure settled into a procedure slot keeps one more answer
        // unless the slot's answer leaves the one it settled to before as it
        // is; what it takes and how it may run are judged, not changed.
        case let (
            .procedure(myParameters, myAnswer, myConstness, myIsolation),
            .procedure(theirParameters, theirAnswer, theirConstness, theirIsolation)
        ):
            if myConstness == .const, theirConstness != .const { return false }
            if myIsolation == .isolated, theirIsolation != .isolated { return false }

            switch (myParameters, theirParameters) {
            case (nil, nil):
                break

            // A slot taking another number of arguments takes none of these.
            case let (mine?, theirs?) where mine.count != theirs.count:
                return false

            case let (mine?, theirs?):
                guard zip(mine, theirs).allSatisfy({ one, other in one.identical(to: other, in: table) }) else { return nil }

            default:
                return nil
            }

            // A slot that wrote no answer adds none.
            guard let myAnswer else { return true }

            return myAnswer.settlesUnchanged(theirAnswer ?? .any, in: table, assumingPairs: assumed, namesAside: namesAside)

        default:
            return false
        }
    }

    // A value handed to a slot of this type: a null where the type admits
    // one, and otherwise the value settled. `locus` is where a refusal says
    // the value stood, in the caller's terms.
    func checking(_ value: Value, at locus: String, in table: LoweredTypeTable) throws -> Value {
        guard value != .null else {
            guard admitsNull(in: table) else {
                throw ArgumentError("\(locus): expected \(rendered(in: table)), got Null")
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

    // Whether a null that arrives is one of this type's values. `Any` is
    // here and not below: it accepts what it is handed, null included.
    func admitsNull(in table: LoweredTypeTable) -> Bool {
        admitsNull(in: table, asking: .nothing)
    }

    // The same question, carrying the memberships already being asked.
    func admitsNull(in table: LoweredTypeTable, asking: Asking) -> Bool {
        switch self {
        case .any:
            return true

        case let .named(row):
            return table.loweredTypes[row].admitsNull(in: table, asking: asking)

        // A parameter stands for what arrived and does not settle it, so an
        // unbounded one holds a null the way it holds anything; a bounded
        // one, and a composition, hold null only where every bound does.
        case let .parameter(_, bounds), let .composition(bounds):
            return bounds.allSatisfy { bound in bound.admitsNull(in: table, asking: asking) }

        default:
            return declaresNull(in: table, asking: asking)
        }
    }

    // Whether null is one of this type's values rather than an absence: the
    // fact `T?` exists to declare, and the boundary reads it. `Any` is not
    // this: an undeclared type accepts a null that arrives, but it does not
    // spell null as a value.
    func declaresNull(in table: LoweredTypeTable) -> Bool {
        declaresNull(in: table, asking: .nothing)
    }

    // The same question, carrying the memberships already being asked.
    func declaresNull(in table: LoweredTypeTable, asking: Asking) -> Bool {
        switch self {
        case .null, .nullable:
            return true

        case let .named(row):
            return table.loweredTypes[row].declaresNull(in: table, asking: asking)

        // A value of a composition is one of every membership's members, so
        // null is spelled here where every membership has a member spelling
        // it. A membership already being asked adds no member.
        case let .composition(bounds):
            return bounds.allSatisfy { bound in
                guard case let .membership(constraint) = bound else { return false }

                return table.someMember(of: constraint, asking: asking) { member, asked in member.declaresNull(in: table, asking: asked) }
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
    // type's row refuse a constraint's question it never asked.
    func holdsEveryByte(in table: LoweredTypeTable) -> Bool {
        holdsEveryByte(in: table, namedAsking: [], boundAsking: .nothing)
    }

    // The same question, carrying the names and the memberships already
    // being asked.
    func holdsEveryByte(
        in table: LoweredTypeTable,
        namedAsking: [Int],
        boundAsking: Asking
    ) -> Bool {
        switch self {
        case .any, .projection, .int:
            return true

        case let .variable(inner), let .inout(inner), let .nullable(inner):
            return inner.holdsEveryByte(in: table, namedAsking: namedAsking, boundAsking: boundAsking)

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
                    namedAsking: namedAsking,
                    boundAsking: boundAsking
                )
            }

        case let .ranged(refinement):
            return refinement.holdsEveryByte

        case let .named(row):
            guard !namedAsking.contains(row) else { return false }

            return table.loweredTypes[row].holdsEveryByte(
                in: table,
                namedAsking: namedAsking + [row],
                boundAsking: boundAsking
            )

        // `Double` is the one widening the language has, so it changes every
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
            return "Any"

        // Spelled as what it is: the type reached by that path. No document
        // writes this, so the spelling answers to the message alone, and an
        // author reading a refusal about `item.a` sees where it came from.
        case let .projection(of, path):
            return "some \(Path([.key(of)] + path.segments).rendered)"

        case .never:
            return "Never"

        case .null:
            return "Null"

        case .bool:
            return "Bool"

        case .int:
            return "Int"

        case .double:
            return "Double"

        case .string:
            return "String"

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
                "Procedure"
            ]
            .compactMap { part in part }
            .joined(separator: " ")

            guard let parameters else { return spelling }

            let written = parameters.map { parameter in parameter.rendered(in: table) }

            return "\(spelling)<(\(written.joined(separator: ", ")))"
                + " -> \((returns ?? .any).rendered(in: table))>"

        case let .array(element):
            return "Array<\(element.rendered(in: table))>"

        case let .dictionary(entry):
            return "Dictionary<\(entry.rendered(in: table))>"

        case let .record(held):
            return Self.rendered(fields: held.named.map { name, field in (name, field.rendered(in: table)) })

        case let .named(row):
            return table.labels[row].spelling

        case let .undeclared(label, _):
            return label

        case let .nullable(inner):
            return "\(inner.rendered(in: table))?"
        }
    }

    // How a record reads in a message, each field beside how it reads, in
    // the order given.
    static func rendered(fields: [(name: Name, spelled: String)]) -> String {
        "{ " + fields.map { name, spelled in "\(name): \(spelled)" }.joined(separator: ", ") + " }"
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

        case let (.projection(myRoot, myPath), .projection(theirRoot, theirPath)):
            return myRoot == theirRoot && myPath == theirPath

        case let (.undeclared(mine, _), .undeclared(theirs, _)):
            return mine == theirs

        default:
            return false
        }
    }

    // MARK: - Private
    // The join of two readings where one takes the other, `takingGiven`
    // saying which, walked in step. Each position below is asked the same.
    // A reading of `Any` at a position is `Any` there, as it is for the
    // whole parameter: it is the loosest reading there is, and `accepts`
    // cannot order it. A record's field is read without its `var`, which is
    // a fact about the field and not about the value joined.
    private func merged(with given: LoweredType, takingGiven takesGiven: Bool, in table: LoweredTypeTable) -> LoweredType {
        let mine = throughAliases(in: table)
        let theirs = given.throughAliases(in: table)

        guard mine != .any, theirs != .any else { return .any }

        let looser = takesGiven ? self : given

        switch (mine, theirs) {
        // The looser of the two is a range: its kind holds both, whichever
        // kind the other is a range of.
        case let (.ranged(range), _) where takesGiven, let (_, .ranged(range)) where !takesGiven:
            return range.lowered

        case let (.array(element), .array(other)):
            return .array(element.merged(with: other, in: table))

        case let (.dictionary(element), .dictionary(other)):
            return .dictionary(element.merged(with: other, in: table))

        case let (.dictionary(element), other) where other.record(in: table) != nil,
             let (other, .dictionary(element)) where other.record(in: table) != nil:
            let fields = other.record(in: table)?.fields ?? []

            return .dictionary(fields.reduce(element) { merged, field in merged.merged(with: field.fieldUnwrapped, in: table) })

        case let (.nullable(inner), .nullable(other)):
            return .nullable(inner.merged(with: other, in: table))

        case let (.nullable(inner), other) where takesGiven && other != .null:
            return .nullable(inner.merged(with: other, in: table))

        case let (other, .nullable(inner)) where !takesGiven && other != .null:
            return .nullable(other.merged(with: inner, in: table))

        // A record and a nameless one of the same fields: the nameless one,
        // its fields merged.
        case let (mine, .record(nameless)) where mine.record(in: table)?.layout.fields == nameless.layout.fields:
            return .record(LoweredType.nameless(nameless, merging: mine.record(in: table)?.fields ?? [], in: table))

        case let (.record(nameless), theirs) where theirs.record(in: table)?.layout.fields == nameless.layout.fields:
            return .record(LoweredType.nameless(nameless, merging: theirs.record(in: table)?.fields ?? [], in: table))

        // Two records of other fields: the looser names fewer, and what holds
        // both is a nameless record of its fields, each merged with the field
        // of the same name in the other.
        case let (mine, theirs):
            guard
                let myRecord = mine.record(in: table),
                let theirRecord = theirs.record(in: table),
                myRecord.layout.fields != theirRecord.layout.fields
            else {
                return looser
            }

            let (loose, tight) = takesGiven ? (myRecord, theirRecord) : (theirRecord, myRecord)

            return .record(
                LoweredRecord(
                    layout: Layout(name: nil, ordered: loose.layout.fields),
                    fields: loose.named.map { name, field in
                        tight[name].map { other in field.fieldUnwrapped.merged(with: other.fieldUnwrapped, in: table) }
                            ?? field.fieldUnwrapped
                    }
                )
            )
        }
    }

    // A nameless record with each field merged with the one at its place.
    private static func nameless(
        _ record: LoweredRecord,
        merging fields: [LoweredType],
        in table: LoweredTypeTable
    ) -> LoweredRecord {
        LoweredRecord(
            layout: record.layout,
            fields: zip(fields, record.fields).map { field, given in field.fieldUnwrapped.merged(with: given.fieldUnwrapped, in: table) }
        )
    }

    // The same at a position below, asking there which takes the other.
    private func merged(with given: LoweredType, in table: LoweredTypeTable) -> LoweredType {
        guard self != given else { return self }

        return merged(with: given, takingGiven: accepts(given, in: table, rigid: true), in: table)
    }

    // The record this stands for: a nameless one as it is, a declared one
    // as its row lays it out.
    private func record(in table: LoweredTypeTable) -> LoweredRecord? {
        switch self {
        case let .record(record):
            return record

        case let .named(row):
            guard let laid = table.recordRows[row], case let .record(record) = table.loweredTypes[laid] else { return nil }

            return record

        default:
            return nil
        }
    }

    // The procedure type a slot holding this holds, through the names
    // standing for one and the marks a slot writes, and nil where it holds
    // none.
    private func procedureHeld(in table: LoweredTypeTable, walked: Set<Int> = []) -> LoweredType? {
        switch self {
        case .procedure:
            return self

        case let .named(row):
            guard !walked.contains(row) else { return nil }

            return table.loweredTypes[row].procedureHeld(in: table, walked: walked.union([row]))

        case let .variable(inner), let .inout(inner):
            return inner.procedureHeld(in: table, walked: walked)

        default:
            return nil
        }
    }

    // A row already being walked through stands as itself. A type may name
    // itself (`Tree` holding `Array<Tree>` is a declared type) so a walk that
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

    // Names are peeled one layer at a time, with the question each was
    // peeled at remembered, because this walk is the one that recurses: one
    // met there again has come back, and is assumed to hold. The questions a
    // composition was taken apart at sit beside them, and one of those met
    // again, inside a record or not, is a question no member answers. A
    // question is the two types and whether the reading is nameless, which
    // changes what a name in it says.
    //
    // This is what a cast names and `other` is what it reads, and no step
    // swaps the two: a record's name on the reading side is kept further than
    // one on this side, so the sides are not alike. `nameless` says the
    // reading is a value written with no name, at whatever depth: its names
    // say only what structure it has.
    private func couldBothHold(
        _ other: LoweredType,
        in table: LoweredTypeTable,
        assumingQuestions: [(LoweredType, LoweredType, Bool)],
        askingQuestions: [(LoweredType, LoweredType, Bool)],
        nameless: Bool
    ) -> Bool {
        // What a field holds is read without its `var`.
        guard fieldUnwrapped == self, other.fieldUnwrapped == other else {
            return fieldUnwrapped.couldBothHold(other.fieldUnwrapped, in: table, assumingQuestions: assumingQuestions, askingQuestions: askingQuestions, nameless: nameless)
        }

        let question = (self, other, nameless)

        // Two declared records are two types by name, through `?` and the
        // aliases that stand for them, so the one value both could hold is
        // null. A nameless reading wears neither name.
        if !nameless, let myRecord = table.record(of: self), let theirRecord = table.record(of: other), myRecord != theirRecord {
            return declaresNull(in: table) && other.declaresNull(in: table)
        }

        if case let .named(row) = self {
            guard !assumingQuestions.contains(where: { asked in asked == question }) else { return true }

            return table.loweredTypes[row].couldBothHold(other, in: table, assumingQuestions: assumingQuestions + [question], askingQuestions: askingQuestions, nameless: nameless)
        }

        // A value of a composition is one of every membership's members, so
        // a value could be both wherever one member could.
        if case let .composition(bounds) = self {
            guard !askingQuestions.contains(where: { asked in asked == question }) else { return false }

            let asked = askingQuestions + [question]

            return bounds.allSatisfy { bound in
                guard case let .membership(row) = bound else { return true }

                return table.constraints[row].contains { member in
                    member.couldBothHold(other, in: table, assumingQuestions: assumingQuestions, askingQuestions: asked, nameless: nameless)
                }
            }
        }

        // A name that stands for no record is what it stands for, and so is
        // any name in a nameless reading. A record's name on the other side
        // otherwise stays until a structure meets it, since a value of a
        // declared record keeps its name wherever it is settled, and whatever
        // wraps this side meets that name.
        if case let .named(row) = other, nameless || table.recordRows[row] == nil {
            guard !assumingQuestions.contains(where: { asked in asked == question }) else { return true }

            return couldBothHold(table.loweredTypes[row], in: table, assumingQuestions: assumingQuestions + [question], askingQuestions: askingQuestions, nameless: nameless)
        }

        if provesNothing || other.provesNothing { return true }

        // What is read as a membership may be a value written into it
        // nameless, and nothing inside such a value has a name either, so a
        // member is read as a nameless reading, whatever this one was, and
        // that is the question taken apart here.
        if case let .composition(bounds) = other {
            let taken = (self, other, true)

            guard !askingQuestions.contains(where: { asked in asked == taken }) else { return false }

            let asked = askingQuestions + [taken]

            return bounds.allSatisfy { bound in
                guard case let .membership(row) = bound else { return true }

                return table.constraints[row].contains { member in
                    couldBothHold(member, in: table, assumingQuestions: assumingQuestions, askingQuestions: asked, nameless: true)
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
            return mine.lowered.couldBothHold(theirs.lowered, in: table, assumingQuestions: assumingQuestions, askingQuestions: askingQuestions, nameless: nameless)
                && mine.overlaps(theirs)
        }

        // Refinements and compact spellings are dropped first: whether a
        // value could be both is a question about kinds.
        switch (unrefined, other.unrefined) {
        case let (.nullable(inner), theirs):
            return inner.couldBothHold(theirs, in: table, assumingQuestions: assumingQuestions, askingQuestions: askingQuestions, nameless: nameless)

        case let (mine, .nullable(inner)):
            return mine.couldBothHold(inner, in: table, assumingQuestions: assumingQuestions, askingQuestions: askingQuestions, nameless: nameless)

        case let (_, .named(row)):
            guard !assumingQuestions.contains(where: { asked in asked == question }) else { return true }

            return couldBothHold(table.loweredTypes[row], in: table, assumingQuestions: assumingQuestions + [question], askingQuestions: askingQuestions, nameless: nameless)

        // What both name has to be able to hold at once; what only one names
        // is data the other lets ride through.
        case let (.record(mine), .record(theirs)):
            return mine.named.allSatisfy { name, field in
                theirs[name].map { given in field.couldBothHold(given, in: table, assumingQuestions: assumingQuestions, askingQuestions: askingQuestions, nameless: nameless) } ?? true
            }

        // A dictionary and a record are one value at run time read two ways, so
        // every field the record names must be able to be an entry. A list
        // and a map are not asked about their elements: an empty one is of
        // every element type there is.
        case let (.dictionary(entry), .record(held)):
            return held.fields.allSatisfy { field in entry.couldBothHold(field, in: table, assumingQuestions: assumingQuestions, askingQuestions: askingQuestions, nameless: nameless) }

        case let (.record(held), .dictionary(entry)):
            return held.fields.allSatisfy { field in field.couldBothHold(entry, in: table, assumingQuestions: assumingQuestions, askingQuestions: askingQuestions, nameless: nameless) }

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
    // about remembered, since a membership may name itself through a row,
    // and the memberships already being asked beside them.
    private func couldBeProcedure(in table: LoweredTypeTable, namedAsking: [Int], asking: Asking) -> Bool {
        switch self {
        case .procedure, .any, .never, .projection, .undeclared:
            return true

        case let .nullable(inner), let .variable(inner), let .inout(inner):
            return inner.couldBeProcedure(in: table, namedAsking: namedAsking, asking: asking)

        case let .named(row):
            guard !namedAsking.contains(row) else { return false }

            return table.loweredTypes[row].couldBeProcedure(in: table, namedAsking: namedAsking + [row], asking: asking)

        // A value of a type parameter or a composition is one of every
        // bound's members at once. A contract is answered by declared types,
        // and a procedure wears no name to answer one. A membership already
        // being asked adds no member.
        case let .parameter(_, bounds), let .composition(bounds):
            return bounds.allSatisfy { bound in
                switch bound {
                case let .membership(row):
                    return table.someMember(of: row, asking: asking) { member, asked in
                        member.couldBeProcedure(in: table, namedAsking: namedAsking, asking: asked)
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

    // Whether the types a membership admits take every byte between them. A
    // membership met again on the way does not, and the bytes are then settled
    // one by one.
    private func holdsEveryByte(
        of constraint: Int,
        in table: LoweredTypeTable,
        namedAsking: [Int],
        boundAsking: Asking
    ) -> Bool {
        guard !boundAsking.contains(constraint) else { return false }

        let covered = table.someMember(of: constraint, asking: boundAsking) { member, asked in
            member.holdsEveryByte(in: table, namedAsking: namedAsking, boundAsking: asked)
        }

        guard !covered else { return true }

        // No one member covers it, so the complete question is asked with the
        // boundary's own primitive: members that divide the range between them
        // still take every byte.
        return (0 ... 255).allSatisfy { byte in
            table.admits(constraint: constraint, value: .int(byte), asking: .nothing)
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
        asking: Asking
    ) throws -> Value {
        switch self {
        case .any, .projection, .parameter, .composition:
            return try settling(value, at: path(), in: table, asking: asking)

        // A value arrived where nothing was supposed to, so the arrival is the
        // refusal: there is no type to compare it against.
        case .never:
            throw ArgumentError("\(path()): declares Never, and nothing is ever that")

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
            return try settlingNamed(value, row: row, at: path(), in: table, asking: asking)

        // Null arrives as itself; anything else is held to the declared half.
        case let .nullable(inner):
            guard value != .null else { return value }

            return try inner.settling(value, at: path(), in: table, asking: asking)

        case let .array(element):
            // Bytes are an array of bytes in a compact spelling, so they arrive
            // here as the array they are. Where the declaration leaves every
            // byte as it is, the compact spelling crosses whole: the slot
            // asked for an array and one is what it has, and unpacking it would
            // spend an element per byte to answer nothing.
            if case .bytes = value, element.holdsEveryByte(in: table) {
                return value
            }

            // An element nothing was declared for passes as it is, so the
            // array does too: settling each element to itself would copy the
            // array to say nothing.
            if element == .any, case .array = value { return value }

            // Otherwise the slot's spelling wins the way `Double` settles a
            // whole number, and both spellings are read through the one
            // projection that owns the equation.
            guard let items = value.elements else { throw mismatch(value, at: path(), in: table) }

            return .array(
                try items.enumerated().map { index, item in
                    try element.settling(item, at: "\(path())[\(index)]", in: table, asking: .nothing)
                }
            )

        // A dictionary slot holds the names as data, so a record settling
        // here becomes one, its layout's names written beside their values.
        case let .dictionary(entry):
            guard let held = value.asDictionary else { throw mismatch(value, at: path(), in: table) }

            if entry == .any { return .dictionary(held) }

            return .dictionary(
                try held.mapValues { _, item in
                    try entry.settling(item, at: path(), in: table, asking: .nothing)
                }
            )

        // An inline record is structural: a value holding at least these
        // fields fits it, whatever else it holds and whatever it is named.
        // Settling builds the slot's layout, so what settles here holds these
        // fields and no others.
        case let .record(held):
            return try settlingFields(value, of: held, at: path(), in: table, asking: asking)

        // A slot writes `var` or `inout` about itself; what stands in it is a
        // value of the inner type.
        case let .variable(inner), let .inout(inner):
            return try inner.settling(value, at: path(), in: table, asking: asking)

        // A closure carries what the build derived about its text, its constness
        // and its isolation, and a slot that asks for either reads the
        // carried fact. A closure that reached here through `Any` or through
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
    // one still holds its constraint here: what arrived through `Any` was
    // never read at the build, so membership is judged against the types the
    // constraint admits, and the value passes untouched. A parameter stands
    // for what arrived; it does not settle it.
    private func standing(
        _ value: Value,
        boundBy bound: LoweredType.Bound,
        at path: @autoclosure () -> String,
        in table: LoweredTypeTable,
        asking: Asking
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

        guard case let .membership(constraint) = bound else { return value }

        guard !asking.contains(constraint) else {
            throw ArgumentError(
                "\(path()): expected \(rendered(in: table)), which is already being asked of this value"
            )
        }

        guard let reasons = table.refusals(of: value, by: constraint, at: path(), asking: asking) else { return value }

        throw ArgumentError(
            "\(path()): expected \(rendered(in: table)), and nothing"
                + " '\(table.constraintLabels[constraint])' admits takes \(value.type)."
                + " \(reasons.joined(separator: ". "))"
        )
    }

    private func settlingNamed(
        _ value: Value,
        row: Int,
        at path: @autoclosure () -> String,
        in table: LoweredTypeTable,
        asking: Asking
    ) throws -> Value {
        let declared = table.loweredTypes[row]

        guard value.holdsFields, let nominal = table.record(of: self) else {
            return try declared.settling(value, at: path(), in: table, asking: asking)
        }

        let label = table.labels[nominal]

        // A tag already canonical is the same spelling. One that is not
        // is an alias or another record, told apart by the table once.
        if case let .record(record) = value, let tag = record.name, tag != label {
            guard let spelled = table.row(named: tag), table.recordRows[spelled] == nominal else {
                throw ArgumentError("\(path()): is a \(tag), and the slot declares \(label)")
            }
        }

        guard case let .record(settled) = try declared.settling(value, at: path(), in: table, asking: asking) else {
            throw mismatch(value, at: path(), in: table)
        }

        return .record(settled.named(label))
    }

    private func settlingFields(
        _ value: Value,
        of held: LoweredRecord,
        at path: @autoclosure () -> String,
        in table: LoweredTypeTable,
        asking: Asking
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

                    return try field.settling(given, at: "\(path()).\(name)", in: table, asking: .nothing)
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

        // It is read as answering what a call of it settles to last.
        let given = LoweredType.procedure(
            parameters: linked.slots.map(\.type),
            returns: closure.answerTypes.last,
            constness: linked.constness,
            isolation: linked.isolation
        )

        // A type parameter the slot names is filled by what arrived, the way
        // a call fills it at the build. One the procedure's own signature
        // names is one a closure took from the generic body that made it,
        // filled by that body's call, which the run does not know; it is read
        // as what the slot asks there, held to its bounds.
        let slot = LoweredType.procedure(parameters: required, returns: returns, constness: .unstated, isolation: .unstated)
        var asking = Substitution()

        slot.binding(against: given, into: &asking, in: table)

        let asked = slot.filling(asking.readings)
        var taken = Substitution()

        if given.namesParameter {
            given.binding(against: asked, into: &taken, in: table)
        }

        let bounded = given.boundedParameters.allSatisfy { label, bounds in
            taken.everyReading(of: label).allSatisfy { filled in
                LoweredType.composition(bounds).accepts(filled, in: table)
            }
        }

        guard bounded, asked.accepts(taken.readings.isEmpty ? given : given.filling(taken.readings), in: table) else {
            throw ArgumentError(
                "\(path()): expected \(rendered(in: table)), got \(given.rendered(in: table))"
            )
        }

        // A call of it settles to each of its answers in turn, so a slot
        // takes it only where its answer takes every one the value still
        // bears, not only the last.
        if case let .procedure(_, wanted?, _, _) = asked,
           let answer = closure.answersBorne(in: table).first(where: { answer in !wanted.accepts(answer, in: table) }) {
            throw ArgumentError(
                "\(path()): expected \(rendered(in: table)),"
                    + " got a procedure whose answer settles to \(answer.rendered(in: table)) on the way"
            )
        }

        // What the slot wrote for the answer is one more answer every call of
        // it settles to. An answer naming a type parameter is filled by a
        // call, so the closure keeps what it answered before.
        guard let returns, !returns.namesParameter else { return value }

        return .procedure(closure.passing(returns, in: table))
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
