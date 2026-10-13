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
indirect enum LoweredType: Sendable, Hashable {
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

    // A declared struct's row: what a mention of it, `named`, stands for.
    case `struct`(LoweredStruct)

    // What a slot asks of a procedure value: the types it is applied with, in
    // position order, and what it must answer. Nil where no signature was
    // declared. Constness and isolation are the slot's requirements.
    case procedure(LoweredProcedureType?, constness: Constness, isolation: Isolation)

    case variable(LoweredType)
    case `inout`(LoweredType)
    case nullable(LoweredType)

    // A declared type, by its row in the table, with the types a struct
    // taking type parameters is applied to, in the order it lists them.
    case named(Int, arguments: [LoweredType] = [])

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
            .array, .dictionary, .struct, .procedure, .inout, .nullable,
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

    // Whether a type parameter stands anywhere in this type. A composition
    // writes none.
    var namesParameter: Bool {
        switch self {
        case .parameter:
            return true

        case let .array(inner), let .nullable(inner), let .variable(inner), let .inout(inner):
            return inner.namesParameter

        case let .dictionary(key, value):
            return key.namesParameter || value.namesParameter

        case let .procedure(signature, _, _):
            return (signature?.parameters ?? []).contains { parameter in parameter.namesParameter }
                || (signature?.returns?.namesParameter ?? false)

        // A mention of a struct names what it is applied to. The struct's
        // own parameters are its declaration's, which a mention fills.
        case let .named(_, arguments):
            return arguments.contains(where: \.namesParameter)

        case .any, .never, .null, .bool, .int, .wholeLiteral, .double, .string, .struct, .composition, .projection:
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

        case let .procedure(signature, _, _):
            return ((signature?.parameters ?? []) + [signature?.returns].compactMap { $0 }).reduce(into: [:]) { found, part in
                found.merge(part.typeParameters) { first, _ in first }
            }

        case let .named(_, arguments):
            return arguments.reduce(into: [:]) { found, argument in
                found.merge(argument.typeParameters) { first, _ in first }
            }

        case .any, .never, .null, .bool, .int, .wholeLiteral, .double, .string, .struct, .composition, .projection:
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
            .array, .dictionary, .struct, .procedure, .nullable,
            .named, .parameter, .composition, .projection:
            return self
        }
    }

    // What a literal written where this is read is written into: the type
    // through `?`, `var` and `inout`, which hold no value of their own.
    var literalPlace: LoweredType {
        switch self {
        case let .nullable(inner), let .variable(inner), let .inout(inner):
            return inner.literalPlace

        default:
            return self
        }
    }

    // The declared struct this stands on, through `?`, `var` and `inout`,
    // which hold no value of their own. Nil for a type that names no row.
    var row: Int? {
        switch self {
        case let .named(row, _):
            return row

        case let .nullable(inner), let .variable(inner), let .inout(inner):
            return inner.row

        default:
            return nil
        }
    }

    // What the declared struct this stands on is applied to, through the
    // same marks. Empty for a type naming no row and for a struct taking
    // no type parameters.
    var arguments: [LoweredType] {
        switch self {
        case let .named(_, arguments):
            return arguments

        case let .nullable(inner), let .variable(inner), let .inout(inner):
            return inner.arguments

        default:
            return []
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
        case .bool, .int, .double, .string, .null, .array, .dictionary:
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

        case let .named(row, arguments):
            return .named(row, arguments: arguments.map(\.asHeld))

        case .any, .never, .null, .bool, .int, .double, .string, .struct, .procedure, .variable, .inout,
            .parameter, .composition, .projection:
            return self
        }
    }

    // What a box a write may fill again holds where its start reads as this:
    // a literal whole number an Int, wherever in it one stands, and every
    // procedure in it without the constness, isolation or failing the build
    // derived for the one value judged, since a write may put another
    // procedure there.
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

        case let .procedure(signature, _, _):
            return .procedure(signature?.with(failing: .unstated), constness: .unstated, isolation: .unstated)

        case let .named(row, arguments):
            return .named(row, arguments: arguments.map(\.boxed))

        case .any, .never, .null, .bool, .int, .double, .string, .struct, .variable, .inout,
            .parameter, .composition, .projection:
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

        case let .named(_, arguments):
            return arguments.contains(where: \.holdsNoElement)

        default:
            return false
        }
    }

    // This type read by its bounded parameters alone: each as the
    // composition of its bounds, and every other position, what a struct is
    // applied to among them, as `Any`. What is
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
                    returns: answer,
                    failing: .unstated
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

        // A struct reads as the struct its name declares, an alias's name
        // its struct's, and as `Any` under a name this table declares none
        // under, which a door refuses before anything reads it.
        // A struct taking type parameters reads as applied to what its
        // fields read them as.
        case let .struct(instance):
            guard let row = table.structRow(named: instance.name) else {
                self = .any

                return
            }

            self = .named(
                row,
                arguments: table.arguments(
                    of: row,
                    joining: Dictionary(uniqueKeysWithValues: zip(instance.names, instance.values.map { field in LoweredType(of: field, in: table) }))
                )
            )

        // A map reads as what its keys and its values hold, joined, and is a
        // map where its keys join to `Any`: a door holds a value to the type
        // it is an instance of. A constant's type is the build's, under
        // `refined(by:)`.
        case let .dictionary(dictionary):
            self = .dictionary(
                key: LoweredType(joining: dictionary.keys.map { key in LoweredType(of: key, in: table) }),
                value: LoweredType(joining: dictionary.values.map { value in LoweredType(of: value, in: table) })
            )
        }
    }

    // What a value written as a literal reads as: a whole number as one
    // whose place may read it as a fraction, at whatever depth of a list or
    // a map it stands, and anything else as the value it is.
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

    // A map keyed by `key` and holding `value`, as the build reads one: a
    // key read as `Any` answers no `Hashable`, so a map of it is no map type
    // and reads `Any` whole.
    init(keyedBy key: LoweredType, holding value: LoweredType) {
        self = key == .any ? .any : .dictionary(key: key, value: value)
    }

    // MARK: - Public
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

    // What a slot said the procedure it holds may fail with: nothing it
    // claims where it writes no signature to say it in.
    var procedureFailing: Failing {
        guard case let .procedure(signature?, _, _)? = procedureHeld else { return .unstated }

        return signature.failing
    }

    // The positions a procedure a slot holding this holds takes in place.
    // Empty where the slot says nothing of the procedure's parameters.
    var inPlacePositions: Set<Int> {
        guard case let .procedure(signature?, _, _)? = procedureHeld else { return [] }

        return Set(signature.parameters.indices.filter { position in signature.parameters[position].isInout })
    }

    // Whether a value this holds may carry a procedure that takes a parameter
    // in place: one written here, or one inside a `?`, an array, a dictionary,
    // a struct's field or the type a name declares. A procedure's own
    // parameters and answer are that procedure's business and are not walked.
    func carriesProcedureTakingInPlace(in table: LoweredTypeTable, walked: Set<Int> = []) -> Bool {
        switch self {
        case let .procedure(signature, _, _):
            return signature?.parameters.contains { parameter in parameter.isInout } ?? false

        case let .nullable(inner), let .array(inner), let .dictionary(_, inner), let .variable(inner), let .inout(inner):
            return inner.carriesProcedureTakingInPlace(in: table, walked: walked)

        case let .struct(structType):
            return structType.fields.contains { field in field.carriesProcedureTakingInPlace(in: table, walked: walked) }

        // What a struct is applied to is held in its fields, and what its
        // declaration writes is walked once.
        case let .named(row, arguments):
            guard !arguments.contains(where: { argument in argument.carriesProcedureTakingInPlace(in: table, walked: walked) }) else {
                return true
            }

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

    // What a dot reading this name reaches: the field a struct type
    // declares under the name, as what the field holds. Nil where a dot
    // reaches nothing the type declares. A box is read through, since a
    // path reads what the box holds.
    func dotted(_ name: Name, in table: LoweredTypeTable) -> LoweredType? {
        switch self {
        case let .struct(held):
            return held[name]?.fieldUnwrapped

        case let .named(row, arguments):
            return table.declared(row, applied: arguments).dotted(name, in: table)

        case let .variable(inner), let .inout(inner):
            return inner.dotted(name, in: table)

        default:
            return nil
        }
    }

    // What an element of this stands as, for a walk taking an index. Nil
    // where the build proved no element type.
    var element: LoweredType? {
        switch self {
        case let .array(element):
            return element

        // Brackets on a map read an entry the way they read a list's
        // element.
        case let .dictionary(_, value):
            return value

        case let .variable(inner), let .inout(inner):
            return inner.element

        default:
            return nil
        }
    }

    // A constant's type: its settled value's, with each procedure it holds
    // read by the type the value's expression was judged at in that position
    // (an element, an entry), the constness, isolation and failing the build
    // derived for that one value included. A struct's fields are its
    // declaration's. A procedure value says nothing about its signature, and
    // the expression that made it wrote one; everything else is the value's. Null, `Any`, and a list or a map
    // showing no element, say nothing the judged type does not, so what
    // holds one is what the expression was judged as, a cast's type among
    // them. A map whose keys the value joins to `Any` is no map type, so it
    // takes the judged key, and where the judged type keys no map it reads
    // as that type, `Any` where nothing is written.
    func refined(by judged: LoweredType) -> LoweredType {
        guard self != .null, self != .any, !holdsNoElement else { return judged }

        var written = judged

        if case let .nullable(inner) = written {
            written = inner
        }

        switch (self, written) {
        case (.procedure(nil, .unstated, .unstated), .procedure):
            return written

        case let (.array(element), .array(judgedElement)):
            return .array(element.refined(by: judgedElement))

        // A value says nothing of what a struct is applied to, and a struct
        // is one type only at the same arguments, so the constant is the
        // struct its expression was judged as.
        case let (.named(row, _), .named(judgedRow, _)) where row == judgedRow:
            return written

        case let (.dictionary(key, value), .dictionary(judgedKey, judgedValue)):
            return LoweredType(keyedBy: key.refined(by: judgedKey), holding: value.refined(by: judgedValue))

        case (.dictionary(.any, _), _):
            return judged

        default:
            return self
        }
    }

    // Two readings of one slot, joined part by part: null beside a value is
    // what may be null, two lists join by their elements and two maps by
    // their keys and their values, and two procedures to a procedure. Where
    // two parts still disagree the part holds neither, which is what `Any`
    // says, and two maps whose keys join to `Any` are no map type, since a
    // key answers `Hashable`, so they read `Any` whole. A join that guessed
    // would be a refusal an author cannot act on.
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
        // constness both of them have and what either may fail with: one body
        // that runs, in a list of them, does not pass a slot that asked for
        // none.
        if
            case let .procedure(mine, wanted, wantedIsolation) = self,
            case let .procedure(theirs, offered, offeredIsolation) = other
        {
            return .procedure(
                mine.flatMap { mine in theirs.flatMap(mine.joined) },
                constness: wanted == .const && offered == .const ? .const : .unstated,
                isolation: wantedIsolation == .isolated && offeredIsolation == .isolated ? .isolated : .unstated
            )
        }

        guard self != other else { return self }

        switch (self, other) {
        case let (.array(mine), .array(theirs)):
            return .array(mine.joined(theirs))

        case let (.dictionary(myKey, mine), .dictionary(theirKey, theirs)):
            return LoweredType(keyedBy: myKey.joined(theirKey), holding: mine.joined(theirs))

        // One struct is one type only at the same arguments, so two readings
        // of it join where each is that one type, a whole literal read as
        // the number beside it.
        case let (.named(row, mine), .named(theirRow, theirs)) where row == theirRow:
            let joined = zip(mine, theirs).map { argument, other in argument.joined(other) }
            let one = LoweredType.named(row, arguments: joined)

            return reads(as: one) && other.reads(as: one) ? one : .any

        default:
            return .any
        }
    }

    // Whether this reading is `declared` itself: what one struct's two
    // mentions have to be to be one type. What the reading says of one value
    // and no declaration writes is read as what is declared: a whole literal
    // as the number it names, `Never`, what holds no value, as any type, and
    // a procedure as its positions and answer, the constness, isolation and
    // failing derived for it meeting what the declaration asks, as a write
    // handed in place is judged.
    func reads(as declared: LoweredType) -> Bool {
        switch (self, declared) {
        case (.wholeLiteral, .int), (.wholeLiteral, .double), (.never, _):
            return true

        case let (.procedure(given, constness, isolation), .procedure(asked, wanted, wantedIsolation)):
            guard wanted != .const || constness == .const, wantedIsolation != .isolated || isolation == .isolated else {
                return false
            }

            guard let asked, let given else { return asked == given }

            return given.failing.fails(within: asked.failing)
                && given.parameters.count == asked.parameters.count
                && zip(given.parameters, asked.parameters).allSatisfy { mine, theirs in mine.reads(as: theirs) }
                && (given.returns ?? .any).reads(as: asked.returns ?? .any)

        case let (.array(mine), .array(theirs)), let (.nullable(mine), .nullable(theirs)):
            return mine.reads(as: theirs)

        case let (.dictionary(myKey, mine), .dictionary(theirKey, theirs)):
            return myKey.reads(as: theirKey) && mine.reads(as: theirs)

        case let (.named(row, mine), .named(theirRow, theirs)):
            return row == theirRow
                && mine.count == theirs.count
                && zip(mine, theirs).allSatisfy { argument, other in argument.reads(as: other) }

        default:
            return self == declared
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
    // struct by its name, and bytes as the list they are. Nil where the
    // reading names no one type: a type only a value decides, and `Never`.
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

        case .dictionary:
            return TypeSpelling.dictionary

        case let .struct(structType):
            return structType.name

        case .procedure:
            return TypeSpelling.procedure

        case let .named(row, _):
            return table.labels[row]

        case let .variable(inner), let .inout(inner):
            return inner.nominal(in: table)

        case .any, .never, .nullable, .parameter, .composition, .projection:
            return nil
        }
    }

    // The reading judges: whether one type may stand where another is
    // declared, whether two types are one type, whether some value could
    // satisfy two types at once. The build asks them of readings; the run
    // asks the first of a closure value a cast reads as a procedure type.
    //
    // Whether a value of `other` may stand where this is declared. Exact on
    // structs, by their names, and one-directional: `Any` on the left accepts anything
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

        // A declared struct is nominal: a value of it fits only its own
        // name, whatever the structure, and nothing else is a value of it.
        // Applied to types, it is one type only where it is applied to the
        // same ones.
        case (.named, _), (_, .named):
            return other.reads(as: self)

        // A nullable slot takes anything nullable whose declared half it
        // takes; null and what cannot be null were taken above. What may be
        // null does not stand where null was never declared.
        case let (.nullable(mine), .nullable(theirs)):
            return mine.accepts(theirs, in: table)

        case let (.array(mine), .array(theirs)):
            return mine.accepts(theirs, in: table)

        case let (.dictionary(myKey, mine), .dictionary(theirKey, theirs)):
            return myKey.accepts(theirKey, in: table) && mine.accepts(theirs, in: table)

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

            // A slot naming what may fail takes only what fails within it, the
            // way constness and isolation are asked.
            guard given.failing.fails(within: required.failing) else { return false }

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
    // nullable, a list or a dictionary takes what it takes anywhere; a type
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

        case (.named, .named):
            return written.reads(as: self)

        case let (.nullable(mine), _):
            return mine.takesInPlace(written, in: table)

        // A procedure's positions and answer are written as themselves, and a
        // value saying it is const or isolated, or failing within what is
        // named, fits a slot that does not ask that much.
        case let (.procedure(signature, constness, isolation), .procedure(offered, given, held)):
            guard constness != .const || given == .const, isolation != .isolated || held == .isolated else { return false }

            guard let signature, let offered else { return signature == offered }

            return offered.failing.fails(within: signature.failing) && offered.with(failing: signature.failing) == signature

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
    // a cast names. Not `accepts`: a list of `Int` and a list of `String`
    // accept each other in neither direction and are still both satisfied
    // by the empty list. It refuses only where the types provably disagree,
    // and leaves everything else to the run.
    func couldBothHold(reading other: LoweredType, in table: LoweredTypeTable) -> Bool {
        // What a field holds is read without its `var`.
        guard fieldUnwrapped == self, other.fieldUnwrapped == other else {
            return fieldUnwrapped.couldBothHold(reading: other.fieldUnwrapped, in: table)
        }

        if provesNothing || other.provesNothing { return true }

        // Null is a value both hold, so one exists whatever else they say.
        if declaresNull(in: table), other.declaresNull(in: table) { return true }

        // Literals are read as their kind first: whether a value could be
        // both is a question about kinds.
        switch (widened, other.widened) {
        case let (.nullable(inner), theirs):
            return inner.couldBothHold(reading: theirs, in: table)

        case let (mine, .nullable(inner)):
            return mine.couldBothHold(reading: inner, in: table)

        // A declared struct is its name: one struct shares its values with
        // itself and with no other, and a value of a decided kind is none
        // of them.
        case let (.named(row, mine), .named(theirRow, theirs)):
            return row == theirRow
                && zip(mine, theirs).allSatisfy { argument, other in argument.couldBothHold(reading: other, in: table) }

        case let (.named, other), let (other, .named):
            return !other.isDecidedKind

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

    // The judge asked as a question. Settling is the one rule for what a
    // type holds, so whether it holds something is that rule run with its
    // refusal dropped rather than a second rule written beside it. The path
    // is empty because nothing reads the refusal.
    func settles(_ value: Value, in table: LoweredTypeTable) -> Bool {
        (try? settling(value, at: "", in: table)) != nil
    }

    // The reading that holds two readings of one type parameter where one
    // takes the other, walked in step through lists, dictionaries and what
    // may be null. Which was read first says nothing. At each position a reading
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

        // One struct is walked into by what it is applied to, as a list by
        // its element.
        case let (.named(row, mine), .named(theirRow, theirs)) where row == theirRow:
            for (argument, other) in zip(mine, theirs) {
                argument.binding(against: other, into: &substitution, taking: &taking, holding: &holding, in: table)
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
            return LoweredType(keyedBy: key.filling(filled), holding: value.filling(filled))

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

        case let .named(row, arguments):
            return .named(row, arguments: arguments.map { argument in argument.filling(filled) })

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

        case .null, .bool, .int, .wholeLiteral, .double, .string, .array, .dictionary, .struct, .named:
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

        case let .struct(held):
            return .struct(try held.mapFields { field in try field.replacingRows(by: type) })

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

        // A struct's arguments are answered too, and stand on what the row
        // is answered by: a row's own mention, or an alias, which takes no
        // arguments of its own and may stand for a struct applied to some.
        case let .named(row, arguments):
            return try type(row).applied(to: try arguments.map { argument in try argument.replacingRows(by: type) })

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

        // A mention naming no arguments, what a value from outside is
        // settled by once its door applied it, reads them off the value.
        case let .named(row, arguments):
            let applied = arguments.isEmpty ? LoweredType(of: value, in: table).arguments : arguments

            return try table.declared(row, applied: applied).settling(value, at: path(), in: table)

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
                        let at = "\(path())\(Path([.index(written.key)]).rendered)"

                        return (
                            key: try key.settling(written.key, at: at, in: table),
                            value: try entry.settling(written.value, at: at, in: table)
                        )
                    }
                )
            )

        // A declared struct is nominal. A struct under its name is held to
        // the declared fields and built on the struct's layout; one under
        // another name is refused, whatever its fields, since a door holds
        // an alias's name to its struct before anything judges it.
        case let .struct(held):
            guard case let .struct(instance) = value else { throw mismatch(value, at: path(), in: table) }

            guard instance.name == held.name else {
                throw ArgumentError("\(path()): is a \(instance.name), and the slot declares \(held.name)")
            }

            return .struct(try settlingFields(instance, of: held, at: path(), in: table))

        // A slot writes `var` or `inout` about itself; what stands in it is a
        // value of the inner type.
        case let .variable(inner), let .inout(inner):
            return try inner.settling(value, at: path(), in: table)

        // A closure carries what the build derived about its text, its
        // constness, its isolation and what it may fail with, and a slot that
        // asks for any of them reads the carried fact. A closure that reached
        // here through a cast or from outside is judged here for the first
        // time.
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

    // A value from outside at a door that fills no type parameter: every
    // struct it holds held to the struct its name declares, then the value
    // judged against this type.
    func settling(
        outside value: Value,
        at path: @autoclosure () -> String,
        in table: LoweredTypeTable
    ) throws -> Value {
        try settling(try table.resolvingNames(in: value, under: self, at: path()), at: path(), in: table)
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
                throw CastRefused(mismatch.message, expected: self, actual: value, in: table)
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
                    leaning: { leaning in table.fulfillment?.require(folded: leaning) }
                ) == nil
            }

        // `Double` takes no whole number and so no byte, and neither do the
        // rest. Named rather than left to a default, so that a kind added to
        // the type language has to be answered for here too.
        case .never, .null, .bool, .double, .string,
             .array, .dictionary, .struct, .procedure, .named:
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
            return "\(TypeSpelling.some) \(Path([.name(of)] + path.segments).rendered)"

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
            let failing = signature.failing == .unstated ? "" : " failing \(signature.failing.rendered)"

            return "\(spelling)<(\(written.joined(separator: ", ")))"
                + " -> \((signature.returns ?? .any).rendered(in: table))\(failing)>"

        case let .array(element):
            return "Array<\(element.rendered(in: table))>"

        case let .dictionary(key, value):
            return "Dictionary<\(key.rendered(in: table)), \(value.rendered(in: table))>"

        case let .struct(held):
            return held.name.spelling

        case let .named(row, arguments):
            guard !arguments.isEmpty else { return table.labels[row].spelling }

            return "\(table.labels[row].spelling)<\(arguments.map { argument in argument.rendered(in: table) }.joined(separator: ", "))>"

        case let .nullable(inner):
            return "\(inner.rendered(in: table))?"
        }
    }

    // The type's string spelling, as a value a program reads holds it. A
    // procedure type's signature has none, so a procedure type is spelled
    // by what stands in front of it and `Procedure`.
    func spelling(in table: LoweredTypeTable) -> String {
        switch self {
        case let .procedure(_, constness, isolation):
            return LoweredType.procedure(nil, constness: constness, isolation: isolation).rendered(in: table)

        case let .array(element):
            return "Array<\(element.spelling(in: table))>"

        case let .dictionary(key, value):
            return "Dictionary<\(key.spelling(in: table)), \(value.spelling(in: table))>"

        case let .nullable(inner):
            return "\(inner.spelling(in: table))?"

        default:
            return rendered(in: table)
        }
    }

    // A value written as a literal, as a place of this type holds it: each
    // whole number standing where this declares a Double is the fraction it
    // names, at whatever depth of a list or a map it stands. A struct is its
    // declaration's, its fields held to it where it was made.
    // Everything else is the value as written, and whether it fits is the
    // judge's to say.
    func written(_ value: Value, in table: LoweredTypeTable) -> Value {
        switch (self, value) {
        case let (.double, .int(whole)):
            return .double(Double(whole))

        case let (.named(row, arguments), _):
            return table.declared(row, applied: arguments).written(value, in: table)

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

        default:
            return value
        }
    }

    // The same for an expression written into a place of this type: the
    // literals in it, at the depths a list, a map, a struct and the answer of
    // a block or an attempt hand on.
    func written(_ expression: Expression, in table: LoweredTypeTable) -> Expression {
        reaching(expression, in: table) { place, standing in
            guard case let .literal(value) = standing else { return nil }

            return .literal(place.written(value, in: table))
        }
    }

    // What a reading is once what it reads is written where this is
    // declared: a whole literal standing where this declares a Double is the
    // fraction it names, at whatever depth of a list or a map it stands, the
    // way `written` writes the value itself. Every other reading is what
    // it was.
    func written(_ reading: LoweredType, in table: LoweredTypeTable) -> LoweredType {
        switch (self, reading) {
        case (.double, .wholeLiteral):
            return .double

        case let (.named(row, arguments), _):
            return table.declared(row, applied: arguments).written(reading, in: table)

        case let (.nullable(inner), _), let (.variable(inner), _), let (.inout(inner), _):
            return inner.written(reading, in: table)

        case let (.array(element), .array(read)):
            return .array(element.written(read, in: table))

        case let (.dictionary(key, entry), .dictionary(readKey, read)):
            return .dictionary(key: key.written(readKey, in: table), value: entry.written(read, in: table))

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
        reaching(expression, in: table) { place, standing in
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

        // A struct is written once, where it is declared, and spelled by its
        // name.
        case let .struct(structType):
            return .named(structType.name)

        case let .procedure(signature, constness, isolation):
            guard let signature else { return .procedure(nil, constness, isolation) }

            return .procedure(
                ProcedureType(
                    parameters: signature.parameters.map { parameter in parameter.spelled(in: table) },
                    returns: signature.returns?.spelled(in: table),
                    failing: signature.failing
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

        case let .named(row, arguments):
            return .named(table.labels[row], arguments: arguments.map { argument in argument.spelled(in: table) })

        case let .parameter(label, _):
            return .parameter(name: label)

        case let .composition(names):
            return .composition(Set(names))

        case let .projection(of, path):
            return .projection(of: of, path: path)
        }
    }

    // This mention of a row applying it to `arguments`: a struct's own row
    // takes them, and an alias, which takes none, is what it stands for, a
    // struct applied to types included.
    func applied(to arguments: [LoweredType]) -> LoweredType {
        guard !arguments.isEmpty, case let .named(row, written) = self, written.isEmpty else { return self }

        return .named(row, arguments: arguments)
    }

    // How a struct reads in a message, each field beside how it reads, in
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

        case let (.struct(mine), .struct(theirs)):
            return mine == theirs

        case let (.procedure(mine, myConstness, myIsolation),
                  .procedure(theirs, theirConstness, theirIsolation)):
            return myConstness == theirConstness
                && myIsolation == theirIsolation
                && mine == theirs

        case let (.named(mine, myArguments), .named(theirs, theirArguments)):
            return mine == theirs && myArguments == theirArguments

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

    // Hashed by its shape: the case, and the rows, names and readings it holds
    // where it holds them, which two equal readings share.
    func hash(into hasher: inout Hasher) {
        switch self {
        case let .array(inner), let .variable(inner), let .inout(inner), let .nullable(inner):
            hasher.combine(caseRank)
            hasher.combine(inner)

        case let .dictionary(key, value):
            hasher.combine(caseRank)
            hasher.combine(key)
            hasher.combine(value)

        case let .named(row, arguments):
            hasher.combine(caseRank)
            hasher.combine(row)
            hasher.combine(arguments)

        case let .parameter(label, bounds):
            hasher.combine(caseRank)
            hasher.combine(label)
            hasher.combine(bounds)

        case let .composition(names):
            hasher.combine(caseRank)
            hasher.combine(names)

        default:
            hasher.combine(caseRank)
        }
    }

    // MARK: - Private
    // Which case this is, as a number to hash.
    private var caseRank: Int {
        switch self {
        case .any: 0
        case .never: 1
        case .null: 2
        case .bool: 3
        case .int: 4
        case .wholeLiteral: 5
        case .double: 6
        case .string: 7
        case .array: 8
        case .dictionary: 9
        case .struct: 10
        case .procedure: 11
        case .variable: 12
        case .inout: 13
        case .nullable: 14
        case .named: 15
        case .parameter: 16
        case .composition: 17
        case .projection: 18
        }
    }

    // The join of two readings where one takes the other, `takingGiven`
    // saying which, walked in step. Each position below is asked the same.
    // A reading of `Any` at a position is `Any` there, as it is for the
    // whole parameter: it is the loosest reading there is, and `accepts`
    // cannot order it.
    private func merged(with given: LoweredType, takingGiven takesGiven: Bool, in table: LoweredTypeTable) -> LoweredType {
        guard self != .any, given != .any else { return .any }

        let looser = takesGiven ? self : given

        switch (self, given) {
        case let (.array(element), .array(other)):
            return .array(element.merged(with: other, in: table))

        case let (.dictionary(key, element), .dictionary(otherKey, other)):
            return .dictionary(key: key.merged(with: otherKey, in: table), value: element.merged(with: other, in: table))

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
            leaning: { leaning in table.fulfillment?.require(folded: leaning) }
        )

        if let refusal {
            throw ArgumentError("\(path()): \(refusal)")
        }

        return value
    }

    // A struct holding exactly the fields of `held`, each settled against its
    // type, built on the struct's layout. Whose name it carries is asked
    // before this.
    private func settlingFields(
        _ instance: Struct,
        of held: LoweredStruct,
        at path: @autoclosure () -> String,
        in table: LoweredTypeTable
    ) throws -> Struct {
        let layout = held.layout

        // A struct laid out as this one is holds exactly its fields, which is
        // what a value of a struct type the build judged is.
        if instance.names == held.names {
            return Struct(
                layout: layout,
                values: try zip(held.named, instance.values).map { pair, given in
                    try pair.1.settling(given, at: "\(path()).\(pair.0)", in: table)
                }
            )
        }

        if let field = Set(instance.names).subtracting(held.names).min() {
            throw ArgumentError(
                "\(path()).\(field): is not a field of \(rendered(in: table)), and a struct holds exactly its fields"
            )
        }

        return Struct(
            layout: layout,
            values: try held.named.map { name, field in
                guard let given = instance[name] else {
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
            LoweredProcedureType(parameters: linked.slots.map(\.type), returns: linked.returns, failing: linked.failing),
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

    // The walk `written` and `completing` share: an expression standing where
    // this is read, through what may be null and the names around it, at the
    // depths a list, a map, a struct and the answer of a block, an attempt or
    // a loop hand on. `replacing` is asked first at each depth, with the type
    // read there, and answers what stands in place of the expression, or nil
    // to walk on.
    private func reaching(
        _ expression: Expression,
        in table: LoweredTypeTable,
        replacing: (LoweredType, Expression) -> Expression?
    ) -> Expression {
        func answering(_ block: Block) -> Block {
            Block(
                body: block.body,
                result: block.result.map { result in reaching(result, in: table, replacing: replacing) }
            )
        }

        // What a block, an attempt or a loop answers stands where this is
        // read, so it is walked with this type as it stands, a name around
        // it included.
        switch expression {
        case let .block(block):
            return .block(answering(block))

        case let .attempt(block, rescue):
            return .attempt(answering(block), rescue: answering(rescue))

        case let .loop(condition, body):
            return .loop(while: condition, body: answering(body))

        default:
            break
        }

        switch self {
        case let .nullable(inner), let .variable(inner), let .inout(inner):
            return inner.reaching(expression, in: table, replacing: replacing)

        case let .named(row, arguments):
            return table.declared(row, applied: arguments).reaching(expression, in: table, replacing: replacing)

        default:
            break
        }

        if let standing = replacing(self, expression) {
            return standing
        }

        switch expression {
        case let .array(items):
            guard let element = self.element else { return expression }

            return .array(items.map { item in element.reaching(item, in: table, replacing: replacing) })

        case let .struct(fields):
            return .struct(
                Dictionary(uniqueKeysWithValues: fields.map { name, field in
                    (name, dotted(name, in: table).map { dotted in
                        dotted.reaching(field, in: table, replacing: replacing)
                    } ?? field)
                })
            )

        case let .dictionary(entries):
            guard case let .dictionary(key, value) = slotUnwrapped else { return expression }

            return .dictionary(entries.map { entry in
                (
                    key: key.reaching(entry.key, in: table, replacing: replacing),
                    value: value.reaching(entry.value, in: table, replacing: replacing)
                )
            })

        default:
            return expression
        }
    }
}
