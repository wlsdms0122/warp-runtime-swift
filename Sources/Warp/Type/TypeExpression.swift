//
//  TypeExpression.swift
//  Warp
//
//  Created by JSilver on 8/17/26.
//

import Foundation

// What a declaration says it takes. Distinct from `Value.nominal`, the type a
// value is an instance of: `Any` is only ever something a declaration says,
// and a type names what a list or a dictionary holds where a value's own type names
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
    // place control does not come back from is written down: a refusal returns
    // `Never` because it does not return at all.
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

    // A dictionary: keys of one type to values of one type, which a
    // `Value.dictionary` holds. The key's type conforms to `Hashable`.
    case dictionary(key: TypeExpression, value: TypeExpression)

    // A value that can be called: the types it is applied with, in position
    // order, and what it returns. Nil is a declaration that has not been
    // written ("some procedure") the way `Any` is for a value: a slot of it
    // takes any procedure, and a value of it stands where a procedure type
    // is read once a cast says what it is.
    //
    // Constness and isolation are what a slot asks of whatever fills it, and
    // what a declaration's signature says of itself where it is read as a
    // value.
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

    // The Optional of the declared type. `?.` returns this.
    case optional(TypeExpression)

    // A type a module declared, with the types it is applied to where its
    // declaration takes type parameters, in the order it lists them. Kept
    // rather than expanded so that a type may name itself (`Tree` with
    // children of `Array<Tree>` is a type, not a regress) which means
    // resolving one needs the table it was declared in.
    case named(Name, arguments: [TypeExpression] = [])

    // A type parameter, filled by whatever the call site puts there. The name
    // is what ties one signature's mentions together: `first` takes
    // `Array<some T>` and returns `some T`, so an array of strings returns a
    // string and the declaration never had to say which.
    //
    // It stands for a type rather than naming one, which is why it is not
    // `named`. A name is looked up in a table and this is worked out from the
    // call.
    //
    // The contracts bounding it are the signature's `bounds`, written once
    // for the name, so a mention carries the name alone.
    case parameter(name: Name)

    // A value of whatever type conforms to every contract here, written
    // `A & B`, with no name of its own to tie one mention to another. A set,
    // as a bound is: what it says is which contracts, so no order and no
    // repeat is written. One name in this position is written as the name and
    // read as this where the name is a contract's.
    case composition(Set<Name>)

    // The type that conforms to a contract, written `Self` in that contract's
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
    case associatedType(AssociatedType)

    // MARK: - Property
    // The types the language names, by the spelling a document writes each
    // under. A spelling here is never a declaration's: what a document
    // declares stands beside these, and a reader resolves one of these before
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
    // name a claim writes and `Value.nominal` returns, each as the type a
    // claim about it stands for. A list and a dictionary are named bare: every
    // list is a list whatever it holds, and a value does not say which
    // elements a slot declared it to hold. So a claim about one is about
    // every list, its element a type parameter nothing fills, which a
    // declaration satisfying the claim takes whatever it is.
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

    // The names of the types the language declares, which a claim or a
    // member may be about without a document declaring them: those
    // `nominalTypes` holds, and the Optional, which a head writes by its `?`
    // and so always applies.
    static let languageTypeNames: Set<Name> = Set(nominalTypes.keys).union([TypeSpelling.optional])

    // How the type reads in a message: a declaration an author wrote comes
    // back to them in the spelling they wrote it in.
    public var rendered: String {
        TypeSyntax(self).spelling
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

        case let .variable(inner), let .inout(inner), let .optional(inner):
            inner.mentions

        case let .named(name, arguments):
            arguments.reduce(into: [name]) { mentioned, argument in mentioned.formUnion(argument.mentions) }

        case let .composition(names):
            names

        case .parameter, .selfType, .associatedType:
            []
        }
    }

    // Every associated type named in here, by the label its lowering takes:
    // each one written, and each one written stands on.
    var associatedTypes: [Name: AssociatedType] {
        switch self {
        case let .associatedType(associated):
            return associated.chain

        case let .array(element), let .optional(element), let .variable(element), let .inout(element):
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

    // Every type parameter named in here.
    var parameterNames: Set<Name> {
        switch self {
        case let .parameter(name):
            return [name]

        case .composition, .selfType, .associatedType:
            return []

        case let .array(element), let .optional(element):
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

        case let .array(element), let .optional(element):
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
    // rather than a result of "no mark".
    var slotUnwrapped: TypeExpression {
        switch self {
        case let .inout(inner):
            return inner

        case .any, .never, .null, .bool, .int, .double, .string,
            .array, .dictionary, .procedure, .variable,
            .optional, .named, .parameter, .associatedType, .composition, .selfType:
            return self
        }
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
            .optional, .named, .parameter, .associatedType, .composition, .selfType:
            return self
        }
    }

    public var description: String { rendered }

    // MARK: - Initializer
    // MARK: - Public
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

        case let .optional(inner):
            return .optional(inner.replacingSelf(with: type))

        case let .named(name, arguments):
            return .named(name, arguments: arguments.map { argument in argument.replacingSelf(with: type) })

        // An associated type of `Self` stays one: a call through the contract
        // reads `Self` as its type parameter, whose associated type it then is.
        case .any, .never, .null, .bool, .int, .double, .string, .parameter, .composition,
            .associatedType:
            return self
        }
    }

    // Whether this is `Null` or an Optional, a type whose values a none
    // stands among by its declaration: `Null`'s one value, or the
    // Optional's none.
    //
    // `Any` is not this. A slot declaring nothing accepts a null that arrives,
    // but it does not *spell* null as a value.
    func declaresNone(in types: TypeTable) -> Bool {
        lowered(in: types.loweredTypes).declaresNone(in: types.loweredTypes)
    }

    // MARK: - Private
}
