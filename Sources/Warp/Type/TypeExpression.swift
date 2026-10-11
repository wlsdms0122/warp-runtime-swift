//
//  TypeExpression.swift
//  Warp
//
//  Created by JSilver on 8/17/26.
//

import Foundation

// What a declaration says it takes. Distinct from `Value.nominal`, the type a
// value is an instance of: `Any` is only ever something a declaration says,
// and a type names an element, fields, or a declared name where a value has
// none.
//
// A type is an expression for the same reason an expression is: it composes.
// `Array<String>` is `array` applied to `String`, and a name is a name for one
// of these rather than a separate kind of thing, which is why a module declares
// a type the same way it declares anything, by binding a name to something.
//
// A record type is exact: a value fits with exactly its name, or exactly its
// fields where it has none. What arrives from outside gains fields, so the door
// it comes through fits it to the declaration first, and every other place
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

    // Names to one type: a record whose field names are data rather than
    // declaration, which a `Value.dictionary` holds.
    case dictionary(TypeExpression)

    // Named fields with types, exactly the ones a value holds.
    case record([Name: TypeExpression])

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
    // link. What the value holds is the inner type; this is a fact about the
    // slot and never about a value.
    case variable(TypeExpression)

    // A parameter the call hands a variable to, in place: the callee writes the
    // caller's box, and the caller reads what was written when the call
    // returns. Only a parameter's type is one. The argument is a path headed by
    // a variable, and what arrives is the inner type.
    case `inout`(TypeExpression)

    // The declared type, or null. `?.` answers this.
    case nullable(TypeExpression)

    // A type a module declared. Kept rather than expanded so that a type may
    // name itself (`Tree` with children of `Array<Tree>` is a type, not a
    // regress) which means resolving one needs the table it was declared in.
    case named(Name)

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

    // What a walk *through* a type parameter reached. Still a type the call
    // decides (a dot on it stands as written, the way a dot on the parameter
    // does) and not the parameter, because a field of an unknown type is a
    // different unknown. It carries no bound for the same reason: what a
    // bound asks was proven of the parameter, and nothing was proven of what
    // was read out of it.
    //
    // Apart from `parameter` rather than spelled into one. Both are types the
    // link cannot see, but only one of them is a slot a call fills, and the
    // difference has to survive every way a type is built: a declaration is
    // written in a document *and* assembled in a host, and a rule the reader
    // alone enforces is a rule the host walks around. Two cases is that rule
    // stated where nothing can walk around it.
    //
    // The parameter it was read out of, and the path from there, together,
    // because that pair is the whole of what this is. Two walks that land on
    // the same field of the same unknown are one type, and two fields of it
    // are two.
    //
    // Rooted at the parameter and not at the name a body happened to read
    // through: `of: some T` and `also: some T` are one unknown, so their
    // `.inner` is one field, and a step given a name along the way (`held =
    // of.inner` and then `held.count`) has to arrive where the unbroken walk
    // arrives.
    //
    // The path is segments and not their spelling for the same reason: `.a`
    // and `?.a` land on one field, and a spelling would make them two unknowns
    // that never meet.
    case projection(of: Name, path: Path)

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

    // The types the language names that a value is an instance of, under
    // the name a claim writes and `Value.nominal` answers, each as the type
    // a claim about it stands for. A list and a map are named bare: every
    // list is a list whatever it holds, and a value does not say which
    // elements a slot declared it to hold. So a claim about one is about
    // every list, its element a type parameter nothing fills, which a
    // declaration answering the claim takes whatever it is. A claim about
    // `Procedure` is the same about every procedure, whatever it takes and
    // answers.
    static let nominalTypes: [Name: TypeExpression] = [
        TypeSpelling.null: .null,
        TypeSpelling.bool: .bool,
        TypeSpelling.int: .int,
        TypeSpelling.double: .double,
        TypeSpelling.string: .string,
        TypeSpelling.array: .array(.parameter(name: TypeSpelling.selfElement)),
        TypeSpelling.dictionary: .dictionary(.parameter(name: TypeSpelling.selfElement)),
        TypeSpelling.procedure: .procedure(nil)
    ]

    // How the type reads in a message: a declaration an author wrote comes
    // back to them in the spelling they wrote it in.
    public var rendered: String {
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
            return "\(TypeSpelling.some) \(name)"

        case let .composition(names):
            return names.sorted().map(\.spelling).joined(separator: " & ")

        case .selfType:
            return TypeSpelling.selfType.spelling

        // Spelled as what it is, the type reached by that path. No document
        // writes this, so the spelling answers to the message alone: a refusal
        // about `item.a` names where it came from.
        case let .projection(of, path):
            return "\(TypeSpelling.some) \(Path([.key(of)] + path.segments).rendered)"

        case let .variable(inner):
            return "\(TypeSpelling.variable) \(inner.rendered)"

        case let .inout(inner):
            return "\(TypeSpelling.inout) \(inner.rendered)"

        case let .procedure(type, constness, isolation):
            let spelling = [
                constness == .const ? TypeSpelling.const.spelling : nil,
                isolation == .isolated ? TypeSpelling.isolated.spelling : nil,
                TypeSpelling.procedure.spelling
            ]
            .compactMap { part in part }
            .joined(separator: " ")

            guard let type else { return spelling }

            let written = type.parameters.map(\.rendered)

            // Rendered as what it accepts, because a message is about what would
            // have fit. Which half was written is a fact about the source rather
            // than about the value being refused.
            return "\(spelling)<(\(written.joined(separator: ", ")))"
                + " -> \((type.returns ?? .any).rendered)>"

        case let .array(element):
            return "Array<\(element.rendered)>"

        case let .dictionary(entry):
            return "Dictionary<\(entry.rendered)>"

        case let .record(fields):
            let written = fields
                .sorted { left, right in left.key < right.key }
                .map { name, field in "\(name): \(field.rendered)" }

            return "{ \(written.joined(separator: ", ")) }"

        case let .named(name):
            return name.spelling

        case let .nullable(inner):
            return "\(inner.rendered)?"
        }
    }

    // The refusal a cast earns for naming a type there is nothing to read, once
    // its names are resolved. Nil where the type names one. Each of the two
    // says its own, because a refusal carries its reason.
    var unreadableCast: String? {
        if self == .any {
            return "reads as \(rendered), which declares nothing."
                + " A cast names the type a value is read as, and `Any` is"
                + " the absence of one"
        }

        if self == .never {
            return "reads as \(rendered), which no value is."
                + " A cast names the type a value turns out to have, and"
                + " nothing arrives to have this one"
        }

        return nil
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

        case let .dictionary(entry):
            entry.mentions

        case let .record(fields):
            fields.values.reduce(into: Set()) { mentioned, field in
                mentioned.formUnion(field.mentions)
            }

        case let .procedure(type, _, _):
            type?.mentions ?? []

        case let .variable(inner), let .inout(inner), let .nullable(inner):
            inner.mentions

        case let .named(name):
            [name]

        case let .composition(names):
            names

        case .parameter, .selfType, .projection:
            []
        }
    }

    // Every type parameter named in here.
    var parameterNames: Set<Name> {
        switch self {
        case let .parameter(name):
            return [name]

        case .projection, .composition, .selfType:
            return []

        case let .array(element), let .dictionary(element), let .nullable(element):
            return element.parameterNames

        case let .record(fields):
            return fields.values.reduce(into: Set()) { named, field in named.formUnion(field.parameterNames) }

        case let .procedure(type, _, _):
            return type?.parameterNames ?? []

        case let .variable(inner), let .inout(inner):
            return inner.parameterNames

        case .any, .never, .null, .bool, .int, .double, .string, .named:
            return []
        }
    }

    // Whether anything in here is a type parameter. A declaration without one
    // is read as written, so nothing pays for a feature it does not use.
    var isGeneric: Bool {
        switch self {
        // Both are types a call decides, and the deep question is only
        // whether this declaration has to be filled at all.
        case .parameter, .projection:
            return true

        case let .array(element), let .dictionary(element), let .nullable(element):
            return element.isGeneric

        case let .record(fields):
            return fields.values.contains { field in field.isGeneric }

        case let .procedure(type, _, _):
            return type?.isGeneric ?? false

        case let .variable(inner), let .inout(inner):
            return inner.isGeneric

        case .any, .never, .null, .bool, .int, .double, .string, .named, .composition, .selfType:
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
            .array, .dictionary, .record, .procedure, .variable,
            .nullable, .named, .parameter, .projection, .composition, .selfType:
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

        case .bool, .int, .double, .string, .array, .dictionary, .record, .procedure, .variable,
            .inout, .named, .projection, .composition, .selfType:
            return true
        }
    }

    // Whether a document writes this type as a string, which a `?` trails and
    // a slot mark stands in front of. An inline record and a procedure type
    // that writes its signature are written as a mapping under one key, and
    // so is a list or a map of one of those.
    var hasSpelling: Bool {
        switch self {
        case .any, .never, .null, .bool, .int, .double, .string, .named, .parameter, .composition,
            .selfType, .projection:
            return true

        case let .procedure(type, _, _):
            return type == nil

        case .record:
            return false

        case let .array(inner), let .dictionary(inner), let .nullable(inner), let .variable(inner),
            let .inout(inner):
            return inner.hasSpelling
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
            .array, .dictionary, .record, .procedure, .inout,
            .nullable, .named, .parameter, .projection, .composition, .selfType:
            return self
        }
    }

    public var description: String { rendered }

    // MARK: - Initializer
    // MARK: - Public
    // The same type with every name it holds walked through to what that name
    // declares. At every depth, not only the outermost.
    func resolved(in types: TypeTable) -> TypeExpression {
        resolved(in: types, assuming: [])
    }

    // The same type with `Self` written as `type` wherever it stands: what a
    // contract's procedure says once a claim names the type answering it, or
    // once a call through the contract reads `Self` as one of its type
    // parameters.
    func replacingSelf(with type: TypeExpression) -> TypeExpression {
        switch self {
        case .selfType:
            return type

        case let .array(element):
            return .array(element.replacingSelf(with: type))

        case let .dictionary(entry):
            return .dictionary(entry.replacingSelf(with: type))

        case let .record(fields):
            return .record(fields.mapValues { field in field.replacingSelf(with: type) })

        case let .procedure(procedure, constness, isolation):
            return .procedure(procedure?.replacingSelf(with: type), constness, isolation)

        case let .variable(inner):
            return .variable(inner.replacingSelf(with: type))

        case let .inout(inner):
            return .inout(inner.replacingSelf(with: type))

        case let .nullable(inner):
            return .nullable(inner.replacingSelf(with: type))

        case .any, .never, .null, .bool, .int, .double, .string, .named, .parameter, .composition,
            .projection:
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

    // Whether a value of `other` may stand where this is declared. Exact on
    // records, a declared one by its name and a nameless one by its fields,
    // and one-directional: `Any` on the left accepts anything because nothing
    // was declared, and a value read as `Any` on the right stands only where
    // `Any` is declared, until a cast says what it is.
    //
    // This is the half of checking the builder can do. What a body computes is
    // not readable from the text, but what a *call* answers is: it is the
    // callee's declaration, and a declaration is text.
    func accepts(_ other: TypeExpression, in types: TypeTable = .empty) -> Bool {
        lowered(in: types.loweredTypes).accepts(other.lowered(in: types.loweredTypes), in: types.loweredTypes)
    }

    // MARK: - Private
    // A name already being walked through stands as itself. A type may name
    // itself (`Tree` holding `Array<Tree>` is a declared type) so a walk that
    // expanded every name at every depth would chase one forever. The link
    // refuses *cyclic name chains*, which makes a walk that only follows names
    // finite; this one goes into fields as well, so it is outside that
    // guarantee and carries its own, the way `accepts` does.
    private func resolved(in types: TypeTable, assuming: Set<Name>) -> TypeExpression {
        switch self {
        case let .named(name):
            guard !assuming.contains(name), let declared = types.types[name] else {
                return self
            }

            return declared.resolved(in: types, assuming: assuming.union([name]))

        case let .array(element):
            return .array(element.resolved(in: types, assuming: assuming))

        case let .dictionary(element):
            return .dictionary(element.resolved(in: types, assuming: assuming))

        case let .nullable(element):
            return .nullable(element.resolved(in: types, assuming: assuming))

        case let .record(fields):
            return .record(fields.mapValues { field in
                field.resolved(in: types, assuming: assuming)
            })

        default:
            return self
        }
    }
}
