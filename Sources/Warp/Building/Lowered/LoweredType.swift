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

    // What an integer literal reads as: an Int, or the floating-point number
    // it names where the place it is written into declares a Double. A
    // reading and never a declaration, and an Int as a name holds it.
    case wholeLiteral

    case array(LoweredType)
    case dictionary(key: LoweredType, value: LoweredType)

    // A declared struct's row: what a mention of it, `named`, stands for.
    case `struct`(LoweredStruct)

    // What a slot asks of a procedure value: the types it is applied with, in
    // position order, and what it must return. Nil where no signature was
    // declared. Constness and isolation are the slot's requirements.
    case procedure(LoweredProcedureType?, constness: Constness, isolation: Isolation)

    case variable(LoweredType)
    case `inout`(LoweredType)
    case optional(LoweredType)

    // A declared type, by its row in the table, with the types a struct
    // taking type parameters is applied to, in the order it lists them.
    case named(Int, arguments: [LoweredType] = [])

    // A type parameter the call fills, and the contracts the signature
    // held it to, in name order. The label is the spelling that ties one
    // mention to another.
    case parameter(label: Name, bounds: [Name])

    // A value of whatever type conforms to every contract here, which no call
    // fills and no other mention shares: what a contract's name, or `A & B`,
    // stands for where a type is written. Apart from a parameter, so that
    // what fills a parameter cannot pass for what holds a value to its
    // bounds.
    case composition([Name])

    // How a reading meets an Optional, by the slot rule: a reading of an
    // Optional whose payload the place's payload takes as it stands stands as
    // it is, a reading of `Null` is the none, and a reading the payload takes
    // is its some.
    enum Meeting {
        case standing
        case asNone
        case asSome
    }

    // MARK: - Property
    // What a field a declaration wrote `var` holds. The mark is a fact about
    // the field, and what is read out of it is the type inside.
    //
    // No `default` on either below: a mark nobody thought about must be a
    // compile error here rather than a result of "no mark".
    var fieldUnwrapped: LoweredType {
        switch self {
        case let .variable(inner):
            return inner

        case .any, .never, .null, .bool, .int, .wholeLiteral, .double, .string,
            .array, .dictionary, .struct, .procedure, .inout, .optional,
            .named, .parameter, .composition:
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

        case let .array(inner), let .optional(inner), let .variable(inner), let .inout(inner):
            return inner.namesParameter

        case let .dictionary(key, value):
            return key.namesParameter || value.namesParameter

        case let .procedure(signature, _, _):
            return (signature?.parameters ?? []).contains { parameter in parameter.namesParameter }
                || (signature?.returns.namesParameter ?? false)

        // A mention of a struct names what it is applied to. The struct's
        // own parameters are its declaration's, which a mention fills.
        case let .named(_, arguments):
            return arguments.contains(where: \.namesParameter)

        case .any, .never, .null, .bool, .int, .wholeLiteral, .double, .string, .struct, .composition:
            return false
        }
    }

    // Whether this writes the type parameter where `holding` does not walk:
    // inside a struct or a procedure type, rather than alone or through an
    // Optional, a list and a dictionary.
    func writesBeyondHolding(_ parameter: Name) -> Bool {
        switch self {
        case let .array(inner), let .optional(inner), let .variable(inner), let .inout(inner):
            return inner.writesBeyondHolding(parameter)

        case let .dictionary(key, value):
            return key.writesBeyondHolding(parameter) || value.writesBeyondHolding(parameter)

        case .procedure, .named:
            return typeParameters[parameter] != nil

        case .any, .never, .null, .bool, .int, .wholeLiteral, .double, .string, .struct, .composition, .parameter:
            return false
        }
    }

    // Every type parameter this names, by label, with the bounds it is held
    // to, none for one no bound holds.
    var typeParameters: [Name: [Name]] {
        switch self {
        case let .parameter(label, bounds):
            return [label: bounds]

        case let .array(inner), let .optional(inner), let .variable(inner), let .inout(inner):
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

        case .any, .never, .null, .bool, .int, .wholeLiteral, .double, .string, .struct, .composition:
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
            .array, .dictionary, .struct, .procedure, .optional,
            .named, .parameter, .composition:
            return self
        }
    }

    // What a literal written where this is read is written into: the type
    // through `?`, `var` and `inout`, which hold no value of their own.
    var literalPlace: LoweredType {
        switch self {
        case let .optional(inner), let .variable(inner), let .inout(inner):
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

        case let .optional(inner), let .variable(inner), let .inout(inner):
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

        case let .optional(inner), let .variable(inner), let .inout(inner):
            return inner.arguments

        default:
            return []
        }
    }

    // The type a reading widens to where nothing reads it as a literal: a
    // integer literal is an Int.
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
        case .parameter:
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

    // This reading as a name holds it: an integer literal, wherever in it
    // one stands, is an Int.
    var asHeld: LoweredType {
        switch self {
        case .wholeLiteral:
            return .int

        case let .array(element):
            return .array(element.asHeld)

        case let .dictionary(key, value):
            return .dictionary(key: key.asHeld, value: value.asHeld)

        case let .optional(inner):
            return .optional(inner.asHeld)

        case let .named(row, arguments):
            return .named(row, arguments: arguments.map(\.asHeld))

        case .any, .never, .null, .bool, .int, .double, .string, .struct, .procedure, .variable, .inout,
            .parameter, .composition:
            return self
        }
    }

    // What a box a write may fill again holds where its start reads as this:
    // an integer literal an Int, wherever in it one stands, and every
    // procedure in it without the constness, isolation or failing the one
    // value judged declared, since a write may put another procedure there.
    var boxed: LoweredType {
        switch self {
        case .wholeLiteral:
            return .int

        case let .array(element):
            return .array(element.boxed)

        case let .dictionary(key, value):
            return .dictionary(key: key.boxed, value: value.boxed)

        case let .optional(inner):
            return .optional(inner.boxed)

        case let .procedure(signature, _, _):
            return .procedure(signature?.with(failing: .anything), constness: .unstated, isolation: .unstated)

        case let .named(row, arguments):
            return .named(row, arguments: arguments.map(\.boxed))

        case .any, .never, .null, .bool, .int, .double, .string, .struct, .variable, .inout,
            .parameter, .composition:
            return self
        }
    }

    // The Optional of this, or this where it is an Optional already: what a
    // path holding a marked step reads, and `Null` beside a reading.
    var madeOptional: LoweredType {
        if case .optional = self { return self }

        return .optional(self)
    }

    // How many Optionals stand around what this holds: two for `Int??`, and
    // none for a type that is no Optional.
    var optionalDepth: Int {
        guard case let .optional(inner) = self else { return 0 }

        return inner.optionalDepth + 1
    }

    // Whether a value of this may be a none, `null` or a marker, so that its
    // some at an Optional is the marker holding it: `Null`, `Any`, an
    // Optional, a type parameter and a contract. Everywhere else the some of
    // a value is the value itself.
    var mayHoldNone: Bool {
        switch self {
        case .null, .any, .optional, .parameter, .composition:
            return true

        case let .variable(inner), let .inout(inner):
            return inner.mayHoldNone

        case .never, .bool, .int, .wholeLiteral, .double, .string, .array, .dictionary, .struct, .procedure, .named:
            return false
        }
    }

    // One value of every kind a decided type can hold, for asking the judge
    // rather than restating it.
    private static let samples: [Value] = [
        .null, .bool(false), .int(0), .double(0), .string(""),
        .array([]), .dictionary([:]), .bytes([])
    ]

    // Whether this reads a contract, a composition or one contract, so a
    // value of it is held beside the type it was read as.
    var isContract: Bool {
        guard case .composition = self else { return false }

        return true
    }

    // Whether this reads a contract here or in a list's, a dictionary's or an
    // Optional's part: where a value read as another type is held beside
    // what it was read as.
    var holdsContract: Bool {
        switch self {
        case .composition:
            return true

        case let .array(inner), let .optional(inner):
            return inner.holdsContract

        case let .dictionary(key, value):
            return key.holdsContract || value.holdsContract

        default:
            return false
        }
    }

    // Whether a value of this type may hold a type beside it, here or in a
    // part: where it reads a contract, or a type parameter no bound holds,
    // which a call may fill with one. A declared struct's fields are read
    // through the table, each struct once.
    func mayHoldExistential(in table: LoweredTypeTable) -> Bool {
        var visited = Set<Int>()

        return mayHoldExistential(in: table, visited: &visited)
    }

    // Whether a value of any type passes this as it is: nothing declared, or
    // a type parameter no bound holds. Settling
    // against one says nothing, so what holds it need not be walked.
    var passesEverything: Bool {
        switch self {
        case .any, .parameter(_, bounds: []):
            return true

        default:
            return false
        }
    }

    // Whether a list or a dictionary here, at whatever depth, holds no element a
    // value could be: what an empty literal reads as, which says nothing of
    // what a box of it will hold.
    var holdsNoElement: Bool {
        switch self {
        case .array(.never), .dictionary(_, .never):
            return true

        case let .array(inner), let .optional(inner):
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

        case let .optional(inner):
            let bounded = inner.boundedAlone

            return bounded == .any ? .any : .optional(bounded)

        case let .variable(inner):
            let bounded = inner.boundedAlone

            return bounded == .any ? .any : .variable(bounded)

        case let .inout(inner):
            let bounded = inner.boundedAlone

            return bounded == .any ? .any : .inout(bounded)

        // A procedure's return type stands where it is held, and is held there. Its
        // parameters are what it is handed and take `Never`, which every
        // parameter takes, so they ask nothing.
        case let .procedure(signature, _, _):
            guard let signature else { return .any }

            let returnType = signature.returns.boundedAlone

            guard returnType != .any else { return .any }

            return .procedure(
                LoweredProcedureType(
                    parameters: signature.parameters.map { parameter in parameter.isInout ? .inout(.never) : .never },
                    returns: returnType,
                    failing: .anything
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

        // The type its value is an instance of, whatever it was read as.
        case let .existential(existential):
            self = LoweredType(of: existential.value, in: table)

        case let .array(elements):
            self = .array(LoweredType(joining: elements.map { element in LoweredType(of: element, in: table) }))

        // A struct reads as the struct its name declares, an alias's name
        // its struct's, and as `Any` under a name this table declares none
        // under, which a door refuses before anything reads it.
        // A struct taking type parameters reads as applied to what its
        // fields read them as. The marker holding a value is a some of the
        // Optional of what that value is an instance of.
        case let .struct(instance):
            if instance.isMarker {
                self = .optional(LoweredType(of: instance[Prelude.markerField] ?? .null, in: table))

                return
            }

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

        // A dictionary reads as what its keys and its values hold, joined, and is a
        // dictionary where its keys join to `Any`: a door holds a value to the type
        // it is an instance of. A constant's type is the build's, under
        // `refined(by:)`.
        case let .dictionary(dictionary):
            self = .dictionary(
                key: LoweredType(joining: dictionary.keys.map { key in LoweredType(of: key, in: table) }),
                value: LoweredType(joining: dictionary.values.map { value in LoweredType(of: value, in: table) })
            )
        }
    }

    // What a value says of its type: what it reads as, every struct in it
    // as the struct it is and not applied to anything. A value carries no
    // type's arguments, so two boxes are of one type whatever they hold.
    init(unapplied value: Value, in table: LoweredTypeTable) {
        switch value {
        case let .array(elements):
            self = .array(LoweredType(joining: elements.map { element in LoweredType(unapplied: element, in: table) }))

        case let .struct(instance) where instance.isMarker:
            self = .optional(LoweredType(unapplied: instance[Prelude.markerField] ?? .null, in: table))

        case let .struct(instance):
            self = table.structRow(named: instance.name).map { row in .named(row) } ?? .any

        case let .dictionary(dictionary):
            self = .dictionary(
                key: LoweredType(joining: dictionary.keys.map { key in LoweredType(unapplied: key, in: table) }),
                value: LoweredType(joining: dictionary.values.map { value in LoweredType(unapplied: value, in: table) })
            )

        default:
            self = LoweredType(of: value, in: table)
        }
    }

    // What a value written as a literal reads as: an integer literal as one
    // whose place may read it as a floating-point number, at whatever depth
    // of a list or a dictionary it stands, and anything else as the value it is.
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
    // are none: an empty list or dictionary holds no element, so it is a value of a
    // list or a dictionary of any type.
    private init(joining readings: [LoweredType]) {
        self = readings.dropFirst().reduce(readings.first ?? .never) { joined, next in joined.joined(next) }
    }

    // A dictionary keyed by `key` and holding `value`, as the build reads one: a
    // key read as `Any` conforms to no `Hashable`, so a dictionary of it is no dictionary type
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

    // What a slot said the procedure it holds may fail with: anything where
    // it writes no signature to say it in.
    var procedureFailing: Failing {
        guard case let .procedure(signature?, _, _)? = procedureHeld else { return .anything }

        return signature.failing
    }

    // What a slot said the procedure it holds returns: nil where it writes no
    // signature to say it in.
    var procedureReturns: LoweredType? {
        guard case let .procedure(signature?, _, _)? = procedureHeld else { return nil }

        return signature.returns
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
    // parameters and return type are that procedure's business and are not walked.
    func carriesProcedureTakingInPlace(in table: LoweredTypeTable, walked: Set<Int> = []) -> Bool {
        switch self {
        case let .procedure(signature, _, _):
            return signature?.parameters.contains { parameter in parameter.isInout } ?? false

        case let .optional(inner), let .array(inner), let .dictionary(_, inner), let .variable(inner), let .inout(inner):
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

        case .any, .never, .null, .bool, .int, .wholeLiteral, .double, .string, .parameter, .composition:
            return false
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

        // Brackets on a dictionary read an entry the way they read a list's
        // element.
        case let .dictionary(_, value):
            return value

        case let .variable(inner), let .inout(inner):
            return inner.element

        default:
            return nil
        }
    }

    // A constant's type: its folded value's, with each procedure it holds read
    // by the type the value's expression was judged at in that position (an
    // element, an entry), the constness, isolation and failing its signature
    // declares included. A struct's fields are its declaration's. A procedure
    // value says nothing about its signature, and the expression that made it
    // wrote one; everything else is the value's. Null, `Any`, and a list or a
    // dictionary showing no element, say nothing the judged type does not, so what
    // holds one is what the expression was judged as, a cast's type among them.
    // A dictionary whose keys the value joins to `Any` is no dictionary type, so it takes the
    // judged key, and where the judged type keys no dictionary it reads as that type,
    // `Any` where nothing is written.
    func refined(by judged: LoweredType) -> LoweredType {
        guard self != .null, self != .any, !holdsNoElement else { return judged }

        // A value reading an Optional is the marker, a some of the judged
        // Optional whose payload refines what it holds.
        if case let .optional(inner) = self, case let .optional(judgedInner) = judged {
            return .optional(inner.refined(by: judgedInner))
        }

        var written = judged

        if case let .optional(inner) = written {
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
    // its Optional, two lists join by their elements and two dictionaries by
    // their keys and their values, and two procedures to a procedure. Where
    // two parts still disagree the part holds neither, which is what `Any`
    // says, and two dictionaries whose keys join to `Any` are no dictionary type, since a
    // key conforms to `Hashable`, so they read `Any` whole. A join that guessed
    // would be a refusal an author cannot act on.
    //
    // A reading that leaves is not one of the two. It contributes no value, so
    // it cannot disagree with the reading that stays, and the slot holds what
    // the other one said.
    func joined(_ other: LoweredType) -> LoweredType {
        guard self != .never else { return other }
        guard other != .never else { return self }
        guard self != other else { return self }

        // Null beside a reading is the none beside it, so the two read its
        // Optional, or the reading itself where that is an Optional. An
        // Optional beside another reading holds its payload or that reading,
        // as its some.
        if self == .null { return other.madeOptional }
        if other == .null { return madeOptional }

        switch (self, other) {
        case let (.optional(mine), .optional(theirs)):
            return .optional(mine.joined(theirs))

        case let (.optional(mine), _):
            return .optional(mine.joined(other))

        case let (_, .optional(theirs)):
            return .optional(joined(theirs))

        default:
            break
        }

        // An integer literal beside a number is read as that number's kind,
        // the floating-point number it names beside a Double, and beside
        // anything else it is the Int it is.
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

        switch (self, other) {
        case let (.array(mine), .array(theirs)):
            return .array(mine.joined(theirs))

        case let (.dictionary(myKey, mine), .dictionary(theirKey, theirs)):
            return LoweredType(keyedBy: myKey.joined(theirKey), holding: mine.joined(theirs))

        // One struct is one type only at the same arguments, so two readings
        // of it join where each is that one type, an integer literal read as
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
    // and no declaration writes is read as what is declared: an integer literal
    // as the number it names, and `Never`, what holds no value, as any type.
    // A procedure type is that type: its effects are declared, and the same
    // as the declaration's rather than within them.
    func reads(as declared: LoweredType) -> Bool {
        switch (self, declared) {
        case (.wholeLiteral, .int), (.wholeLiteral, .double), (.never, _):
            return true

        case let (.procedure(given, constness, isolation), .procedure(asked, wanted, wantedIsolation)):
            guard effects(of: given, constness, isolation) == effects(of: asked, wanted, wantedIsolation) else {
                return false
            }

            guard let asked, let given else { return asked == given }

            return given.parameters.count == asked.parameters.count
                && zip(given.parameters, asked.parameters).allSatisfy { mine, theirs in mine.reads(as: theirs) }
                && given.returns.reads(as: asked.returns)

        case let (.array(mine), .array(theirs)), let (.optional(mine), .optional(theirs)):
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

    // The type a value read as this is, under the name a claim writes and
    // `Value.nominal` returns once the value arrives: a declared struct by its
    // name, bytes as the list they are, and an Optional as `Optional`, which a
    // value does not name. Nil where the reading names no one type: a type
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

        case .dictionary:
            return TypeSpelling.dictionary

        case let .struct(structType):
            return structType.name

        case .procedure:
            return TypeSpelling.procedure

        case let .named(row, _):
            return table.labels[row]

        case .optional:
            return TypeSpelling.optional

        case let .variable(inner), let .inout(inner):
            return inner.nominal(in: table)

        case .any, .never, .parameter, .composition:
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
        // What reads as `Never` never arrives, so it cannot be the value that
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
        // structure, which the branches below decide.
        case let (.parameter(mine, _), .parameter(theirs, _)):
            return mine == theirs

        case let (.parameter, .variable(inner)), let (.parameter, .inout(inner)):
            return accepts(inner, in: table)

        // A slot's own wrapping comes off before what stands for it is taken
        // apart, since a name or a composition there is what a contract
        // reads. `var` is a fact about a slot.
        case let (.variable(inner), _):
            return inner.accepts(other, in: table)

        // An Optional slot takes null as its none, whatever its payload.
        case (.optional, .null):
            return true

        // A value read as a composition is of a type that conforms to its
        // contracts and nothing more the build knows of, so it stands where
        // every contract asked is one it conforms to.
        case let (.composition(bounds), .composition(theirs)):
            return Set(bounds).isSubset(of: theirs)

        // A composition takes what conforms to each of its contracts, asked of
        // the table. A value read as `Any` conforms to none until a cast says
        // what it is.
        case let (.composition(bounds), _):
            return bounds.allSatisfy { contract in
                table.conforms(to: contract, reading: other)
            }

        // A reading that is neither `Null` nor an Optional is the payload's
        // some where the payload takes it.
        case let (.optional(mine), _) where !other.slotUnwrapped.declaresNone(in: table):
            return mine.accepts(other, in: table)

        case let (_, .variable(inner)), let (_, .inout(inner)):
            return accepts(inner, in: table)

        case (.any, _):
            return true

        case (_, .any), (_, .composition):
            return false

        case (.never, _):
            return false

        // A declared struct is nominal: a value of it fits only its own
        // name, whatever the structure, and nothing else is a value of it.
        // Applied to types, it is one type only where it is applied to the
        // same ones.
        case (.named, _), (_, .named):
            return other.reads(as: self)

        // An Optional slot takes an Optional whose payload its own payload
        // takes as it stands, and an Optional its payload takes as its some;
        // null and what is no Optional were taken above. An Optional does
        // not stand where no Optional is declared.
        case (.optional, .optional):
            return meeting(other, in: table) != nil

        case let (.array(mine), .array(theirs)):
            return mine.accepts(theirs, in: table)

        case let (.dictionary(myKey, mine), .dictionary(theirKey, theirs)):
            return myKey.accepts(theirKey, in: table) && mine.accepts(theirs, in: table)

        case let (.procedure(required, wantedConstness, wantedIsolation),
                  .procedure(given, offeredConstness, offeredIsolation)):
            // What stands here does no more than the slot allows.
            let allowed = effects(of: required, wantedConstness, wantedIsolation)

            guard effects(of: given, offeredConstness, offeredIsolation).exceeding(allowed) == nil else { return false }

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
            // required must accept everything it will get back. A procedure
            // value is not walked, so no value it takes or returns is
            // promoted on the way.
            for (parameter, taken) in zip(required.parameters, given.parameters) {
                guard taken.takes(parameter, in: table), taken.promotions(of: parameter, wrappingOnly: true, in: table).isEmpty else {
                    return false
                }
            }

            return required.returns.accepts(given.returns, in: table)
                && required.returns.promotions(of: given.returns, wrappingOnly: true, in: table).isEmpty

        // An integer literal is an Int, or the floating-point number it names
        // where the place declares a Double.
        case (.int, .wholeLiteral), (.double, .wholeLiteral):
            return true

        // A parameter no call fills, which no branch above took by its
        // structure (`Any`, a composition, an Optional or a name around it).
        // Last, because a refusal any earlier would cover those too.
        case (_, .parameter):
            return false

        default:
            return self == other
        }
    }

    // Whether a write into a box handed in place, of this type, holds. The
    // caller reads its box as what filled each type parameter here, so where
    // this writes a parameter only that parameter lands. Around one, an
    // Optional, a list or a dictionary takes what it takes anywhere; a type
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

        case (.optional, .null):
            return true

        case let (.optional(mine), .optional(theirs)) where theirs.optionalDepth >= mine.optionalDepth,
            let (.array(mine), .array(theirs)):
            return mine.takesInPlace(theirs, in: table)

        case let (.dictionary(myKey, mine), .dictionary(theirKey, theirs)):
            return myKey.takesInPlace(theirKey, in: table) && mine.takesInPlace(theirs, in: table)

        case (.named, .named):
            return written.reads(as: self)

        case let (.optional(mine), _):
            return mine.takesInPlace(written, in: table)

        // A procedure's positions and return type are written as themselves, and
        // its effects within what the slot asks, since a write is a value
        // standing where the slot is.
        case let (.procedure(signature, constness, isolation), .procedure(offered, given, held)):
            let allowed = effects(of: signature, constness, isolation)

            guard effects(of: offered, given, held).exceeding(allowed) == nil else { return false }

            guard let signature, let offered else { return signature == offered }

            return offered.with(failing: signature.failing) == signature

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

    // How a reading meets this where this is an Optional, or nil where this
    // is no Optional or does not take it. The order matters only where the
    // payload takes `Null` itself: a reading of `Null` is the outermost none,
    // and a reading of an Optional shallower than the payload is its some.
    func meeting(_ reading: LoweredType, in table: LoweredTypeTable) -> Meeting? {
        guard case let .optional(payload) = self else { return nil }

        let reading = reading.slotUnwrapped

        switch reading {
        case .null:
            return .asNone

        case .never:
            return .standing

        case let .optional(held) where held.optionalDepth >= payload.optionalDepth && payload.accepts(held, in: table):
            return .standing

        default:
            return payload.accepts(reading, in: table) ? .asSome : nil
        }
    }

    // Whether a value of `reading` comes to another value standing here than
    // standing at `other`: promoted otherwise, or its held type dropped at
    // one and not at the other. A hold changes no value. This is the one
    // test an inferred join is refused by.
    func changes(_ reading: LoweredType, otherwiseThan other: LoweredType, in table: LoweredTypeTable) -> Bool {
        Coercion(reading, landingIn: self, in: table)?.change != Coercion(reading, landingIn: other, in: table)?.change
    }

    // Where a value of `reading` landing here is promoted, as the steps
    // walking to each part that meets an Optional as its some, the innermost
    // first and the value itself as no step. `wrappingOnly` keeps the parts
    // that may hold a none, the only ones whose value a promotion changes. A
    // list is walked into its elements and a dictionary into its keys and its
    // values; an Optional the reading stands at is walked by value, and its
    // none holds no part.
    func promotions(of reading: LoweredType, wrappingOnly: Bool, in table: LoweredTypeTable) -> [[Coercion.Step]] {
        let reading = reading.slotUnwrapped

        switch (slotUnwrapped, reading) {
        case let (.optional(payload), _):
            switch meeting(reading, in: table) {
            case .asSome?:
                return payload.promotions(of: reading, wrappingOnly: wrappingOnly, in: table)
                    + (!wrappingOnly || reading.mayHoldNone ? [[]] : [])

            case .standing?:
                guard case let .optional(held) = reading else { return [] }

                return payload.promotions(of: held, wrappingOnly: wrappingOnly, in: table)

            case .asNone?, nil:
                return []
            }

        case let (.array(element), .array(read)):
            return element.promotions(of: read, wrappingOnly: wrappingOnly, in: table).map { steps in [.element] + steps }

        case let (.dictionary(key, value), .dictionary(readKey, read)):
            return key.promotions(of: readKey, wrappingOnly: wrappingOnly, in: table).map { steps in [.key] + steps }
                + value.promotions(of: read, wrappingOnly: wrappingOnly, in: table).map { steps in [.value] + steps }

        default:
            return []
        }
    }

    // This type with the part the steps walk to read as an Optional's some:
    // what a value of it is read as once promoted there. An Optional is
    // walked by value, as a promotion walks its some.
    func promoted(along steps: ArraySlice<Coercion.Step>) -> LoweredType {
        guard let step = steps.first else { return .optional(self) }

        switch (step, self) {
        case let (_, .optional(payload)):
            return .optional(payload.promoted(along: steps))

        case let (.element, .array(element)):
            return .array(element.promoted(along: steps.dropFirst()))

        case let (.key, .dictionary(key, value)):
            return .dictionary(key: key.promoted(along: steps.dropFirst()), value: value)

        case let (.value, .dictionary(key, value)):
            return .dictionary(key: key, value: value.promoted(along: steps.dropFirst()))

        default:
            return self
        }
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
        if declaresNone(in: table), other.declaresNone(in: table) { return true }

        // Literals are read as their kind first: whether a value could be
        // both is a question about kinds.
        switch (widened, other.widened) {
        case let (.optional(inner), theirs):
            return inner.couldBothHold(reading: theirs, in: table)

        case let (mine, .optional(inner)):
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
    // takes the other, walked in step through lists, dictionaries and
    // Optionals. Which was read first says nothing. At each position a reading
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
            holding.append(Substitution.Held(reading: given, bounds: bounds))

        case let (.parameter(name, _), _):
            substitution.read(name, as: given, in: table)

        // The slot's own wrapping comes off before what arrived is walked
        // through, so a name arriving is held to a composition as the name.
        case let (.variable(mine), _), let (.inout(mine), _):
            mine.binding(against: given, into: &substitution, taking: &taking, holding: &holding, in: table)

        // An Optional of a composition holds what arrived by how it meets the
        // Optional: an Optional standing there by its payload, and what the
        // payload takes as its some whole. Its none holds nothing.
        case let (.optional(.composition(bounds)), _):
            switch (meeting(given, in: table), given) {
            case (.asNone?, _):
                return

            case let (.standing?, .optional(payload)), let (nil, .optional(payload)):
                holding.append(Substitution.Held(reading: payload, bounds: bounds))

            default:
                holding.append(Substitution.Held(reading: given, bounds: bounds))
            }

        // An Optional slot takes null whole: it carries no reading and leaves
        // nothing to hold. An Optional arrival as deep as the slot's payload
        // reads by its own payload, and anything else is the payload's some.
        case (.optional, .null):
            return

        case let (.optional(mine), .optional(theirs)) where theirs.optionalDepth >= mine.optionalDepth:
            mine.binding(against: theirs, into: &substitution, taking: &taking, holding: &holding, in: table)

        case let (.optional(mine), _):
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

            mine.returns.binding(
                against: theirs.returns,
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
    // `Never`, and one read off integer literals alone is filled with
    // the Int they are.
    func filling(_ filled: [Name: LoweredType]) -> LoweredType {
        replacing { part in
            switch part {
            case let .parameter(name, _):
                return (filled[name] ?? .any).asHeld

            default:
                return nil
            }
        }
    }

    // This type with each parameter `given` names read as what it gives, and
    // every other left standing: a declaration's own parameters, some of
    // which a reading says and the rest of which stay the declaration's.
    func replacingParameters(_ given: [Name: LoweredType]) -> LoweredType {
        replacing { part in
            guard case let .parameter(label, _) = part else { return nil }

            return given[label]
        }
    }

    // The labels of the type parameters this names, each once, in the order
    // they are first met: what a call hands its types in.
    var parameterLabels: [Name] {
        var labels: [Name] = []

        _ = replacing { part in
            if case let .parameter(label, _) = part, !labels.contains(label) {
                labels.append(label)
            }

            return nil
        }

        return labels
    }

    // Whether a value read as this type could be a procedure: the question a
    // call of a value asks before the run. A reading no procedure could stand in
    // is a call every run refuses.
    var couldBeProcedure: Bool {
        switch self {
        // A type parameter or a contract stands for whichever type fills or
        // conforms to it, `Procedure` among them.
        case .procedure, .any, .never, .parameter, .composition:
            return true

        case let .optional(inner), let .variable(inner), let .inout(inner):
            return inner.couldBeProcedure

        case .null, .bool, .int, .wholeLiteral, .double, .string, .array, .dictionary, .struct, .named:
            return false
        }
    }

    // Which rows this type stands on. Read by replacing every row with
    // itself, so the walk over the tree stays written once.
    func standing(into types: inout Set<Int>) {
        _ = replacingRows { row in
            types.insert(row)

            return .named(row)
        }
    }

    // The same type with every row it stands on replaced, by another row or
    // by the type an alias stands for. A type is a tree and its rows stand at
    // the leaves, so a caller that can replace one row replaces the whole of
    // it, and the walk over the tree is written once.
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

        case let .optional(inner):
            return .optional(try inner.replacingRows(by: type))

        // A struct's arguments are replaced too, and stand on what the row
        // is replaced by: a row's own mention, or an alias, which takes no
        // arguments of its own and may stand for a struct applied to some.
        case let .named(row, arguments):
            return try type(row).applied(to: try arguments.map { argument in try argument.replacingRows(by: type) })

        // Every case that stands on no row, listed rather than let through:
        // a case added here has to say whether it holds one.
        case .any, .never, .null, .bool, .int, .wholeLiteral, .double, .string,
            .parameter, .composition:
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
        case .any:
            return value

        // A value at a type parameter stands as what it arrived as, and the
        // activation holds the type that fills it.
        case let .parameter(_, bounds):
            return try bounds.reduce(value) { value, contract in
                try standing(value, conformingTo: contract, at: path(), in: table)
            }

        // A value held beside a type is judged by the type it holds. Any
        // other stands as what it arrived as, held beside the type it is an
        // instance of.
        case let .composition(bounds):
            if case let .existential(existential) = value {
                for contract in bounds {
                    if let refusal = table.refusal(of: try existential.resolved(), conformingTo: contract, as: "is") {
                        throw ArgumentError("\(path()): \(refusal)")
                    }
                }

                return value
            }

            for contract in bounds {
                _ = try standing(value, conformingTo: contract, at: path(), in: table)
            }

            return .existential(Existential(value, as: LoweredType(of: value, in: table)))

        // A value arrived where nothing was supposed to, so the arrival is the
        // refusal: there is no type to compare it against.
        case .never:
            throw ArgumentError("\(path()): declares Never, and nothing is ever that")

        // A mention naming no arguments, what a value from outside is
        // settled by once its door applied it, reads them off the value.
        case let .named(row, arguments):
            let applied = arguments.isEmpty ? LoweredType(of: value, in: table).arguments : arguments

            return try table.declared(row, applied: applied).settling(value, at: path(), in: table)

        // A value of an Optional is its none, `null`, a marker holding a
        // value of the payload, which is a some of a none, or a value of the
        // payload that is neither.
        case let .optional(inner):
            guard value != .null else { return value }

            if case let .struct(marker) = value, marker.isMarker {
                return .struct(try marker.mapValues { field, held in
                    try inner.settling(held, at: "\(path()).\(field)", in: table)
                })
            }

            return try inner.settling(value, at: path(), in: table)

        case let .array(element):
            // Bytes are a list of integers in a compact spelling, so they
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

        // A dictionary slot judges every key and every value.
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

        // A closure carries what its signature declares, its constness, its
        // isolation and what it may fail with, and a slot that asks for any
        // of them reads the carried fact. A closure that reached
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
        // floating-point number, `2.0` included, and a `Double` slot every
        // integer.
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
        try settling(try table.admitting(value, under: self, at: path()), at: path(), in: table)
    }

    // A value read as `reading` where this place holds it, held beside what
    // it was read as wherever the place reads a contract, part by part
    // through a list, a dictionary and an Optional, an Optional by how the reading
    // meets it. The place and the reading are the ones the build judged, and
    // `filling` reads a type parameter in them as what fills it here. A value
    // read as a contract there holds its type already, and so does the some
    // of an Optional of one, a none holds none, a value read as `Any`, and the
    // some of an Optional of `Any`, holds none beside the type it is an
    // instance of, and a part the place reads as `Any` drops every type held
    // in it.
    func holding(
        _ value: Value,
        readAs reading: LoweredType,
        filling: (LoweredType) -> LoweredType,
        in table: LoweredTypeTable
    ) -> Value {
        switch (self, reading) {
        case (.composition, _):
            let filled = filling(reading)

            guard !filled.isContract, !value.isExistential else { return value }

            // Nothing is known of what a reading of `Any` holds, or the some
            // of an Optional of `Any`, but the type it is an instance of.
            if filled == .any { return value }
            if filled == .optional(.any), let some = value.payload { return some }

            return .existential(Existential(value, as: filled))

        case (.any, _):
            return value.dropped

        // An Optional the reading stands at holds its some at the payload and
        // keeps it a some, and a reading the payload takes as its some is
        // held whole, its none included.
        case let (.optional(payload), _):
            switch meeting(reading, in: table) {
            case .standing?:
                guard case let .optional(read) = reading.slotUnwrapped, let some = value.payload else { return value }

                return payload.holding(some, readAs: read, filling: filling, in: table).asSome

            case .asSome?:
                return payload.holding(value, readAs: reading, filling: filling, in: table)

            case .asNone?, nil:
                return value
            }

        // Bytes are integers, each an instance of what it reads as, so they
        // keep their spelling.
        case let (.array(element), .array(read)):
            guard case let .array(items) = value else { return value }

            return .array(items.map { item in element.holding(item, readAs: read, filling: filling, in: table) })

        case let (.dictionary(key, entry), .dictionary(readKey, readEntry)):
            guard case let .dictionary(held) = value else { return value }

            return .dictionary(
                Value.Dictionary(
                    ordered: held.entries.map { written in
                        (
                            key: key.holding(written.key, readAs: readKey, filling: filling, in: table),
                            value: entry.holding(written.value, readAs: readEntry, filling: filling, in: table)
                        )
                    }
                )
            )

        default:
            return value
        }
    }

    // What a cast does, said once. The judgement is `settling`'s; what this
    // adds is the one thing the cast spelling decides: what a mismatch means.
    //
    // A fold casts against the claims of one document's reach. Where the
    // value fits once every type no claim there is about is taken to conform,
    // what the cast comes to turns on claims beyond the reach, which the run
    // reads and the build does not, so the cast does not fold.
    //
    // A cast to a contract judges the type a value read as one holds, and a
    // cast to any other type the value alone. An asking cast reads this
    // type's Optional, so a match is its some.
    func reading(_ value: Value, optional: Bool, in table: LoweredTypeTable) throws -> Value {
        let value = isContract ? value : value.dropped

        do {
            let settled = try settling(value, at: "as \(rendered(in: table))", in: table)

            return optional ? settled.asSome : settled
        } catch let mismatch as ArgumentError {
            if !table.holdsEveryClaim, (try? settling(value, at: "", in: table.assumingUnseenClaims())) != nil {
                throw ExecutionError(
                    "folding this at the build casts a value of \(LoweredType(of: value, in: table).rendered(in: table))"
                        + " to \(rendered(in: table)), which turns on a claim no document within reach makes. What the build folds stands on what its document"
                        + " stands on, and the run reads every claim the link holds"
                )
            }

            // Only a mismatch is read as the author's expectation. Naming what
            // is absorbed rather than what is not keeps the default closed:
            // an error kind added later surfaces instead of quietly becoming
            // null.
            guard optional else {
                // Recoverable, unlike the same mismatch at a door: a cast is
                // the author expecting a kind of data the build could not
                // type, and being wrong about that is what the world does. An
                // `try` catches it.
                throw CastRefused(mismatch.message, expected: self, actual: value, in: table)
            }

            return .null
        }
    }

    // Whether this is `Null` or an Optional, a type whose values a none
    // stands among by its declaration: `Null`'s one value, or the
    // Optional's none. `Any` is not this: a type that declares nothing
    // accepts a null that arrives, but it does not spell null as a value.
    func declaresNone(in table: LoweredTypeTable) -> Bool {
        switch self {
        case .null, .optional:
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
        case .any, .int, .wholeLiteral:
            return true

        case let .variable(inner), let .inout(inner), let .optional(inner):
            return inner.holdsEveryByte(in: table)

        // A parameter stands for what arrived and does not settle it. A
        // bounded one asks each value whether its type stands where every
        // contract is asked, and every byte is an `Int`, so the result for one
        // is the result for all of them.
        case let .parameter(_, bounds), let .composition(bounds):
            return bounds.allSatisfy { contract in
                table.refusal(
                    of: .int,
                    conformingTo: contract,
                    as: "is"
                ) == nil
            }

        // `Double` takes no integer and so no byte, and neither do the
        // rest. Named rather than left to a default, so that a kind added to
        // the type language has to be accounted for here too.
        case .never, .null, .bool, .double, .string,
             .array, .dictionary, .struct, .procedure, .named:
            return false
        }
    }

    // How the type reads in a message: the spelling the author wrote, with
    // a row's label standing where the author wrote the name and each type
    // parameter's bounds beside its first naming.
    func rendered(in table: LoweredTypeTable) -> String {
        let bounds = typeParameters.compactMapValues { contracts in contracts.isEmpty ? nil : Set(contracts) }

        return TypeSyntax(spelled(in: table), bounds: bounds).spelling
    }

    // A value written as a literal, as a place of this type holds it: each
    // integer literal standing where this declares a Double is the
    // floating-point number it names, at whatever depth of a list or a dictionary it
    // stands. A struct is its
    // declaration's, its fields held to it where it was made.
    // Everything else is the value as written, and whether it fits is the
    // judge's to say.
    func written(_ value: Value, in table: LoweredTypeTable) -> Value {
        switch (self, value) {
        case let (.double, .int(integer)):
            return .double(Double(integer))

        case let (.named(row, arguments), _):
            return table.declared(row, applied: arguments).written(value, in: table)

        case let (.optional(inner), _), let (.variable(inner), _), let (.inout(inner), _):
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
    // literals in it, at the depths a list, a dictionary and a struct hand on.
    func written(_ expression: Expression, in table: LoweredTypeTable) -> Expression {
        reaching(expression, in: table) { place, standing in
            guard case let .literal(value) = standing else { return nil }

            return .literal(place.written(value, in: table))
        }
    }

    // What a reading is once what it reads is written where this is
    // declared: an integer literal standing where this declares a Double is
    // the floating-point number it names, at whatever depth of a list or a
    // dictionary it stands, the way `written` writes the value itself. Every other reading is what
    // it was.
    func written(_ reading: LoweredType, in table: LoweredTypeTable) -> LoweredType {
        switch (self, reading) {
        case (.double, .wholeLiteral):
            return .double

        case let (.named(row, arguments), _):
            return table.declared(row, applied: arguments).written(reading, in: table)

        case let (.optional(inner), _), let (.variable(inner), _), let (.inout(inner), _):
            return inner.written(reading, in: table)

        case let (.array(element), .array(read)):
            return .array(element.written(read, in: table))

        case let (.dictionary(key, entry), .dictionary(readKey, read)):
            return .dictionary(key: key.written(readKey, in: table), value: entry.written(read, in: table))

        default:
            return reading
        }
    }

    // This type as a declaration writes it: lowering run backwards. A
    // declared name goes back to its label, so what it stands for, a mark
    // lowering dropped included, is read again where the spelling is
    // lowered. An integer literal is read as the Int a name holds it as. A type
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
                    returns: signature.returns.spelled(in: table),
                    failing: signature.failing
                ),
                constness,
                isolation
            )

        case let .variable(inner):
            return .variable(inner.spelled(in: table))

        case let .inout(inner):
            return .inout(inner.spelled(in: table))

        case let .optional(inner):
            return .optional(inner.spelled(in: table))

        case let .named(row, arguments):
            return .named(table.labels[row], arguments: arguments.map { argument in argument.spelled(in: table) })

        // An associated type's label is the parameter's name and its own.
        case let .parameter(label, _):
            guard let associated = AssociatedType(label: label) else { return .parameter(name: label) }

            return .associatedType(associated)

        case let .composition(names):
            return .composition(Set(names))
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
            let (.optional(mine), .optional(theirs)):
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

        default:
            return false
        }
    }

    // Hashed by its shape: the case, and the rows, names and readings it holds
    // where it holds them, which two equal readings share.
    func hash(into hasher: inout Hasher) {
        switch self {
        case let .array(inner), let .variable(inner), let .inout(inner), let .optional(inner):
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
    private func mayHoldExistential(in table: LoweredTypeTable, visited: inout Set<Int>) -> Bool {
        switch self {
        case .composition, .parameter(_, bounds: []):
            return true

        case let .array(inner), let .optional(inner), let .variable(inner), let .inout(inner):
            return inner.mayHoldExistential(in: table, visited: &visited)

        case let .dictionary(key, value):
            return key.mayHoldExistential(in: table, visited: &visited)
                || value.mayHoldExistential(in: table, visited: &visited)

        case let .struct(held):
            return held.fields.contains { field in field.mayHoldExistential(in: table, visited: &visited) }

        case let .named(row, arguments):
            if arguments.contains(where: { argument in argument.mayHoldExistential(in: table, visited: &visited) }) {
                return true
            }

            guard visited.insert(row).inserted else { return false }

            return table.declared(row, applied: arguments).mayHoldExistential(in: table, visited: &visited)

        case .any, .never, .null, .bool, .int, .wholeLiteral, .double, .string, .procedure, .parameter:
            return false
        }
    }

    // This type with each part `replaced` returns a value for read as that
    // value, and every other part walked into: what is held, keyed, taken and
    // returned, and what a struct is applied to.
    private func replacing(_ replaced: (LoweredType) -> LoweredType?) -> LoweredType {
        if let replacement = replaced(self) {
            return replacement
        }

        switch self {
        case let .array(element):
            return .array(element.replacing(replaced))

        case let .dictionary(key, value):
            return LoweredType(keyedBy: key.replacing(replaced), holding: value.replacing(replaced))

        case let .procedure(signature, constness, isolation):
            return .procedure(
                signature?.map { part in part.replacing(replaced) },
                constness: constness,
                isolation: isolation
            )

        case let .variable(inner):
            return .variable(inner.replacing(replaced))

        case let .inout(inner):
            return .inout(inner.replacing(replaced))

        case let .optional(inner):
            return .optional(inner.replacing(replaced))

        case let .named(row, arguments):
            return .named(row, arguments: arguments.map { argument in argument.replacing(replaced) })

        case .any, .never, .null, .bool, .int, .wholeLiteral, .double, .string, .struct, .composition, .parameter:
            return self
        }
    }

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
        case .optional: 14
        case .named: 15
        case .parameter: 16
        case .composition: 17
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

        case let (.optional(inner), .optional(other)):
            return .optional(inner.merged(with: other, in: table))

        case let (.optional(inner), other) where takesGiven && other != .null:
            return .optional(inner.merged(with: other, in: table))

        case let (other, .optional(inner)) where !takesGiven && other != .null:
            return .optional(other.merged(with: inner, in: table))

        default:
            return looser
        }
    }

    // The same at a position below, asking there which takes the other.
    private func merged(with given: LoweredType, in table: LoweredTypeTable) -> LoweredType {
        guard self != given else { return self }

        return merged(with: given, takingGiven: accepts(given, in: table), in: table)
    }

    // A type parameter the call site filled, or a composition, holding what
    // arrived to a contract by what the value reads as, in the sentence the
    // build refuses such a reading in: what the claims the table holds decide
    // is what a value may arrive as. It does not settle: a value stands as it
    // arrived.
    private func standing(
        _ value: Value,
        conformingTo name: Name,
        at path: @autoclosure () -> String,
        in table: LoweredTypeTable
    ) throws -> Value {
        let refusal = table.refusal(
            of: table.reading(of: value, conformingTo: name),
            conformingTo: name,
            as: "is"
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
        // closure no link resolved is refused here, at a door or a cast.
        guard case let .resolved(linked, types) = closure.resolution else {
            throw ArgumentError("\(path()): a closure no link resolved")
        }

        guard linked.readable(in: table) else {
            throw ArgumentError("\(path()): \(Linked.unreadable)")
        }

        // It is read as returning what its own signature says it returns, a
        // type parameter of the body that wrote it read as the closure holds
        // it.
        let given = LoweredType.procedure(
            LoweredProcedureType(parameters: linked.slots.map(\.type), returns: linked.returns, failing: linked.signature.failing),
            constness: linked.signature.constness,
            isolation: linked.signature.isolation
        ).replacingParameters(types)

        // What fills a type parameter a value arrived with standing is one no
        // run held, so the value is of no procedure type that writes a
        // signature. `Procedure` writes none, and every procedure is one.
        guard !given.namesParameter || required == nil else {
            throw ArgumentError(
                "\(path()): expected \(rendered(in: table)), got \(given.rendered(in: table)),"
                    + " whose type parameter no call filled"
            )
        }

        // A type parameter the slot names is filled by what arrived, the way
        // a call fills it at the build.
        let slot = LoweredType.procedure(required, constness: constness, isolation: isolation)
        let asked = slot.filling(Substitution(filling: [slot], against: [given], in: table).readings)

        guard asked.accepts(given, in: table) else {
            let got = switch linked.signature.effects.exceeding(effects(of: required, constness, isolation)) {
            case .constness: "a procedure not declared const"
            case .isolation: "a procedure that writes what another body could touch"
            case .failing, nil: given.rendered(in: table)
            }

            throw ArgumentError("\(path()): expected \(rendered(in: table)), got \(got)")
        }

        // A slot takes a procedure as it is, and a call of it hands its
        // return value on as it came.
        return value
    }

    // What a procedure type of these parts declares beside what it takes
    // and returns. Anything may fail out of one that writes no signature.
    private func effects(
        of signature: LoweredProcedureType?,
        _ constness: Constness,
        _ isolation: Isolation
    ) -> EffectSet {
        EffectSet(constness: constness, isolation: isolation, failing: signature?.failing ?? .anything)
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

    // The walk `written` takes: an expression standing where
    // this is read, through Optionals and the names around it, at the
    // depths a list, a dictionary and a struct hand on. `replacing` is asked first at
    // each depth, with the type read there, and returns what stands in place
    // of the expression, or nil to walk on.
    private func reaching(
        _ expression: Expression,
        in table: LoweredTypeTable,
        replacing: (LoweredType, Expression) -> Expression?
    ) -> Expression {
        switch self {
        case let .optional(inner), let .variable(inner), let .inout(inner):
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
