//
//  TypeExpression.swift
//  Warp
//
//  Created by JSilver on 8/17/26.
//

import Foundation

// What a declaration says it takes. Distinct from `ValueType`, which is what a
// value *is*: `Any` is only ever something a declaration says, and a type
// names an element, fields, or a declared name where a value has none.
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

    // The declared type, or null. The one union the language has, and it is
    // null-only on purpose. `?.` answers this; a general union would put back
    // the "is it this or that" question the whole type system exists to
    // answer once.
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
    // The names bound it: a parameter bounded by `Comparable` takes only
    // what answers the contract by that name, and one bounded by several
    // takes only what answers every one of them. A bound is a declaration
    // like a type (a module binds a name to the procedures it asks) so a
    // signature writes the names. In name order, so one set has one
    // spelling.
    case parameter(name: Name, bounds: [Name] = [])

    // A value of whatever type answers every contract here, written
    // `A & B`, with no name of its own to tie one mention to another. One
    // name in this position is written as the name and read as this where
    // the name is a contract's.
    case composition([Name])

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
    public static let nominalTypes: [Name: TypeExpression] = [
        TypeSpelling.null: .null,
        TypeSpelling.bool: .bool,
        TypeSpelling.int: .int,
        TypeSpelling.double: .double,
        TypeSpelling.string: .string,
        TypeSpelling.array: .array(.parameter(name: TypeSpelling.selfElement)),
        TypeSpelling.dictionary: .dictionary(.parameter(name: TypeSpelling.selfElement)),
        TypeSpelling.procedure: .procedure(nil)
    ]

    // Bytes are a list of whole numbers in a compact spelling, so the type of
    // one is the type of that list. What a procedure the host answers
    // declares where it takes or answers bytes.
    public static let bytes = TypeExpression.array(.int)

    // How the type reads in a message. A declaration an author wrote should come
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

        // The diagnostic voice, not the notation. `rendered` tells an author
        // what a type *is*, and the procedure case below already writes a type
        // no document spells. So the bound rides along: `some N` alone would
        // hide the one fact a bound refusal is about. What a document spells is
        // the writer's question, and the writer answers it with `bounds`.
        case let .parameter(name, bounds):
            return bounds.isEmpty
                ? "some \(name)"
                : "some \(name): \(bounds.map(\.spelling).joined(separator: " & "))"

        case let .composition(names):
            return names.map(\.spelling).joined(separator: " & ")

        case .selfType:
            return TypeSpelling.selfType.spelling

        // Spelled as what it is. The type reached by that path. No document
        // writes this, so the spelling answers to the message alone: an author
        // reading a refusal about `item.a` should see where it came from.
        case let .projection(of, path):
            return "some \(Path([.key(of)] + path.segments).rendered)"

        case let .variable(inner):
            return "var \(inner.rendered)"

        case let .inout(inner):
            return "inout \(inner.rendered)"

        case let .procedure(type, constness, isolation):
            let spelling = [
                constness == .const ? "const" : nil,
                isolation == .isolated ? "isolated" : nil,
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

    // The refusal a cast earns for naming a type there is nothing to read. Nil
    // where the type names one. Said here, once, because a cast's claim is
    // judged in two places: the declaration scan that sees every cast in every
    // module, and the walk that knows what the value reads as.
    //
    // Each of the three says its own, because a refusal carries its reason:
    // telling an author that `T` names no type is false. A call names it,
    // elsewhere. A type parameter anywhere in the claim is the third, since
    // nothing in a body fills it and the run would settle what arrived against
    // no type there.
    var unreadableClaim: String? {
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

        if isGeneric {
            return "reads as \(rendered), whose type the call"
                + " decides. A cast names a type here, and this one is named"
                + " somewhere else"
        }

        return nil
    }

    // Every declared name this reaches: the types it names, and the
    // contracts it bounds a parameter by.
    //
    // A parameter's own name is not one of them. It stands for a type the
    // call decides rather than one a module declared, and what a walk through
    // one reached is rooted at that same undeclared type.
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

        case let .parameter(_, bounds):
            Set(bounds)

        case let .composition(names):
            Set(names)

        case .selfType, .projection:
            []
        }
    }

    // Every type parameter mentioned in here, occurrence by occurrence, each
    // with the bounds it carries.
    var parameterOccurrences: [ParameterOccurrence] {
        switch self {
        case let .parameter(name, bounds):
            return [ParameterOccurrence(name: name, bounds: bounds)]

        case .projection, .composition, .selfType:
            return []

        case let .array(element), let .dictionary(element), let .nullable(element):
            return element.parameterOccurrences

        case let .record(fields):
            return fields.values.flatMap { field in field.parameterOccurrences }

        case let .procedure(type, _, _):
            return type?.parameterOccurrences ?? []

        case let .variable(inner), let .inout(inner):
            return inner.parameterOccurrences

        case .any, .never, .null, .bool, .int, .double, .string, .named:
            return []
        }
    }

    // Whether anything in here is a type parameter. A declaration without one
    // is read the way it always was, so nothing pays for a feature it does not
    // use.
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
    public var slotUnwrapped: TypeExpression {
        switch self {
        case let .inout(inner):
            return inner

        case .any, .never, .null, .bool, .int, .double, .string,
            .array, .dictionary, .record, .procedure, .variable,
            .nullable, .named, .parameter, .projection, .composition, .selfType:
            return self
        }
    }

    public var isInout: Bool {
        if case .inout = self { return true }
        return false
    }

    public var isVariable: Bool {
        if case .variable = self { return true }
        return false
    }

    // The type a field holds, whether or not a path may write through it.
    public var fieldUnwrapped: TypeExpression {
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
    // What this type accepts, settled to the declared representation, or a
    // refusal saying which part disagreed. `at` is the path into the value so
    // the message names the field rather than the whole argument. A value a
    // host holds comes from outside, so a nameless record where a declared
    // record is read takes the name first, as a cast does; a field the type
    // does not declare is not left out.
    public func settling(
        _ value: Value,
        at path: @autoclosure () -> String,
        in types: TypeTable = .empty
    ) throws -> Value {
        let type = lowered(in: types.loweredTypes)

        return try type.settling(type.named(value, in: types.loweredTypes), at: path(), in: types.loweredTypes)
    }

    // The same type with every name it holds walked through to what that name
    // declares. At every depth, not only the outermost.
    //
    // A name is a spelling, and two spellings of one type are one type: a
    // reading of `{ inner: Person }` and a claim of `{ inner: { name: string } }`
    // are the same thing said twice. Resolving only the outermost made that
    // depend on where the author happened to write the name, so the same
    // question got two answers depending on nesting.
    func resolved(in types: TypeTable) -> TypeExpression {
        resolved(in: types, assuming: [])
    }

    // The occurrence side of `Signature.bounded(by:)`, walked through every
    // place a type parameter may sit. A nested procedure type's parameters
    // included, because they are the outer signature's own slots.
    func bounded(by bounds: [Name: [Name]]) -> TypeExpression {
        switch self {
        case let .parameter(name, own):
            return .parameter(name: name, bounds: own.isEmpty ? bounds[name] ?? [] : own)

        case .projection, .composition, .selfType:
            return self

        case let .array(element):
            return .array(element.bounded(by: bounds))

        case let .dictionary(entry):
            return .dictionary(entry.bounded(by: bounds))

        case let .record(fields):
            return .record(fields.mapValues { field in field.bounded(by: bounds) })

        case let .procedure(type, constness, isolation):
            return .procedure(type?.bounded(by: bounds), constness, isolation)

        case let .nullable(inner):
            return .nullable(inner.bounded(by: bounds))

        case let .variable(inner):
            return .variable(inner.bounded(by: bounds))

        case let .inout(inner):
            return .inout(inner.bounded(by: bounds))

        case .any, .never, .null, .bool, .int, .double, .string, .named:
            return self
        }
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
    // `Any` is not this. An undeclared type accepts a null that arrives, but
    // it does not *spell* null as a value.
    public func declaresNull(in types: TypeTable) -> Bool {
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
    public func accepts(_ other: TypeExpression, in types: TypeTable = .empty) -> Bool {
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
