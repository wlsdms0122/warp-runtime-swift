//
//  TypeExpression.swift
//  Warp
//
//  Created by JSilver on 8/17/26.
//

import Foundation

// What a declaration says it takes. Distinct from `Value.nominal`, the type a
// value is an instance of: `Any` is only ever something a declaration says,
// and a type names what a list or a map holds where a value's own type names
// its kind alone.
//
// A type is an expression for the same reason an expression is: it composes.
// `Array<String>` is `array` applied to `String`, and a name is a name for one
// of these rather than a separate kind of thing, which is why a module declares
// a type the same way it declares anything, by binding a name to something.
//
// A struct type is declared, in `types`, and named here: a value fits with
// exactly its name. What arrives from outside gains fields, so the door it
// comes through fits it to the declaration first, and every other place
// holds a value as it is.
public indirect enum TypeExpression: Sendable, Equatable, CustomStringConvertible {
    // Nothing ever *is* `Any`. It is what a declaration says when it accepts
    // whatever it is handed.
    case any

    // The other end of `Any`. No value is ever of this type, which is how a
    // place control does not come back from is written down: a refusal answers
    // `Never` because it does not answer at all. Saying so is what keeps the
    // arm that leaves from having an opinion about what the arm that stays
    // holds, without it, one branch failing would cost the other its type.
    case never

    case null
    case bool
    case int
    case double
    case string

    // A list of one type. The element is always written, so `Array<Any>` says
    // out loud that anything is accepted. A declaration that accepts anything
    // reads differently from one that has not been written yet.
    case array(TypeExpression)

    // A map: keys of one type to values of one type, which a
    // `Value.dictionary` holds. The key's type answers `Hashable`.
    case dictionary(key: TypeExpression, value: TypeExpression)

    // A value that can be called: the types it is applied with, in position
    // order, and what it answers. Nil is a declaration that has not been
    // written ("some procedure") the way `Any` is for a value: a slot of it
    // takes any procedure, and a value of it stands where a procedure type
    // is read once a cast says what it is.
    //
    // Constness and isolation are requirements rather than claims. A declaration
    // never states its own (the builder derives both from what a body does) so
    // what is written here is what a slot asks of whatever fills it.
    case procedure(ProcedureType?, Constness = .unstated, Isolation = .unstated)

    // A field that a path may write through. Only a declared type's field is
    // one: `var Int` in a type declaration says a `set` or an `inout` path may
    // pass this field, and a field written without it stops such a path at the
    // build. What the value holds is the inner type; this is a fact about the
    // slot and never about a value.
    case variable(TypeExpression)

    // A parameter the call hands a variable to, in place: the callee writes the
    // caller's box, and the caller reads what was written when the call
    // returns. Only a parameter's type is one. The argument is a path headed by
    // a variable, and what arrives is the inner type.
    case `inout`(TypeExpression)

    // The declared type, or null. `?.` answers this.
    case nullable(TypeExpression)

    // A type a module declared, with the types it is applied to where its
    // declaration takes type parameters, in the order it lists them. Kept
    // rather than expanded so that a type may name itself (`Tree` with
    // children of `Array<Tree>` is a type, not a regress) which means
    // resolving one needs the table it was declared in.
    case named(Name, arguments: [TypeExpression] = [])

    // A type parameter, filled by whatever the call site puts there. The name
    // is what ties one signature's mentions together: `first` takes
    // `Array<some T>` and answers `some T`, so an array of strings answers a
    // string and the declaration never had to say which.
    //
    // It stands for a type rather than naming one, which is why it is not
    // `named`. A name is looked up in a table and this is worked out from the
    // call.
    //
    // The contracts bounding it are the signature's `bounds`, written once
    // for the name, so a mention carries the name alone.
    case parameter(name: Name)

    // A value of whatever type answers every contract here, written
    // `A & B`, with no name of its own to tie one mention to another. A set,
    // as a bound is: what it says is which contracts, so no order and no
    // repeat is written. One name in this position is written as the name and
    // read as this where the name is a contract's.
    case composition(Set<Name>)

    // The type that answers a contract, written `Self` in that contract's
    // procedures and nowhere else. A claim reads it as the type the claim is
    // about, and a call through the contract as one type parameter the
    // contract bounds, so every position writing it takes one type.
    case selfType

    // The type a type parameter's type gives under a name a contract asks,
    // written `some T.Item`, and `Self.Item` in a contract's procedures,
    // where the base is `Self`. What fills `T` decides it: the type member of
    // that name the type gives. Inside the declaration it is one type the
    // body does not know, held to what the contracts bounding `T` and the
    // signature say of it.
    //
    // One step from a type parameter, so the base is a parameter's name and
    // never another associated type.
    case associatedType(of: Name, name: Name)

    // MARK: - Property
    // The types the language names, by the spelling a document writes each
    // under. A spelling here is never a declaration's: what a document
    // declares stands beside these, and a reader answers one of these before
    // it looks for a declaration.
    public static let keywords: [Name: TypeExpression] = [
        TypeSpelling.any: .any,
        // A declaration a call never comes back from. Written out loud because
        // a procedure that always refuses is a procedure an author may declare.
        TypeSpelling.never: .never,
        TypeSpelling.null: .null,
        TypeSpelling.bool: .bool,
        TypeSpelling.int: .int,
        TypeSpelling.double: .double,
        TypeSpelling.string: .string,
        TypeSpelling.procedure: .procedure(nil),
        TypeSpelling.selfType: .selfType
    ]

    // The types the language names that a claim may be about, under the
    // name a claim writes and `Value.nominal` answers, each as the type a
    // claim about it stands for. A list and a map are named bare: every
    // list is a list whatever it holds, and a value does not say which
    // elements a slot declared it to hold. So a claim about one is about
    // every list, its element a type parameter nothing fills, which a
    // declaration answering the claim takes whatever it is.
    static let nominalTypes: [Name: TypeExpression] = [
        TypeSpelling.null: .null,
        TypeSpelling.bool: .bool,
        TypeSpelling.int: .int,
        TypeSpelling.double: .double,
        TypeSpelling.string: .string,
        TypeSpelling.array: .array(.parameter(name: TypeSpelling.selfElement)),
        TypeSpelling.dictionary: .dictionary(
            key: .parameter(name: TypeSpelling.selfKey),
            value: .parameter(name: TypeSpelling.selfElement)
        )
    ]

    // How the type reads in a message: a declaration an author wrote comes
    // back to them in the spelling they wrote it in.
    public var rendered: String {
        spelled { _ in nil }
    }

    // Every declared name this reaches: the types and contracts it names.
    //
    // A parameter's own name is not one of them. It stands for a type the
    // call decides rather than one a module declared, and what a walk through
    // one reached is rooted at that same type.
    var mentions: Set<Name> {
        switch self {
        case .any, .never, .null, .bool, .int, .double, .string:
            []

        case let .array(element):
            element.mentions

        case let .dictionary(key, value):
            key.mentions.union(value.mentions)

        case let .procedure(type, _, _):
            type?.mentions ?? []

        case let .variable(inner), let .inout(inner), let .nullable(inner):
            inner.mentions

        case let .named(name, arguments):
            arguments.reduce(into: [name]) { mentioned, argument in mentioned.formUnion(argument.mentions) }

        case let .composition(names):
            names

        case .parameter, .selfType, .associatedType:
            []
        }
    }

    // Every associated type named in here, by the label its lowering takes,
    // beside what it is an associated type of and the name it is asked under:
    // each one written, and each one written stands on.
    var associatedTypes: [Name: (of: Name, name: Name)] {
        switch self {
        case let .associatedType(of, name):
            return Self.associatedTypes(of: name.spelled(under: of))

        case let .array(element), let .nullable(element), let .variable(element), let .inout(element):
            return element.associatedTypes

        case let .dictionary(key, value):
            return key.associatedTypes.merging(value.associatedTypes) { first, _ in first }

        case let .procedure(type, _, _):
            return ((type?.parameters ?? []) + [type?.returns].compactMap { $0 }).reduce(into: [:]) { found, part in
                found.merge(part.associatedTypes) { first, _ in first }
            }

        case let .named(_, arguments):
            return arguments.reduce(into: [:]) { found, argument in found.merge(argument.associatedTypes) { first, _ in first } }

        case .any, .never, .null, .bool, .int, .double, .string, .parameter, .composition, .selfType:
            return [:]
        }
    }

    // The associated type under a label and each one it stands on, by label.
    static func associatedTypes(of label: Name) -> [Name: (of: Name, name: Name)] {
        var found: [Name: (of: Name, name: Name)] = [:]
        var next = label

        while let standing = next.associated {
            found[next] = standing
            next = standing.of
        }

        return found
    }

    // Every type parameter named in here.
    var parameterNames: Set<Name> {
        switch self {
        case let .parameter(name):
            return [name]

        case .composition, .selfType, .associatedType:
            return []

        case let .array(element), let .nullable(element):
            return element.parameterNames

        case let .dictionary(key, value):
            return key.parameterNames.union(value.parameterNames)

        case let .procedure(type, _, _):
            return type?.parameterNames ?? []

        case let .variable(inner), let .inout(inner):
            return inner.parameterNames

        case let .named(_, arguments):
            return arguments.reduce(into: []) { names, argument in names.formUnion(argument.parameterNames) }

        case .any, .never, .null, .bool, .int, .double, .string:
            return []
        }
    }

    // Whether anything in here is a type parameter. A declaration without one
    // is read as written.
    var isGeneric: Bool {
        switch self {
        // Both are types a call decides, and the deep question is only
        // whether this declaration has to be filled at all.
        case .parameter, .associatedType:
            return true

        case let .array(element), let .nullable(element):
            return element.isGeneric

        case let .dictionary(key, value):
            return key.isGeneric || value.isGeneric

        case let .procedure(type, _, _):
            return type?.isGeneric ?? false

        case let .variable(inner), let .inout(inner):
            return inner.isGeneric

        case let .named(_, arguments):
            return arguments.contains(where: \.isGeneric)

        case .any, .never, .null, .bool, .int, .double, .string, .composition, .selfType:
            return false
        }
    }

    // The type a slot's mark stands in front of, where it has one, and the type
    // itself otherwise. What arrives through `inout` is the inner type, and
    // every question about what fits asks that.
    //
    // No `default`: a mark nobody thought about must be a compile error here
    // rather than an answer of "no mark".
    var slotUnwrapped: TypeExpression {
        switch self {
        case let .inout(inner):
            return inner

        case .any, .never, .null, .bool, .int, .double, .string,
            .array, .dictionary, .procedure, .variable,
            .nullable, .named, .parameter, .associatedType, .composition, .selfType:
            return self
        }
    }

    // Whether a `?` on this says something new. It says nothing on what
    // already takes null, on `Never`, which no value is, and on a type
    // parameter, which stands for the whole type the call fills in.
    var takesQuestionMark: Bool {
        switch self {
        case .any, .null, .never, .parameter, .nullable:
            return false

        case .bool, .int, .double, .string, .array, .dictionary, .procedure, .variable,
            .inout, .named, .associatedType, .composition, .selfType:
            return true
        }
    }

    // Whether a `?` trailing this is written after parentheses around it: a
    // procedure type writing its signature or a modifier, whose spelling a
    // `?` would otherwise end inside.
    private var isGroupedBeforeQuestionMark: Bool {
        guard case let .procedure(type, constness, isolation) = self else { return false }

        return type != nil || constness == .const || isolation == .isolated
    }

    var isInout: Bool {
        if case .inout = self { return true }
        return false
    }

    var isVariable: Bool {
        if case .variable = self { return true }
        return false
    }

    // The type a field holds, whether or not a path may write through it.
    var fieldUnwrapped: TypeExpression {
        switch self {
        case let .variable(inner):
            return inner

        case .any, .never, .null, .bool, .int, .double, .string,
            .array, .dictionary, .procedure, .inout,
            .nullable, .named, .parameter, .associatedType, .composition, .selfType:
            return self
        }
    }

    public var description: String { rendered }

    // MARK: - Initializer
    // MARK: - Public
    // The spelling a document writes the type as. `bound` answers the
    // contracts a type parameter is written beside at a naming, asked of each
    // naming in the order the spelling writes them, and nil where it is
    // written bare.
    public func spelled(bounding bound: (Name) -> Set<Name>?) -> String {
        switch self {
        case .any:
            return TypeSpelling.any.spelling

        case .never:
            return TypeSpelling.never.spelling

        case .null:
            return TypeSpelling.null.spelling

        case .bool:
            return TypeSpelling.bool.spelling

        case .int:
            return TypeSpelling.int.spelling

        case .double:
            return TypeSpelling.double.spelling

        case .string:
            return TypeSpelling.string.spelling

        case let .parameter(name):
            guard let contracts = bound(name) else { return "\(TypeSpelling.some) \(name)" }

            return "\(TypeSpelling.some) \(name): \(Self.joined(contracts))"

        case let .composition(names):
            return Self.joined(names)

        case .selfType:
            return TypeSpelling.selfType.spelling

        case let .associatedType(of, name) where of.root == TypeSpelling.selfType:
            return name.spelled(under: of).spelling

        case let .associatedType(of, name):
            return "\(TypeSpelling.some) \(name.spelled(under: of))"

        case let .variable(inner):
            return "\(TypeSpelling.variable) \(inner.spelled(bounding: bound))"

        case let .inout(inner):
            return "\(TypeSpelling.inout) \(inner.spelled(bounding: bound))"

        case let .procedure(type, constness, isolation):
            let modifiers = [
                constness == .const ? TypeSpelling.const : nil,
                isolation == .isolated ? TypeSpelling.isolated : nil
            ]
            .compactMap { modifier in modifier.map { modifier in "\(modifier) " } }
            .joined()

            guard let type else { return "\(modifiers)\(TypeSpelling.procedure)" }

            let parameters = type.parameters.map { parameter in parameter.spelled(bounding: bound) }
            let throwing = switch type.failing {
            case .unstated: " \(TypeSpelling.throws)"
            case let .these(failures) where failures.isEmpty: ""
            case let .these(failures): " \(TypeSpelling.throws)(\(failures.sorted().joined(separator: ", ")))"
            }

            return "\(modifiers)(\(parameters.joined(separator: ", ")))\(throwing)"
                + " -> \((type.returns ?? .any).spelled(bounding: bound))"

        case let .array(element):
            return "\(TypeSpelling.array)<\(element.spelled(bounding: bound))>"

        case let .dictionary(key, value):
            return "\(TypeSpelling.dictionary)<\(key.spelled(bounding: bound)), \(value.spelled(bounding: bound))>"

        case let .named(name, arguments):
            guard !arguments.isEmpty else { return name.spelling }

            return "\(name.spelling)<\(arguments.map { argument in argument.spelled(bounding: bound) }.joined(separator: ", "))>"

        // Everything after `->` is a procedure's answer, and a modifier stands
        // in front of the whole type after it, so a `?` meaning either one
        // whole is written after parentheses around it.
        case let .nullable(inner):
            guard inner.isGroupedBeforeQuestionMark else { return "\(inner.spelled(bounding: bound))?" }

            return "(\(inner.spelled(bounding: bound)))?"
        }
    }

    // The same type with `Self` written as `type` wherever it stands: what a
    // contract's procedure says once a call through the contract reads `Self`
    // as one of its type parameters.
    func replacingSelf(with type: TypeExpression) -> TypeExpression {
        switch self {
        case .selfType:
            return type

        case let .array(element):
            return .array(element.replacingSelf(with: type))

        case let .dictionary(key, value):
            return .dictionary(key: key.replacingSelf(with: type), value: value.replacingSelf(with: type))

        case let .procedure(procedure, constness, isolation):
            return .procedure(procedure?.replacingSelf(with: type), constness, isolation)

        case let .variable(inner):
            return .variable(inner.replacingSelf(with: type))

        case let .inout(inner):
            return .inout(inner.replacingSelf(with: type))

        case let .nullable(inner):
            return .nullable(inner.replacingSelf(with: type))

        case let .named(name, arguments):
            return .named(name, arguments: arguments.map { argument in argument.replacingSelf(with: type) })

        // An associated type of `Self` stays one: a call through the contract
        // reads `Self` as its type parameter, whose associated type it then is.
        case .any, .never, .null, .bool, .int, .double, .string, .parameter, .composition,
            .associatedType:
            return self
        }
    }

    // Whether null is one of this type's values. The fact `T?` exists to
    // declare.
    //
    // `Any` is not this. A slot declaring nothing accepts a null that arrives,
    // but it does not *spell* null as a value.
    func declaresNull(in types: TypeTable) -> Bool {
        lowered(in: types.loweredTypes).declaresNull(in: types.loweredTypes)
    }

    // MARK: - Private
    // Contracts a bound or a composition names, in one order.
    private static func joined(_ names: Set<Name>) -> String {
        names.sorted().map(\.spelling).joined(separator: " & ")
    }
}
