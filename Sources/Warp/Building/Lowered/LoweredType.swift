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
// is the product of an `Expression`, and the document's type reaches it by
// lowering.
indirect enum LoweredType: Sendable, Equatable {
    case any
    case never
    case null
    case bool
    case int
    case double
    case string

    // What a whole number written as a literal reads as: an Int, or the
    // fraction it names where the place it is written into declares a
    // Double. A reading and never a declaration, and an Int as a name holds
    // it.
    case wholeLiteral

    case array(LoweredType)
    case dictionary(key: LoweredType, value: LoweredType)

    case record(LoweredRecord)

    // What a slot asks of a procedure value: the types it is applied with, in
    // position order, and what it must answer. Nil where no signature was
    // declared. Constness and isolation are the slot's requirements.
    case procedure(LoweredProcedureType?, constness: Constness, isolation: Isolation)

    case variable(LoweredType)
    case `inout`(LoweredType)
    case nullable(LoweredType)

    // A declared type, by its row in the table.
    case named(Int)

    // A type parameter the call fills, and the contracts the signature
    // held it to, in name order. The label is the spelling that ties one
    // mention to another.
    case parameter(label: Name, bounds: [Name])

    // A value of whatever type answers every contract here, which no call
    // fills and no other mention shares: what a contract's name, or `A & B`,
    // stands for where a type is written. Apart from a parameter, so that
    // what fills a parameter cannot pass for what holds a value to its
    // bounds.
    case composition([Name])

    // The type a walk reached by taking a path through one a call decides.
    // The root is the type parameter's spelling and the path is what was
    // walked from it, so two walks landing on one field land on one type.
    // Nothing is proven about what it holds, so every judgement answers it the
    // way it answers `Any`; it stands apart for the walk's own naming.
    case projection(of: Name, path: Path)

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

        case .any, .never, .null, .bool, .int, .wholeLiteral, .double, .string,
            .array, .dictionary, .record, .procedure, .inout, .nullable,
            .named, .parameter, .composition, .projection:
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

        case let .array(inner), let .nullable(inner), let .variable(inner), let .inout(inner):
            return inner.namesParameter

        case let .dictionary(key, value):
            return key.namesParameter || value.namesParameter

        case let .record(record):
            return record.fields.contains { field in field.namesParameter }

        case let .procedure(signature, _, _):
            return (signature?.parameters ?? []).contains { parameter in parameter.namesParameter }
                || (signature?.returns?.namesParameter ?? false)

        case .any, .never, .null, .bool, .int, .wholeLiteral, .double, .string, .named, .composition, .projection:
            return false
        }
    }

    // Every type parameter this names, by label, with the bounds it is held
    // to, none for one no bound holds.
    var typeParameters: [Name: [Name]] {
        switch self {
        case let .parameter(label, bounds):
            return [label: bounds]

        case let .array(inner), let .nullable(inner), let .variable(inner), let .inout(inner):
            return inner.typeParameters

        case let .dictionary(key, value):
            return key.typeParameters.merging(value.typeParameters) { first, _ in first }

        case let .record(record):
            return record.fields.reduce(into: [:]) { found, field in found.merge(field.typeParameters) { first, _ in first } }

        case let .procedure(signature, _, _):
            return ((signature?.parameters ?? []) + [signature?.returns].compactMap { $0 }).reduce(into: [:]) { found, part in
                found.merge(part.typeParameters) { first, _ in first }
            }

        case .any, .never, .null, .bool, .int, .wholeLiteral, .double, .string, .named, .composition, .projection:
            return [:]
        }
    }

    // What a slot holds, through the two marks that say how it is held
    // rather than what it is.
    var slotUnwrapped: LoweredType {
        switch self {
        case let .variable(inner), let .inout(inner):
            return inner.slotUnwrapped

        case .any, .never, .null, .bool, .int, .wholeLiteral, .double, .string,
            .array, .dictionary, .record, .procedure, .nullable,
            .named, .parameter, .composition, .projection:
            return self
        }
    }

    // The declared record this stands on, through `?`, `var` and `inout`,
    // which hold no value of their own. Nil for a type that names no row.
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

    // The type a reading widens to where nothing reads it as a literal: a
    // literal whole number is an Int.
    var widened: LoweredType {
        switch self {
        case .wholeLiteral:
            return .int

        default:
            return self
        }
    }

    // Whether what this stands for is decided at the call.
    var decidedAtCall: Bool {
        switch self {
        case .parameter, .projection:
            return true

        default:
            return false
        }
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

    // This reading as a name holds it: a literal whole number, wherever in it
    // one stands, is an Int.
    var asHeld: LoweredType {
        switch self {
        case .wholeLiteral:
            return .int

        case let .array(element):
            return .array(element.asHeld)

        case let .dictionary(key, value):
            return .dictionary(key: key.asHeld, value: value.asHeld)

        case let .nullable(inner):
            return .nullable(inner.asHeld)

        case let .record(record):
            return .record(record.mapFields(\.asHeld))

        case .any, .never, .null, .bool, .int, .double, .string, .procedure, .variable, .inout,
            .named, .parameter, .composition, .projection:
            return self
        }
    }

    // What a box a write may fill again holds where its start reads as this:
    // a literal whole number an Int, wherever in it one stands, and every
    // procedure in it without the constness or isolation the build derived
    // for the one value judged, since a write may put another procedure
    // there.
    var boxed: LoweredType {
        switch self {
        case .wholeLiteral:
            return .int

        case let .array(element):
            return .array(element.boxed)

        case let .dictionary(key, value):
            return .dictionary(key: key.boxed, value: value.boxed)

        case let .nullable(inner):
            return .nullable(inner.boxed)

        case let .record(record):
            return .record(record.mapFields(\.boxed))

        case let .procedure(signature, _, _):
            return .procedure(signature, constness: .unstated, isolation: .unstated)

        case .any, .never, .null, .bool, .int, .double, .string, .variable, .inout,
            .named, .parameter, .composition, .projection:
            return self
        }
    }

    // What a reading that went past a possible absence holds, and what `T?`
    // reads as: `T` or null. Wrapping what already admits null would say the
    // one fact twice, so `Null?` is `Null`.
    var admittingNull: LoweredType {
        switch self {
        case .any, .null, .nullable:
            return self

        default:
            return .nullable(self)
        }
    }

    // Whether a value of this may hold a record, which is all the walk
    // writes or leaves out: what holds none comes back as it is, unwalked.
    var reachesRecord: Bool {
        switch self {
        case .named, .record:
            return true

        case let .array(inner), let .nullable(inner), let .variable(inner), let .inout(inner):
            return inner.reachesRecord

        case let .dictionary(key, value):
            return key.reachesRecord || value.reachesRecord

        default:
            return false
        }
    }

    // One value of every kind a decided type can hold, for asking the judge
    // rather than restating it.
    private static let samples: [Value] = [
        .null, .bool(false), .int(0), .double(0), .string(""),
        .array([]), .dictionary([:]), .bytes([])
    ]

    // Whether a value of any type passes this as it is: nothing declared,
    // a type parameter no bound holds, or a path a call decides. Settling
    // against one says nothing, so what holds it need not be walked.
    var passesEverything: Bool {
        switch self {
        case .any, .projection, .parameter(_, bounds: []):
            return true

        default:
            return false
        }
    }

    // Whether a list or a map here, at whatever depth, holds no element a
    // value could be: what an empty literal reads as, which says nothing of
    // what a box of it will hold.
    var holdsNoElement: Bool {
        switch self {
        case .array(.never), .dictionary(_, .never):
            return true

        case let .array(inner), let .nullable(inner):
            return inner.holdsNoElement

        case let .dictionary(key, value):
            return key.holdsNoElement || value.holdsNoElement

        case let .record(record):
            return record.fields.contains { field in field.holdsNoElement }

        default:
            return false
        }
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

        case let .dictionary(key, value):
            let bounded = (key: key.boundedAlone, value: value.boundedAlone)

            return bounded == (.any, .any) ? .any : .dictionary(key: bounded.key, value: bounded.value)

        case let .record(record):
            let fields = record.fields.map(\.boundedAlone)

            guard fields.contains(where: { field in field != .any }) else { return .any }

            return .record(LoweredRecord(name: record.name, names: record.names, fields: fields))

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
        case let .procedure(signature, _, _):
            guard let signature else { return .any }

            let answer = (signature.returns ?? .any).boundedAlone

            guard answer != .any else { return .any }

            return .procedure(
                LoweredProcedureType(
                    parameters: signature.parameters.map { parameter in parameter.isInout ? .inout(.never) : .never },
                    returns: answer
                ),
                constness: .unstated,
                isolation: .unstated
            )

        default:
            return .any
        }
    }

    // The procedure type a slot holding this holds, through the marks a
    // slot writes, and nil where it holds none.
    private var procedureHeld: LoweredType? {
        switch self {
        case .procedure:
            return self

        case let .variable(inner), let .inout(inner):
            return inner.procedureHeld

        default:
            return nil
        }
    }

    // MARK: - Initializer
    // What a value reads as.
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
            self = .array(.int)

        // A procedure that already exists as a value says nothing about itself
        // that a walk can read.
        case .procedure:
            self = .procedure(nil, constness: .unstated, isolation: .unstated)

        case let .array(elements):
            self = .array(LoweredType(joining: elements.map { element in LoweredType(of: element, in: table) }))

        // A record reads as the record its name declares, an alias's name
        // its record's, and as `Any` under a name this table declares none
        // under, which a door refuses before anything reads it.
        case let .record(record):
            self = table.record(named: record.name).map(LoweredType.named) ?? .any

        // A map reads as what its keys and its values hold, joined.
        case let .dictionary(dictionary):
            self = .dictionary(
                key: LoweredType(joining: dictionary.keys.map { key in LoweredType(of: key, in: table) }),
                value: LoweredType(joining: dictionary.values.map { value in LoweredType(of: value, in: table) })
            )
        }
    }

    // What a value written as a literal reads as: a whole number as one
    // whose place may read it as a fraction, at whatever depth of a list or
    // a record it stands, and anything else as the value it is.
    init(literal value: Value, in table: LoweredTypeTable) {
        switch value {
        case .int:
            self = .wholeLiteral

        case let .array(elements):
            self = .array(LoweredType(joining: elements.map { element in LoweredType(literal: element, in: table) }))

        case let .dictionary(dictionary):
            self = .dictionary(
                key: LoweredType(joining: dictionary.keys.map { key in LoweredType(literal: key, in: table) }),
                value: LoweredType(joining: dictionary.values.map { value in LoweredType(literal: value, in: table) })
            )

        default:
            self = LoweredType(of: value, in: table)
        }
    }

    // What every one of these readings joins to, and `Never` where there
    // are none: an empty list or map holds no element, so it is a value of a
    // list or a map of any type.
    private init(joining readings: [LoweredType]) {
        self = readings.dropFirst().reduce(readings.first ?? .never) { joined, next in joined.joined(next) }
    }

    // MARK: - Public
    // Whether this is a nameless record or a map, through `?` and a field's
    // `var`: a structure no declared record's value is.
    var isNamelessStructure: Bool {
        switch self {
        case .record, .dictionary:
            return true

        case let .nullable(inner), let .variable(inner):
            return inner.isNamelessStructure

        default:
            return false
        }
    }

    // What a slot said about the procedure it holds. A body applying a name a
    // slot declared this way is judged on the slot's word, since the slot is
    // what says which values may arrive there.
    var isConstProcedure: Bool {
        guard case .procedure(_, .const, _)? = procedureHeld else { return false }

        return true
    }

    var isIsolatedProcedure: Bool {
        guard case .procedure(_, _, .isolated)? = procedureHeld else { return false }

        return true
    }

    // The positions a procedure a slot holding this holds takes in place.
    // Empty where the slot says nothing of the procedure's parameters.
    var inPlacePositions: Set<Int> {
        guard case let .procedure(signature?, _, _)? = procedureHeld else { return [] }

        return Set(signature.parameters.indices.filter { position in signature.parameters[position].isInout })
    }

    // Whether a value this holds may carry a procedure that takes a parameter
    // in place: one written here, or one inside a `?`, an array, a dictionary,
    // a record's field or the type a name declares. A procedure's own
    // parameters and answer are that procedure's business and are not walked.
    func carriesProcedureTakingInPlace(in table: LoweredTypeTable, walked: Set<Int> = []) -> Bool {
        switch self {
        case let .procedure(signature, _, _):
            return signature?.parameters.contains { parameter in parameter.isInout } ?? false

        case let .nullable(inner), let .array(inner), let .dictionary(_, inner), let .variable(inner), let .inout(inner):
            return inner.carriesProcedureTakingInPlace(in: table, walked: walked)

        case let .record(record):
            return record.fields.contains { field in field.carriesProcedureTakingInPlace(in: table, walked: walked) }

        case let .named(row):
            guard !walked.contains(row) else { return false }

            return table.loweredTypes[row].carriesProcedureTakingInPlace(in: table, walked: walked.union([row]))

        case .any, .never, .null, .bool, .int, .wholeLiteral, .double, .string, .parameter, .composition, .projection:
            return false
        }
    }

    // What a walk through this type reaches by taking those segments. Nil
    // where this is not a type a call decides, which is where a walk has a
    // type to read the segments against and no need for one of these.
    //
    // A parameter roots a projection at itself, and a projection already
    // rooted extends the path it carries.
    //
    // The marks come off on the way in: what a mark says is expected of the
    // value, and where the walk landed is the same field either way.
    func projecting(along path: Path) -> LoweredType? {
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
            guard let position = held.position(of: field) else { return nil }

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
        case let .dictionary(_, value):
            return value

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
        case let .dictionary(_, value):
            return value

        case let .variable(inner), let .inout(inner):
            return inner.element(in: table)

        default:
            return nil
        }
    }

    // A constant's type: its settled value's, with each procedure it holds
    // read by the type the value's expression was judged at in that position
    // (an element, an entry, a field), the constness and isolation the build
    // derived for that one value included. A procedure value says nothing
    // about its signature, and the expression that made it wrote one;
    // everything else is the value's. Null, and a list or a map showing no
    // element, say nothing the judged type does not, so what holds one is
    // what the expression was judged as, a cast's type among them.
    func refined(by judged: LoweredType) -> LoweredType {
        guard self != .null, !holdsNoElement else { return judged }

        var written = judged

        if case let .nullable(inner) = written {
            written = inner
        }

        switch (self, written) {
        case (.procedure(nil, .unstated, .unstated), .procedure):
            return written

        case let (.array(element), .array(judgedElement)):
            return .array(element.refined(by: judgedElement))

        case let (.dictionary(key, value), .dictionary(judgedKey, judgedValue)):
            return .dictionary(key: key.refined(by: judgedKey), value: value.refined(by: judgedValue))

        case let (.record(record), .record(judgedRecord)):
            return .record(
                LoweredRecord(
                    name: record.name,
                    names: record.names,
                    fields: record.named.map { name, field in
                        judgedRecord[name].map { judgedField in
                            field.refined(by: judgedField.fieldUnwrapped)
                        } ?? field
                    }
                )
            )

        default:
            return self
        }
    }

    // Two readings of one slot, joined part by part: null beside a value is
    // what may be null, two lists join by their elements and two maps by
    // their entries, two records of the same fields field by field, and two
    // procedures to a procedure. Where two parts still disagree the part
    // holds neither, which is what `Any` says. A join that guessed would be a
    // refusal an author cannot act on.
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

        // A literal whole number beside a number is read as that number's
        // kind, the fraction it names beside a Double, and beside anything
        // else it is the Int it is.
        if self == .wholeLiteral || other == .wholeLiteral {
            if self == other { return self }

            let number = self == .wholeLiteral ? other.widened : widened

            return number == .double ? .double : LoweredType.int.joined(number)
        }

        // Two procedures join to a procedure rather than to `Any`, so what
        // joins them still stands where a procedure type is read, keeping the
        // constness both of them have: one body that runs, in a list of them,
        // does not pass a slot that asked for none.
        if
            case let .procedure(mine, wanted, wantedIsolation) = self,
            case let .procedure(theirs, offered, offeredIsolation) = other
        {
            return .procedure(
                mine == theirs ? mine : nil,
                constness: wanted == .const && offered == .const ? .const : .unstated,
                isolation: wantedIsolation == .isolated && offeredIsolation == .isolated ? .isolated : .unstated
            )
        }

        guard self != other else { return self }

        switch (self, other) {
        case let (.array(mine), .array(theirs)):
            return .array(mine.joined(theirs))

        case let (.dictionary(myKey, mine), .dictionary(theirKey, theirs)):
            return .dictionary(key: myKey.joined(theirKey), value: mine.joined(theirs))

        case let (.record(mine), .record(theirs)) where mine.name == theirs.name && mine.names == theirs.names:
            return .record(
                LoweredRecord(name: mine.name, names: mine.names, fields: zip(mine.fields, theirs.fields).map { field, given in field.joined(given) })
            )

        default:
            return .any
        }
    }

    // Two ways that each answer, where they meet. Each way is a place of its
    // own, so a whole literal one of them answers is the Int it is before
    // the two join.
    func meeting(_ way: LoweredType) -> LoweredType {
        asHeld.joined(way.asHeld)
    }

    // The type a value read as this is an instance of, under the name a claim
    // writes and `Value.nominal` answers once the value arrives: a declared
    // record by its name, bytes as the list they are, and a record with no
    // name as the map it is. Nil where the reading names no one type: a type
    // only a value decides, and `Never`.
    func nominal(in table: LoweredTypeTable) -> Name? {
        switch self {
        case .null:
            return TypeSpelling.null

        case .bool:
            return TypeSpelling.bool

        case .int, .wholeLiteral:
            return TypeSpelling.int

        case .double:
            return TypeSpelling.double

        case .string:
            return TypeSpelling.string

        case .array:
            return TypeSpelling.array

        case .dictionary, .record:
            return TypeSpelling.dictionary

        case .procedure:
            return TypeSpelling.procedure

        case let .named(row):
            return table.labels[row]

        case let .variable(inner), let .inout(inner):
            return inner.nominal(in: table)

        case .any, .never, .nullable, .parameter, .composition, .projection:
            return nil
        }
    }

    // A record of these fields, laid out the way the build lays every record
    // out: by the order of the field spellings.
    static func record(_ fields: [Name: LoweredType]) -> LoweredType {
        let ordered = fields.sorted { left, right in left.key < right.key }

        return .record(LoweredRecord(name: nil, names: ordered.map(\.key), fields: ordered.map(\.value)))
    }

    // The reading judges: whether one type may stand where another is
    // declared, whether two types are one type, whether some value could
    // satisfy two types at once. The build asks them of readings; the run
    // asks the first of a closure value a cast reads as a procedure type.
    //
    // Whether a value of `other` may stand where this is declared. Exact on
    // records, a declared one by its name and a nameless one by its fields,
    // and one-directional: `Any` on the left accepts anything
    // because nothing was declared, and a value read as `Any` on the right
    // stands only where `Any` is declared, until a cast says what it is.
    func accepts(_ other: LoweredType, in table: LoweredTypeTable) -> Bool {
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
            return inner == other.slotUnwrapped

        // A type parameter is one type the declaration naming it does not
        // know, so a slot of it takes only that same parameter. A call fills
        // the parameters of what it calls before it asks this. In the other
        // direction a value of one stands only where a slot takes it by its
        // structure, which the branches below answer.
        case let (.parameter(mine, _), .parameter(theirs, _)):
            return mine == theirs

        case let (.parameter, .variable(inner)), let (.parameter, .inout(inner)):
            return accepts(inner, in: table)

        // A slot's own wrapping comes off before what stands for it is taken
        // apart, since a name or a composition there is what a contract
        // reads. `var` is a fact about a slot; a nullable slot takes what
        // its declared half takes from what cannot be null, and what can is
        // answered below.
        case let (.variable(inner), _):
            return inner.accepts(other, in: table)

        // A nullable slot takes null, whatever it declares besides.
        case (.nullable, .null):
            return true

        // A value read as a composition is of a type that answers its
        // contracts and nothing more the build knows of, so it stands where
        // every contract asked is one it answers.
        case let (.composition(bounds), .composition(theirs)),
            let (.nullable(.composition(bounds)), .composition(theirs)):
            return Set(bounds).isSubset(of: theirs)

        // A composition takes what answers each of its contracts, asked of
        // the table knowing, where the slot takes null as well, that it does.
        // A value read as `Any` or along a path a call decides answers none
        // until a cast says what it is, and one leaning on a claim passes,
        // for the link to decide.
        case let (.composition(bounds), _), let (.nullable(.composition(bounds)), _):
            let orNull = if case .nullable = self { true } else { false }

            return bounds.allSatisfy { contract in
                if case .decided(false) = table.answering(contract: contract, reading: other, orNull: orNull) { false } else { true }
            }

        case let (.nullable(mine), _) where !other.slotUnwrapped.declaresNull(in: table):
            return mine.accepts(other, in: table)

        case let (_, .variable(inner)), let (_, .inout(inner)):
            return accepts(inner, in: table)

        case (.any, _), (.projection, _):
            return true

        case (_, .any), (_, .projection), (_, .composition):
            return false

        case (.never, _):
            return false

        // A declared record is nominal: a value of it fits only its own
        // name, whatever the structure, and nothing else is a value of it. A
        // place changes no value, so a record and a nameless one meet only
        // where a literal is written into one, or at a door.
        case (.named, _), (_, .named):
            return self == other

        // A nullable slot takes anything nullable whose declared half it
        // takes; null and what cannot be null were taken above. What may be
        // null does not stand where null was never declared.
        case let (.nullable(mine), .nullable(theirs)):
            return mine.accepts(theirs, in: table)

        case let (.array(mine), .array(theirs)):
            return mine.accepts(theirs, in: table)

        case let (.dictionary(myKey, mine), .dictionary(theirKey, theirs)):
            return myKey.accepts(theirKey, in: table) && mine.accepts(theirs, in: table)

        // A record is a dictionary whose fields happen to be known: a record
        // whose every field is the entry type is such a mapping, its names
        // the text keys. Not the other way round, since a dictionary promises
        // nothing about which fields exist.
        case let (.dictionary(key, mine), .record(theirs)):
            return key.accepts(.string, in: table) && theirs.fields.allSatisfy { field in mine.accepts(field, in: table) }

        // A record type is its fields: what stands here declares exactly
        // these, each taking what stands at it. A place changes no value, so
        // a record of more fields is not one of fewer.
        case let (.record(mine), .record(theirs)):
            return Set(mine.names) == Set(theirs.names)
                && mine.named.allSatisfy { name, field in
                    theirs[name].map { given in field.accepts(given, in: table) } ?? false
                }

        case let (.procedure(required, wantedConstness, wantedIsolation),
                  .procedure(given, offeredConstness, offeredIsolation)):
            // A slot asking for constness takes only what says it is const, and one
            // asking for isolation only what says it is isolated. The two are
            // separate claims: a const body answers without running and can
            // still reach a native procedure that holds state.
            guard wantedConstness != .const || offeredConstness == .const else { return false }
            guard wantedIsolation != .isolated || offeredIsolation == .isolated else { return false }

            // A slot that says nothing of its parameters takes any, and a
            // value that says nothing stands only where nothing is said.
            guard let required else { return true }
            guard let given else { return false }

            // What stands here takes exactly the positions the slot hands: an
            // application gives every position, so a value of another count
            // is refused by every one of them.
            guard given.parameters.count == required.parameters.count else { return false }

            // The directions are opposite on purpose: what is given must
            // accept everything that will be passed to it, and what is
            // required must accept everything it will get back.
            for (parameter, taken) in zip(required.parameters, given.parameters) {
                guard taken.takes(parameter, in: table) else { return false }
            }

            return (required.returns ?? .any).accepts(given.returns ?? .any, in: table)

        // A whole number written as a literal is an Int, or the fraction it
        // names where the place declares a Double.
        case (.int, .wholeLiteral), (.double, .wholeLiteral):
            return true

        // A parameter no call fills, which no branch above took by its
        // structure (`Any`, a composition, a nullable or a name around it).
        // Last, because a refusal any earlier would answer for those too.
        case (_, .parameter):
            return false

        default:
            return self == other
        }
    }

    // Whether a write into a box handed in place, of this type, holds. The
    // caller reads its box as what filled each type parameter here, so where
    // this writes a parameter only that parameter lands. Around one, a
    // nullable, a list or a dictionary takes what it takes anywhere, a record
    // whose every field the entry takes as a dictionary included; a type
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
            let (.array(mine), .array(theirs)):
            return mine.takesInPlace(theirs, in: table)

        case let (.dictionary(myKey, mine), .dictionary(theirKey, theirs)):
            return myKey.takesInPlace(theirKey, in: table) && mine.takesInPlace(theirs, in: table)

        // A record whose every field the entry takes is such a dictionary.
        case let (.dictionary(key, mine), .record(theirs)):
            return key.takesInPlace(.string, in: table)
                && theirs.fields.allSatisfy { field in mine.takesInPlace(field, in: table) }

        case let (.nullable(mine), _):
            return mine.takesInPlace(written, in: table)

        // A procedure's positions and answer are written as themselves, and a
        // value saying it is const or isolated fits a slot that does not ask.
        case let (.procedure(signature, constness, isolation), .procedure(_, given, held)):
            guard constness != .const || given == .const, isolation != .isolated || held == .isolated else { return false }

            return LoweredType.procedure(signature, constness: given, isolation: held) == written

        default:
            return self == written
        }
    }

    // Whether a position taking this may stand where a position handing
    // `handed` is: it accepts what is handed there, and a position taking a
    // place is handed one. A position taking a value may stand where a place
    // is handed, and reads what the place holds.
    func takes(_ handed: LoweredType, in table: LoweredTypeTable) -> Bool {
        accepts(handed, in: table) && (!isInout || handed.isInout)
    }

    // Whether some value read as `reading` could be one of this type, which
    // a cast names. Not `accepts`: two records that name no field in common
    // accept each other in neither direction and are still both satisfied
    // by a value carrying every field. It refuses only where the types
    // provably disagree, and leaves everything else to the run.
    func couldBothHold(reading other: LoweredType, in table: LoweredTypeTable) -> Bool {
        couldBothHold(other, in: table, assumingQuestions: [])
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
    // be null and record fields, a record read as a dictionary by each of its
    // fields. Which was read first says nothing. At each position a reading
    // of `Any` makes its position `Any`. Elsewhere it is the one that takes
    // the other. Nil where neither takes the other.
    func holdingBoth(_ given: LoweredType, in table: LoweredTypeTable) -> LoweredType? {
        guard self != given else { return self }

        let takesGiven = accepts(given, in: table)

        guard takesGiven || given.accepts(self, in: table) else { return nil }

        return merged(with: given, takingGiven: takesGiven, in: table)
    }

    // What the type parameters in this declaration stand for, given what
    // arrived. Walked in step: where the declaration has a parameter, whatever
    // sits opposite it is what the parameter stands for; where both have a
    // type, the walk goes inside. Nothing infers across statements: a call
    // site is one place, and what it hands over is already known there.
    //
    // A parameter reached twice is read once more, and the substitution says
    // how the two readings become one. What a procedure arriving takes at its
    // parameters is read into `taking` instead.
    func binding(
        against given: LoweredType,
        into substitution: inout Substitution,
        taking: inout Substitution,
        holding: inout [Substitution.Held],
        in table: LoweredTypeTable
    ) {
        switch (self, given) {
        // What arrived wears its slot's marks, which say nothing about its
        // value, so they come off before anything is bound or held.
        case let (_, .variable(theirs)), let (_, .inout(theirs)):
            binding(against: theirs, into: &substitution, taking: &taking, holding: &holding, in: table)

        // A composition has no name to be read under: what arrived is held
        // to its bounds where it arrived, wherever in the slot that was.
        case let (.composition(bounds), _):
            holding.append(Substitution.Held(reading: given, bounds: bounds, orNull: false))

        case let (.parameter(name, _), _):
            substitution.read(name, as: given, in: table)

        // The slot's own wrapping comes off before what arrived is walked
        // through, so a name arriving is held to a composition as the name.
        // A nullable slot reads what cannot be null by its declared half, and
        // what can below.
        case let (.variable(mine), _), let (.inout(mine), _):
            mine.binding(against: given, into: &substitution, taking: &taking, holding: &holding, in: table)

        // A composition or null holds what arrived as it stands, the table
        // answering whether it is null or held to the bounds.
        case let (.nullable(.composition(slot)), _):
            holding.append(Substitution.Held(reading: given, bounds: slot, orNull: true))

        case let (.nullable(mine), _) where !given.declaresNull(in: table):
            mine.binding(against: given, into: &substitution, taking: &taking, holding: &holding, in: table)

        // A nullable slot takes null whole: it carries no reading and leaves
        // nothing to hold. A nullable arrival reads by its own declared half,
        // and anything else that may be null by the slot's.
        case (.nullable, .null):
            return

        case let (.nullable(mine), .nullable(theirs)):
            mine.binding(against: theirs, into: &substitution, taking: &taking, holding: &holding, in: table)

        case let (.nullable(mine), _):
            mine.binding(against: given, into: &substitution, taking: &taking, holding: &holding, in: table)

        case let (.array(mine), .array(theirs)):
            mine.binding(against: theirs, into: &substitution, taking: &taking, holding: &holding, in: table)

        case let (.dictionary(myKey, mine), .dictionary(theirKey, theirs)):
            myKey.binding(against: theirKey, into: &substitution, taking: &taking, holding: &holding, in: table)
            mine.binding(against: theirs, into: &substitution, taking: &taking, holding: &holding, in: table)

        // A record read as a dictionary fills a parameter with each of its
        // fields, as a list literal fills one with each of its elements: what
        // each field reads a parameter as is read on its own, what two fields
        // read it as joins part by part, and that join is read as one more
        // reading of it. Each field's value is held to a composition where it
        // stands.
        case let (.dictionary(key, mine), .record(theirs)):
            // One with no field holds no entry, the way an empty map holds
            // none.
            guard !theirs.fields.isEmpty else {
                LoweredType.dictionary(key: key, value: mine)
                    .binding(against: .never, into: &substitution, taking: &taking, holding: &holding, in: table)

                return
            }

            key.binding(against: .string, into: &substitution, taking: &taking, holding: &holding, in: table)

            var fields = Substitution()

            for field in theirs.fields {
                var fieldReadings = Substitution()

                mine.binding(against: field, into: &fieldReadings, taking: &taking, holding: &holding, in: table)
                fields.read(fieldReadings, joining: .joined, in: table)
            }

            substitution.read(fields, in: table)

        case let (.record(mine), .record(theirs)):
            for (name, field) in mine.named {
                guard let opposite = theirs[name] else { continue }

                field.binding(against: opposite, into: &substitution, taking: &taking, holding: &holding, in: table)
            }

        // What a procedure handed here takes is what it accepts, not a value
        // the call hands, so it is read into `taking`: it fills a parameter
        // only where nothing handed does, and the procedure is then judged
        // against what filled it. Two positions taking a parameter fill it
        // with what both take. What it takes is no value standing where a
        // composition is asked, so nothing there is held to one.
        case let (.procedure(mine?, _, _), .procedure(theirs?, _, _)):
            var takenInside = Substitution()
            var accepted: [Substitution.Held] = []

            for (parameter, against) in zip(mine.parameters, theirs.parameters) {
                var taken = Substitution()

                parameter.binding(against: against, into: &taken, taking: &takenInside, holding: &accepted, in: table)
                taking.read(taken, joining: .takenByBoth, in: table)
            }

            taking.read(takenBy: takenInside)

            (mine.returns ?? .any).binding(
                against: theirs.returns ?? .any,
                into: &substitution,
                taking: &taking,
                holding: &holding,
                in: table
            )

        // What arrives as `Never` holds no value at any depth, so every
        // parameter the slot names there is read only by what holds none.
        case (_, .never):
            for name in typeParameters.keys.sorted() {
                substitution.read(name, as: .never, in: table)
            }

        default:
            return
        }
    }

    // This type with every parameter replaced by what it was read as. A
    // parameter nothing filled reads `Any`, which is what a declaration says
    // when it says nothing, one read only by what holds no value reads
    // `Never`, and one read off literal whole numbers alone is filled with
    // the Int they are.
    func filling(_ filled: [Name: LoweredType]) -> LoweredType {
        switch self {
        case let .parameter(name, _):
            return (filled[name] ?? .any).asHeld

        // Nothing fills a walk through a parameter. It is named for a path only
        // the body that wrote it can read, and no call site says anything about
        // that. So the caller reads what a declaration saying nothing says.
        case .projection:
            return .any

        case let .array(element):
            return .array(element.filling(filled))

        case let .dictionary(key, value):
            return .dictionary(key: key.filling(filled), value: value.filling(filled))

        case let .record(fields):
            return .record(fields.mapFields { field in field.filling(filled) })

        case let .procedure(signature, constness, isolation):
            return .procedure(
                signature?.map { part in part.filling(filled) },
                constness: constness,
                isolation: isolation
            )

        case let .variable(inner):
            return .variable(inner.filling(filled))

        case let .inout(inner):
            return .inout(inner.filling(filled))

        case let .nullable(inner):
            return inner.filling(filled).admittingNull

        default:
            return self
        }
    }

    // Whether a value read as this type could be a procedure: the question a
    // call of a value asks before the run. A reading no procedure could stand in
    // is a call every run refuses.
    var couldBeProcedure: Bool {
        switch self {
        // A type parameter or a contract stands for whichever type fills or
        // answers it, `Procedure` among them.
        case .procedure, .any, .never, .parameter, .composition, .projection:
            return true

        case let .nullable(inner), let .variable(inner), let .inout(inner):
            return inner.couldBeProcedure

        case .null, .bool, .int, .wholeLiteral, .double, .string, .array, .dictionary, .record, .named:
            return false
        }
    }

    // Which rows this type stands on. Read by answering every row with
    // itself, so the walk over the tree stays written once.
    func standing(into types: inout Set<Int>) {
        _ = replacingRows { row in
            types.insert(row)

            return .named(row)
        }
    }

    // The same type with every row it stands on answered again, by another
    // row or by the type an alias stands for. A type is a tree and its rows
    // stand at the leaves, so a caller that can answer one row answers the
    // whole of it, and the walk over the tree is written once.
    func replacingRows(by type: (Int) throws -> LoweredType) rethrows -> LoweredType {
        switch self {
        case let .array(element):
            return .array(try element.replacingRows(by: type))

        case let .dictionary(key, value):
            return .dictionary(key: try key.replacingRows(by: type), value: try value.replacingRows(by: type))

        case let .record(held):
            return .record(try held.mapFields { field in try field.replacingRows(by: type) })

        case let .procedure(signature, constness, isolation):
            return .procedure(
                try signature?.map { part in try part.replacingRows(by: type) },
                constness: constness,
                isolation: isolation
            )

        case let .variable(inner):
            return .variable(try inner.replacingRows(by: type))

        case let .inout(inner):
            return .inout(try inner.replacingRows(by: type))

        case let .nullable(inner):
            return try inner.replacingRows(by: type).admittingNull

        case let .named(row):
            return try type(row)

        // Every case that stands on no row, listed rather than let through:
        // a case added here has to say whether it holds one.
        case .any, .never, .null, .bool, .int, .wholeLiteral, .double, .string,
            .parameter, .composition, .projection:
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
        switch self {
        case .any, .projection:
            return value

        // Both ask the contracts and neither settles: a value stands as what
        // it arrived as.
        case let .parameter(_, bounds), let .composition(bounds):
            return try bounds.reduce(value) { value, contract in
                try standing(value, answering: contract, at: path(), in: table)
            }

        // A value arrived where nothing was supposed to, so the arrival is the
        // refusal: there is no type to compare it against.
        case .never:
            throw ArgumentError("\(path()): declares Never, and nothing is ever that")

        // A declared record is nominal. A record arriving under this name is
        // held to the declared fields and keeps it; one under no name or
        // another name is refused, whatever its fields, since a literal, a
        // value from outside and a cast write the name before this reads it.
        case let .named(row):
            return try settlingNamed(value, row: row, at: path(), in: table)

        // Null arrives as itself; anything else is held to the declared half.
        case let .nullable(inner):
            guard value != .null else { return value }

            return try inner.settling(value, at: path(), in: table)

        case let .array(element):
            // Bytes are a list of whole numbers in a compact spelling, so they
            // arrive here as the list they are. Where the declaration leaves
            // every byte as it is, the compact spelling crosses whole: the slot
            // asked for a list and one is what it has.
            if case .bytes = value, element.holdsEveryByte(in: table) {
                return value
            }

            // An element nothing judges passes as it is, so the array does
            // too: settling each element to itself would copy the array to
            // say nothing.
            if element.passesEverything, case .array = value { return value }

            // Otherwise each element is settled against the element type,
            // and both spellings are read through the one projection that
            // owns the equation.
            guard let items = value.elements else { throw mismatch(value, at: path(), in: table) }

            return .array(
                try items.enumerated().map { index, item in
                    try element.settling(item, at: "\(path())[\(index)]", in: table)
                }
            )

        // A map slot judges every key and every value.
        case let .dictionary(key, entry):
            guard case let .dictionary(held) = value else { throw mismatch(value, at: path(), in: table) }

            if key.passesEverything, entry.passesEverything { return .dictionary(held) }

            return .dictionary(
                Value.Dictionary(
                    ordered: try held.entries.map { written in
                        let at = "\(path())[\(Rendering(written.key).text())]"

                        return (
                            key: try key.settling(written.key, at: at, in: table),
                            value: try entry.settling(written.value, at: "\(path()).\(Rendering(written.key).text())", in: table)
                        )
                    }
                )
            )

        // A record's structure as its row lays it out: a record holding
        // exactly these fields fits it, and settling builds on the layout.
        case let .record(held):
            guard case let .record(record) = value else { throw mismatch(value, at: path(), in: table) }

            return .record(try settlingFields(record, of: held, at: path(), in: table))

        // A slot writes `var` or `inout` about itself; what stands in it is a
        // value of the inner type.
        case let .variable(inner), let .inout(inner):
            return try inner.settling(value, at: path(), in: table)

        // A closure carries what the build derived about its text, its constness
        // and its isolation, and a slot that asks for either reads the
        // carried fact. A closure that reached here through a cast or from
        // outside is judged here for the first time.
        case let .procedure(required, constness, isolation):
            return try settlingProcedure(
                value,
                signature: required,
                constness: constness,
                isolation: isolation,
                at: path(),
                in: table
            )

        // The scalars, each by its own kind: an `Int` slot refuses every
        // fraction, `2.0` included, and a `Double` slot every whole number.
        case .null, .bool, .int, .wholeLiteral, .double, .string:
            guard let settled = scalar(value) else { throw mismatch(value, at: path(), in: table) }

            return settled
        }
    }

    // A value from outside fitted to this type before it is held to it: a
    // record's fields its declaration does not name left out, at whatever
    // depth a record, a list, a map or what may be null holds one. Only the
    // doors fit a value to a type.
    func fitted(_ value: Value, in table: LoweredTypeTable) -> Value {
        shaped(value, in: table)
    }

    // The door's first two steps, in its one order: every record a value
    // from outside holds under a name held to the record the name declares,
    // then the value fitted to this type. What the value reads as after
    // these is what a door that is a call fills type parameters from.
    func fitted(
        outside value: Value,
        at path: @autoclosure () -> String,
        in table: LoweredTypeTable
    ) throws -> Value {
        fitted(try table.resolvingNames(in: value, at: path()), in: table)
    }

    // A value from outside at a door that fills no type parameter: fitted,
    // then judged against this type.
    func settling(
        outside value: Value,
        at path: @autoclosure () -> String,
        in table: LoweredTypeTable
    ) throws -> Value {
        try settling(fitted(outside: value, at: path(), in: table), at: path(), in: table)
    }

    // What a cast does, said once. The judgement is `settling`'s; what this
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
                // Recoverable, unlike the same mismatch at a door: a cast is
                // the author expecting a kind of data the build could not
                // type, and being wrong about that is what the world does. An
                // `attempt` catches it.
                throw CastRefused(
                    mismatch.message,
                    expected: rendered(in: table),
                    actual: "\(value.nominal)"
                )
            }

            return .null
        }
    }

    // Whether null is one of this type's values rather than an absence: the
    // fact `T?` exists to declare. `Any` is not this: a type that declares
    // nothing accepts a null that arrives, but it does not spell null as a
    // value.
    func declaresNull(in table: LoweredTypeTable) -> Bool {
        switch self {
        case .null, .nullable:
            return true

        default:
            return false
        }
    }

    // Whether every byte settles into this element declaration as itself,
    // unchanged and with nothing asked of any one of them. This is what lets
    // a compact spelling be judged whole. It says the same thing
    // `settling` says one byte at a time, and a test holds the two together.
    func holdsEveryByte(in table: LoweredTypeTable) -> Bool {
        switch self {
        case .any, .projection, .int, .wholeLiteral:
            return true

        case let .variable(inner), let .inout(inner), let .nullable(inner):
            return inner.holdsEveryByte(in: table)

        // A parameter stands for what arrived and does not settle it. A
        // bounded one asks each value whether its type stands where every
        // contract is asked, and every byte is an `Int`, so one answer is the
        // answer for all of them, a pair the table cannot decide written down
        // as each byte would write it.
        case let .parameter(_, bounds), let .composition(bounds):
            return bounds.allSatisfy { contract in
                table.refusal(
                    of: .int,
                    answering: contract,
                    orNull: false,
                    as: "is",
                    leaning: { claim in table.fulfillment?.require(folded: claim) }
                ) == nil
            }

        // `Double` takes no whole number and so no byte, and neither do the
        // rest. Named rather than left to a default, so that a kind added to
        // the type language has to be answered for here too.
        case .never, .null, .bool, .double, .string,
             .array, .dictionary, .record, .procedure, .named:
            return false
        }
    }

    // How the type reads in a message: the spelling the author wrote, with
    // a row's label standing where the author wrote the name.
    func rendered(in table: LoweredTypeTable) -> String {
        switch self {
        case .any:
            return TypeSpelling.any.spelling

        // Spelled as `TypeExpression` spells it, for the message alone.
        case let .projection(of, path):
            return "\(TypeSpelling.some) \(Path([.key(of)] + path.segments).rendered)"

        case .never:
            return TypeSpelling.never.spelling

        case .null:
            return TypeSpelling.null.spelling

        case .bool:
            return TypeSpelling.bool.spelling

        case .int, .wholeLiteral:
            return TypeSpelling.int.spelling

        case .double:
            return TypeSpelling.double.spelling

        case .string:
            return TypeSpelling.string.spelling

        case let .parameter(label, bounds):
            return bounds.isEmpty
                ? "\(TypeSpelling.some) \(label)"
                : "\(TypeSpelling.some) \(label): \(Self.rendered(bounds))"

        case let .composition(bounds):
            return Self.rendered(bounds)

        case let .variable(inner):
            return "\(TypeSpelling.variable) \(inner.rendered(in: table))"

        case let .inout(inner):
            return "\(TypeSpelling.inout) \(inner.rendered(in: table))"

        case let .procedure(signature, constness, isolation):
            let spelling = [
                constness == .const ? TypeSpelling.const.spelling : nil,
                isolation == .isolated ? TypeSpelling.isolated.spelling : nil,
                TypeSpelling.procedure.spelling
            ]
            .compactMap { part in part }
            .joined(separator: " ")

            guard let signature else { return spelling }

            let written = signature.parameters.map { parameter in parameter.rendered(in: table) }

            return "\(spelling)<(\(written.joined(separator: ", ")))"
                + " -> \((signature.returns ?? .any).rendered(in: table))>"

        case let .array(element):
            return "Array<\(element.rendered(in: table))>"

        case let .dictionary(key, value):
            return "Dictionary<\(key.rendered(in: table)), \(value.rendered(in: table))>"

        // A declared record by its name, and a literal's reading under none
        // by its fields.
        case let .record(held):
            return held.name?.spelling
                ?? Self.rendered(fields: held.named.map { name, field in (name, field.rendered(in: table)) })

        case let .named(row):
            return table.labels[row].spelling

        case let .nullable(inner):
            return "\(inner.rendered(in: table))?"
        }
    }

    // A value written as a literal, as a place of this type holds it: each
    // whole number standing where this declares a Double is the fraction it
    // names, at whatever depth of a list, a map or a record it stands.
    // Everything else is the value as written, and whether it fits is the
    // judge's to say.
    func written(_ value: Value, in table: LoweredTypeTable) -> Value {
        switch (self, value) {
        case let (.double, .int(whole)):
            return .double(Double(whole))

        case let (.named(row), _):
            return table.loweredTypes[row].written(value, in: table)

        case let (.nullable(inner), _), let (.variable(inner), _), let (.inout(inner), _):
            return inner.written(value, in: table)

        case let (.array(element), .array(items)):
            return .array(items.map { item in element.written(item, in: table) })

        case let (.dictionary(key, entry), .dictionary(entries)):
            return .dictionary(
                Value.Dictionary(
                    ordered: entries.entries.map { written in
                        (key: key.written(written.key, in: table), value: entry.written(written.value, in: table))
                    }
                )
            )

        case let (.record(declared), .record(record)):
            return .record(record.mapValues { name, held in
                declared[name].map { field in field.fieldUnwrapped.written(held, in: table) } ?? held
            })

        default:
            return value
        }
    }

    // The same for an expression written into a place of this type: the
    // literals in it, at the depths a list, a record and the answer of a
    // block or an attempt hand on. A record built from parts there takes
    // the name where it is built (`naming`).
    func written(_ expression: Expression, in table: LoweredTypeTable) -> Expression {
        reaching(expression, at: nil, in: table) { place, standing, _ in
            guard case let .literal(value) = standing else { return nil }

            return .literal(place.written(value, in: table))
        }
    }

    // The records an expression written into a place of this type builds
    // where a declared record is read, by the place each is built at, with
    // the name it takes there: the build held each part to its field, so
    // the record is the declared one and the run builds it under the name,
    // with nothing to cast. What builds no record is not walked, so its place
    // is never spelled.
    func naming(_ expression: Expression, at place: @autoclosure () -> Place, in table: LoweredTypeTable) -> [Place: Name] {
        switch expression {
        case .record, .array, .dictionary, .block, .attempt, .loop:
            break

        default:
            return [:]
        }

        var names: [Place: Name] = [:]

        _ = reaching(expression, at: place(), in: table) { type, standing, place in
            if case .record = standing, case .named = type, let nominal = type.row, let place {
                names[place] = table.labels[nominal]
            }

            return nil
        }

        return names
    }

    // The same for a block standing at a place, whose answer stands where
    // this is read.
    func naming(_ block: Block, at place: @autoclosure () -> Place, in table: LoweredTypeTable) -> [Place: Name] {
        block.result.map { result in naming(result, at: place().child(.result), in: table) } ?? [:]
    }

    // What a reading is once what it reads is written where this is
    // declared: a whole literal standing where this declares a Double is the
    // fraction it names, at whatever depth of a list or a record it stands,
    // the way `written` writes the value itself. Every other reading is what
    // it was.
    func written(_ reading: LoweredType, in table: LoweredTypeTable) -> LoweredType {
        switch (self, reading) {
        case (.double, .wholeLiteral):
            return .double

        case let (.named(row), _):
            return table.loweredTypes[row].written(reading, in: table)

        case let (.nullable(inner), _), let (.variable(inner), _), let (.inout(inner), _):
            return inner.written(reading, in: table)

        case let (.array(element), .array(read)):
            return .array(element.written(read, in: table))

        case let (.dictionary(key, entry), .dictionary(readKey, read)):
            return .dictionary(key: key.written(readKey, in: table), value: entry.written(read, in: table))

        case let (.record(declared), .record(read)) where read.name == nil:
            return .record(
                LoweredRecord(
                    name: nil,
                    names: read.names,
                    fields: read.named.map { name, field in
                        declared[name].map { place in place.fieldUnwrapped.written(field, in: table) } ?? field
                    }
                )
            )

        default:
            return reading
        }
    }

    // A block whose answer stands where this is declared.
    func written(_ block: Block, in table: LoweredTypeTable) -> Block {
        Block(body: block.body, result: block.result.map { result in written(result, in: table) })
    }

    // A closure literal written where this is read, its signature completed
    // by the place: one that writes no `returns`, written where a procedure
    // type says what it answers, answers that, so its body is judged against
    // it and a literal it answers is read as the place reads it. It reaches
    // every depth a literal is written at, so where a closure is written does
    // not decide when what it answers is judged. An answer a call fills is no
    // place's to say, and anything else stands as written.
    func completing(_ expression: Expression, in table: LoweredTypeTable) -> Expression {
        reaching(expression, at: nil, in: table) { place, standing, _ in
            guard case let .closure(written) = standing else { return nil }

            guard written.signature.returns == nil, case let .procedure(signature, _, _) = place, let returns = signature?.returns else {
                return standing
            }

            let answer = returns.spelled(in: table)

            guard !answer.isGeneric else { return standing }

            return .closure(written.with(signature: Signature(parameters: written.signature.parameters, returns: answer)))
        }
    }

    // The same for a block whose answer stands where this is read.
    func completing(_ block: Block, in table: LoweredTypeTable) -> Block {
        Block(body: block.body, result: block.result.map { result in completing(result, in: table) })
    }

    // This type as a declaration writes it: lowering run backwards. A
    // declared name goes back to its label, so what it stands for, a mark
    // lowering dropped included, is read again where the spelling is
    // lowered. A whole literal is read as the Int a name holds it as. A type
    // parameter goes back to its name, its bounds being the signature's.
    func spelled(in table: LoweredTypeTable) -> TypeExpression {
        switch self {
        case .any:
            return .any

        case .never:
            return .never

        case .null:
            return .null

        case .bool:
            return .bool

        case .int, .wholeLiteral:
            return .int

        case .double:
            return .double

        case .string:
            return .string

        case let .array(element):
            return .array(element.spelled(in: table))

        case let .dictionary(key, value):
            return .dictionary(key: key.spelled(in: table), value: value.spelled(in: table))

        // A record is written once, where it is declared, and spelled by its
        // name; a literal's reading under no name has no spelling.
        case let .record(record):
            return record.name.map(TypeExpression.named) ?? .any

        case let .procedure(signature, constness, isolation):
            guard let signature else { return .procedure(nil, constness, isolation) }

            return .procedure(
                ProcedureType(
                    parameters: signature.parameters.map { parameter in parameter.spelled(in: table) },
                    returns: signature.returns?.spelled(in: table)
                ),
                constness,
                isolation
            )

        case let .variable(inner):
            return .variable(inner.spelled(in: table))

        case let .inout(inner):
            return .inout(inner.spelled(in: table))

        case let .nullable(inner):
            return .nullable(inner.spelled(in: table))

        case let .named(row):
            return .named(table.labels[row])

        case let .parameter(label, _):
            return .parameter(name: label)

        case let .composition(names):
            return .composition(Set(names))

        case let .projection(of, path):
            return .projection(of: of, path: path)
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
            (.wholeLiteral, .wholeLiteral), (.double, .double), (.string, .string):
            return true

        case let (.array(mine), .array(theirs)),
            let (.variable(mine), .variable(theirs)), let (.inout(mine), .inout(theirs)),
            let (.nullable(mine), .nullable(theirs)):
            return mine == theirs

        case let (.dictionary(myKey, mine), .dictionary(theirKey, theirs)):
            return myKey == theirKey && mine == theirs

        case let (.record(mine), .record(theirs)):
            return mine == theirs

        case let (.procedure(mine, myConstness, myIsolation),
                  .procedure(theirs, theirConstness, theirIsolation)):
            return myConstness == theirConstness
                && myIsolation == theirIsolation
                && mine == theirs

        case let (.named(mine), .named(theirs)):
            return mine == theirs

        case let (.parameter(myLabel, mine), .parameter(theirLabel, theirs)):
            return myLabel == theirLabel && mine == theirs

        case let (.composition(mine), .composition(theirs)):
            return mine == theirs

        case let (.projection(myRoot, myPath), .projection(theirRoot, theirPath)):
            return myRoot == theirRoot && myPath == theirPath

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
        guard self != .any, given != .any else { return .any }

        let looser = takesGiven ? self : given

        switch (self, given) {
        case let (.array(element), .array(other)):
            return .array(element.merged(with: other, in: table))

        case let (.dictionary(key, element), .dictionary(otherKey, other)):
            return .dictionary(key: key.merged(with: otherKey, in: table), value: element.merged(with: other, in: table))

        case let (.dictionary(key, element), other) where other.record(in: table) != nil,
             let (other, .dictionary(key, element)) where other.record(in: table) != nil:
            let fields = other.record(in: table)?.fields ?? []

            return .dictionary(
                key: key.merged(with: .string, in: table),
                value: fields.reduce(element) { merged, field in merged.merged(with: field.fieldUnwrapped, in: table) }
            )

        case let (.nullable(inner), .nullable(other)):
            return .nullable(inner.merged(with: other, in: table))

        case let (.nullable(inner), other) where takesGiven && other != .null:
            return .nullable(inner.merged(with: other, in: table))

        case let (other, .nullable(inner)) where !takesGiven && other != .null:
            return .nullable(other.merged(with: inner, in: table))

        default:
            return looser
        }
    }

    // The same at a position below, asking there which takes the other.
    private func merged(with given: LoweredType, in table: LoweredTypeTable) -> LoweredType {
        guard self != given else { return self }

        return merged(with: given, takingGiven: accepts(given, in: table), in: table)
    }

    // The record this stands for: a nameless one as it is, a declared one
    // as its row lays it out.
    private func record(in table: LoweredTypeTable) -> LoweredRecord? {
        switch self {
        case let .record(record):
            return record

        case let .named(row):
            guard case let .record(record) = table.loweredTypes[row] else { return nil }

            return record

        default:
            return nil
        }
    }

    // A declared record may hold itself, so each question is remembered as
    // it is asked: one met again has come back, and is assumed to hold.
    //
    // This is what a cast names and `other` is what it reads.
    private func couldBothHold(
        _ other: LoweredType,
        in table: LoweredTypeTable,
        assumingQuestions: [(LoweredType, LoweredType)]
    ) -> Bool {
        // What a field holds is read without its `var`.
        guard fieldUnwrapped == self, other.fieldUnwrapped == other else {
            return fieldUnwrapped.couldBothHold(other.fieldUnwrapped, in: table, assumingQuestions: assumingQuestions)
        }

        let question = (self, other)

        // A declared record is its name, through `?`: one record shares its
        // values with itself and with no other. A value read as one is of no
        // nameless record or map either, since nothing takes a name off. The
        // other way a cast writes the name onto a nameless value of the
        // record's fields, so that is asked of the structure below. The one
        // value both of two apart could hold is null.
        let myRecord = self.row
        let theirRecord = other.row

        if let myRecord, let theirRecord {
            return myRecord == theirRecord || (declaresNull(in: table) && other.declaresNull(in: table))
        }

        if theirRecord != nil, isNamelessStructure {
            return declaresNull(in: table) && other.declaresNull(in: table)
        }

        if case let .named(row) = self {
            guard !assumingQuestions.contains(where: { asked in asked == question }) else { return true }

            return table.loweredTypes[row].couldBothHold(other, in: table, assumingQuestions: assumingQuestions + [question])
        }

        if provesNothing || other.provesNothing { return true }

        // Null is a value both hold, so one exists whatever else they say.
        if declaresNull(in: table), other.declaresNull(in: table) { return true }

        // Literals are read as their kind first: whether a value could be
        // both is a question about kinds.
        switch (widened, other.widened) {
        case let (.nullable(inner), theirs):
            return inner.couldBothHold(theirs, in: table, assumingQuestions: assumingQuestions)

        case let (mine, .nullable(inner)):
            return mine.couldBothHold(inner, in: table, assumingQuestions: assumingQuestions)

        case let (_, .named(row)):
            guard !assumingQuestions.contains(where: { asked in asked == question }) else { return true }

            return couldBothHold(table.loweredTypes[row], in: table, assumingQuestions: assumingQuestions + [question])

        // A record type is its fields, so two of other fields share no value,
        // and two of the same fields share one where every field could.
        case let (.record(mine), .record(theirs)):
            return Set(mine.names) == Set(theirs.names)
                && mine.named.allSatisfy { name, field in
                    theirs[name].map { given in field.couldBothHold(given, in: table, assumingQuestions: assumingQuestions) } ?? false
                }

        // A dictionary and a record are one value at run time read two ways, so
        // every field the record names must be able to be an entry. A list
        // and a map are not asked about their elements: an empty one is of
        // every element type there is.
        case let (.dictionary(key, entry), .record(held)):
            return key.couldBothHold(.string, in: table, assumingQuestions: assumingQuestions)
                && held.fields.allSatisfy { field in entry.couldBothHold(field, in: table, assumingQuestions: assumingQuestions) }

        case let (.record(held), .dictionary(key, entry)):
            return LoweredType.string.couldBothHold(key, in: table, assumingQuestions: assumingQuestions)
                && held.fields.allSatisfy { field in field.couldBothHold(entry, in: table, assumingQuestions: assumingQuestions) }

        // Two decided kinds, which is where a value either is both or is
        // neither. Anything else this walk does not read into is the run's.
        case let (mine, theirs):
            guard mine.isDecidedKind, theirs.isDecidedKind else { return true }

            // Asked of the judge that will settle it, not of a second opinion
            // about what it would say. One sample per kind is enough here.
            return LoweredType.samples.contains { sample in
                mine.settles(sample, in: table) && theirs.settles(sample, in: table)
            }
        }
    }

    // The names joined with `&`, as a composition or a bound is spelled.
    private static func rendered(_ bounds: [Name]) -> String {
        bounds.map(\.spelling).joined(separator: " & ")
    }

    // A type parameter the call site filled, or a composition, holding what
    // arrived to a contract by what the value reads as, in the sentence the
    // build refuses such a reading in: what the link found to answer it is
    // what a value may arrive as, and a table that cannot say yet writes the
    // claim down. Neither settles: a value stands as it arrived.
    private func standing(
        _ value: Value,
        answering name: Name,
        at path: @autoclosure () -> String,
        in table: LoweredTypeTable
    ) throws -> Value {
        let refusal = table.refusal(
            of: LoweredType(of: value, in: table),
            answering: name,
            orNull: false,
            as: "is",
            leaning: { claim in table.fulfillment?.require(folded: claim) }
        )

        if let refusal {
            throw ArgumentError("\(path()): \(refusal)")
        }

        return value
    }

    private func settlingNamed(
        _ value: Value,
        row: Int,
        at path: @autoclosure () -> String,
        in table: LoweredTypeTable
    ) throws -> Value {
        let label = table.labels[row]

        guard case let .record(record) = value, case let .record(held) = table.loweredTypes[row] else {
            throw mismatch(value, at: path(), in: table)
        }

        // A record is a value of the record its name declares and of no
        // other, since a door holds an alias's name to its record before
        // anything judges it.
        guard record.name == label else {
            throw ArgumentError("\(path()): is a \(record.name), and the slot declares \(rendered(in: table))")
        }

        return .record(try settlingFields(record, of: held, at: path(), in: table))
    }

    // A record holding exactly the fields of `held`, each settled against its
    // type, built on the record's layout. Whose name it carries is asked
    // before this.
    private func settlingFields(
        _ record: Record,
        of held: LoweredRecord,
        at path: @autoclosure () -> String,
        in table: LoweredTypeTable
    ) throws -> Record {
        guard let layout = held.layout else { throw mismatch(.record(record), at: path(), in: table) }

        // A record laid out as this one is holds exactly its fields, which is
        // what a value of a record type the build judged is.
        if record.names == held.names {
            return Record(
                layout: layout,
                values: try zip(held.named, record.values).map { pair, given in
                    try pair.1.settling(given, at: "\(path()).\(pair.0)", in: table)
                }
            )
        }

        if let field = Set(record.names).subtracting(held.names).min() {
            throw ArgumentError(
                "\(path()).\(field): is not a field of \(rendered(in: table)), and a record holds exactly its fields"
            )
        }

        return Record(
            layout: layout,
            values: try held.named.map { name, field in
                guard let given = record[name] else {
                    throw ArgumentError(
                        "\(path()).\(name): required by \(rendered(in: table)), and nothing was given"
                    )
                }

                return try field.settling(given, at: "\(path()).\(name)", in: table)
            }
        )
    }

    private func settlingProcedure(
        _ value: Value,
        signature required: LoweredProcedureType?,
        constness: Constness,
        isolation: Isolation,
        at path: @autoclosure () -> String,
        in table: LoweredTypeTable
    ) throws -> Value {
        guard case let .procedure(closure) = value else { throw mismatch(value, at: path(), in: table) }

        // Its rows are numbered by the table of the build that made it, and a
        // closure no build answered is refused here, at a door or a cast.
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

        // It is read as answering what its own signature says it answers.
        let given = LoweredType.procedure(
            LoweredProcedureType(parameters: linked.slots.map(\.type), returns: linked.returns),
            constness: linked.constness,
            isolation: linked.isolation
        )

        // A type parameter the procedure's own signature names is one a
        // closure took from the generic body that made it, filled by that
        // body's call, which no value says. A value arriving here gets its
        // type whole, so it is no value of a procedure type that writes a
        // signature. `Procedure` writes none, and every procedure is one.
        guard !given.namesParameter || required == nil else {
            throw ArgumentError(
                "\(path()): expected \(rendered(in: table)), got \(given.rendered(in: table)),"
                    + " whose type parameter only the call that made it fills"
            )
        }

        // A type parameter the slot names is filled by what arrived, the way
        // a call fills it at the build.
        let slot = LoweredType.procedure(required, constness: .unstated, isolation: .unstated)
        let asked = slot.filling(Substitution(filling: [slot], against: [given], in: table).readings)

        guard asked.accepts(given, in: table) else {
            throw ArgumentError(
                "\(path()): expected \(rendered(in: table)), got \(given.rendered(in: table))"
            )
        }

        // A slot takes a procedure as it is, and a call of it hands its
        // answer on as it came.
        return value
    }

    // A scalar of the kind this declares, as it is.
    private func scalar(_ value: Value) -> Value? {
        switch (self, value) {
        case (.null, .null), (.bool, .bool), (.int, .int), (.double, .double), (.string, .string):
            return value

        default:
            return nil
        }
    }

    private func mismatch(_ value: Value, at path: String, in table: LoweredTypeTable) -> ArgumentError {
        ArgumentError("\(path): expected \(rendered(in: table)), got \(value.nominal)")
    }

    // The walk `fitted` takes: a record holding fields its declaration does
    // not name keeps only those it names, at whatever depth a record, a list,
    // a map or what may be null holds one, and keeps its own name.
    private func shaped(_ value: Value, in table: LoweredTypeTable) -> Value {
        switch (self, value) {
        case let (.named(row), _):
            return table.loweredTypes[row].shaped(value, in: table)

        case let (.nullable(inner), _), let (.variable(inner), _), let (.inout(inner), _):
            return inner.shaped(value, in: table)

        case let (.array(element), .array(items)) where element.reachesRecord:
            return .array(items.map { item in element.shaped(item, in: table) })

        case let (.dictionary(key, entry), .dictionary(entries)) where key.reachesRecord || entry.reachesRecord:
            return .dictionary(
                entries.entries.reduce(Value.Dictionary([:])) { shaped, written in
                    shaped.writing(key: key.shaped(written.key, in: table), with: entry.shaped(written.value, in: table))
                }
            )

        case let (.record(declared), .record(record)):
            return .record(
                Record(
                    name: record.name,
                    Dictionary(uniqueKeysWithValues: zip(record.names, record.values).compactMap { name, held in
                        declared[name].map { field in (name, field.fieldUnwrapped.shaped(held, in: table)) }
                    })
                )
            )

        default:
            return value
        }
    }

    // The walk `written`, `completing` and `naming` share: an expression
    // standing where this is read, through what may be null and the names
    // around it, at the depths a list, a record and the answer of a block, an
    // attempt or a loop hand on, each at its place where one is asked for.
    // `replacing` is asked first at each depth, with the type read there, and
    // answers what stands in place of the expression, or nil to walk on.
    private func reaching(
        _ expression: Expression,
        at place: Place?,
        in table: LoweredTypeTable,
        replacing: (LoweredType, Expression, Place?) -> Expression?
    ) -> Expression {
        func answering(_ block: Block, at place: Place?) -> Block {
            Block(
                body: block.body,
                result: block.result.map { result in reaching(result, at: place?.child(.result), in: table, replacing: replacing) }
            )
        }

        // What a block, an attempt or a loop answers stands where this is
        // read, so it is walked with this type as it stands, a name around
        // it included.
        switch expression {
        case let .block(block):
            return .block(answering(block, at: place?.child(.held)))

        case let .attempt(block, rescue):
            return .attempt(answering(block, at: place?.child(.held)), rescue: answering(rescue, at: place?.child(.rescue)))

        case let .loop(condition, body):
            return .loop(while: condition, body: answering(body, at: place?.child(.held)))

        default:
            break
        }

        switch self {
        case let .nullable(inner), let .variable(inner), let .inout(inner):
            return inner.reaching(expression, at: place, in: table, replacing: replacing)

        // A declared record is asked as itself before what it stands for, so
        // what writes a literal there knows the name it is written into.
        case let .named(row):
            if let standing = replacing(self, expression, place) {
                return standing
            }

            return table.loweredTypes[row].reaching(expression, at: place, in: table, replacing: replacing)

        default:
            break
        }

        if let standing = replacing(self, expression, place) {
            return standing
        }

        switch expression {
        case let .array(items):
            guard let element = element(in: table) else { return expression }

            return .array(items.enumerated().map { position, item in
                element.reaching(item, at: place?.child(.element(position)), in: table, replacing: replacing)
            })

        case let .record(fields):
            return .record(
                Dictionary(uniqueKeysWithValues: fields.map { name, field in
                    (name, dotted(name, in: table).map { dotted in
                        dotted.reaching(field, at: place?.child(.field(name)), in: table, replacing: replacing)
                    } ?? field)
                })
            )

        case let .dictionary(entries):
            guard case let .dictionary(key, value) = slotUnwrapped else { return expression }

            return .dictionary(entries.enumerated().map { position, entry in
                (
                    key: key.reaching(entry.key, at: place?.child(.entryKey(position)), in: table, replacing: replacing),
                    value: value.reaching(entry.value, at: place?.child(.entryValue(position)), in: table, replacing: replacing)
                )
            })

        default:
            return expression
        }
    }
}
