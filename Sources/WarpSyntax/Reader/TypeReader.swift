//
//  TypeReader.swift
//  WarpSyntax
//
//  Created by JSilver on 8/17/26.
//

import Foundation
import Warp

// How a document spells a type: as a string, which `TypeParser` cuts into
// its syntax and this judges as the type it says.
//
//   String / Any / Procedure  . A built-in, by its own name
//   Array<String>             . A built-in applied to another type
//   Dictionary<String, Task>  . The same, for a dictionary: its key's type and its
//                                value's
//   Task                      . A name some module declares
//   Box<Int>                  . A struct some module declares, applied to
//                                the types its type parameters stand for
//   (Int, String) throws(aborted) -> Bool
//                             . A procedure: the types it is called with,
//                                what it may fail with, and after `->` what
//                                it returns. Bare `Procedure` says only that
//                                it is one
//
// A struct is a structure a module declares under `types`, and a type names
// it.
struct TypeReader {
    // A built-in taking other types between its brackets.
    enum GenericBuiltin: CaseIterable {
        case array
        case dictionary

        // MARK: - Property
        var spelling: String {
            switch self {
            case .array: TypeSpelling.array.spelling
            case .dictionary: TypeSpelling.dictionary.spelling
            }
        }

        // What its spelling writes between the brackets.
        var arguments: String {
            switch self {
            case .array: "one type, its element's: `Array<String>`"
            case .dictionary: "two types, its key's and its value's: `Dictionary<String, Int>`"
            }
        }

        // MARK: - Initializer
        init?(spelling: String) {
            guard let builtin = Self.allCases.first(where: { builtin in builtin.spelling == spelling }) else {
                return nil
            }

            self = builtin
        }

        // MARK: - Public
        // This applied to these, or nil where they are not as many as it
        // takes.
        func applied(to inner: [TypeExpression]) -> TypeExpression? {
            switch (self, inner.count) {
            case (.array, 1): .array(inner[0])
            case (.dictionary, 2): .dictionary(key: inner[0], value: inner[1])
            default: nil
            }
        }

        // MARK: - Private
    }

    // A type parameter a type names, `some T`, beside the contracts a bound
    // written there holds it to and where it was written.
    struct Naming {
        let name: Name
        let bound: Set<Name>?
        let steps: [Place.Step]
    }

    // What a type's string writes: the type, and the type parameters it
    // names in the order the reading meets them, a procedure type's and a
    // dictionary type's included. Taken through `unbounded()` where no bound may
    // stand, and with `namings` in a slot, which a bound may stand beside.
    struct Written: Decodable {
        // MARK: - Property
        let type: TypeExpression
        let namings: [Naming]

        // MARK: - Initializer
        // A type's own refusals do not know where in a document they
        // happened, and every one of them arrives here, so the place is put
        // on them in one statement rather than in whichever branch threw.
        init(from decoder: Decoder) throws {
            guard let written = try? decoder.singleValueContainer().decode(String.self) else {
                throw ReadingError(TypeReader.unread, at: decoder.steps)
            }

            do {
                self = try TypeReader(at: decoder.steps).written(written)
            } catch let error as TypeFormError {
                throw ReadingError(error.message, at: decoder.steps)
            }
        }

        init(_ type: TypeExpression, namings: [Naming]) {
            self.type = type
            self.namings = namings
        }

        // MARK: - Public
        // The type, where nothing it names is bounded here. A type parameter
        // is bounded where it is introduced, and a type read through this is
        // not where one is.
        func unbounded() throws -> TypeExpression {
            if let bounded = namings.first(where: { naming in naming.bound != nil }) {
                throw ReadingError(TypeReader.unintroduced(bounded.name), at: bounded.steps)
            }

            return type
        }

        // MARK: - Private
    }

    // MARK: - Property
    // Where its string is written: the type stands as deep as the containers
    // these steps enter.
    let steps: [Place.Step]

    // The type parameters the walk has met so far.
    private var namings: [Naming] = []

    // What a type written as anything but a string is refused with.
    static let unread = "a type is written as a string like `String`, `Array<String>`, `Task` or"
        + " `(Int) -> Bool`. A struct is declared under its name in `types` as `{ struct: { … } }`,"
        + " and named everywhere else"

    // MARK: - Initializer
    init(at steps: [Place.Step] = []) {
        self.steps = steps
    }

    // MARK: - Public
    // What a type's spelling writes: the type, and the names it introduces.
    func written(_ text: String) throws -> Written {
        var reader = self
        let type = try reader.judged(try reader.parsed(text))

        return Written(type, namings: reader.namings)
    }

    // The first naming written with a bound after its name was already
    // named, which the caller refuses in its own words.
    func renaming(in namings: [Naming]) -> Naming? {
        var named: Set<Name> = []

        return namings.first { naming in !named.insert(naming.name).inserted && naming.bound != nil }
    }

    // The bound written beside each type parameter's first naming, where no
    // later naming writes one.
    func bounds(of namings: [Naming]) -> [Name: Set<Name>] {
        namings.reduce(into: [:]) { bounds, naming in
            guard let bound = naming.bound else { return }

            bounds[naming.name] = bound
        }
    }

    // What a document gives something to, from the key it writes it under:
    // a type's name, the type applied to what its brackets hold, or an
    // Optional, where a `some T` may stand beside its bounds,
    // `some T: Hashable & Equatable`, and `(some W: Hashable)?` under a `?`.
    // A type parameter is bounded where the head first names it, and the
    // head is a type a value is an instance of.
    func head(_ text: String) throws -> Head {
        let read = try written(text)
        let type = read.type

        if let again = renaming(in: read.namings) {
            throw TypeFormError(
                "bounds '\(again.name)' where it is named again. A head bounds a type parameter where it first names it"
            )
        }

        let bounds = bounds(of: read.namings)

        switch type {
        case let .named(name, arguments):
            return Head(name, arguments: arguments, bounds: bounds)

        case let .array(element):
            return Head(TypeSpelling.array, arguments: [element], bounds: bounds)

        case let .dictionary(key, value):
            return Head(TypeSpelling.dictionary, arguments: [key, value], bounds: bounds)

        case let .optional(wrapped):
            return Head(TypeSpelling.optional, arguments: [wrapped], bounds: bounds)

        default:
            guard let name = TypeExpression.keywords.first(where: { _, keyword in keyword == type })?.key else {
                throw TypeFormError(
                    "'\(text)' is no type a claim may be about, and an extension is of one: a type,"
                        + " a type applied to what its brackets hold, or an Optional"
                )
            }

            return Head(name)
        }
    }

    // The contracts a bound names: the parts an `&` joins, or the one name
    // where none does. Each part is read as a name, and which names a
    // contract may be called is the load's, by `NameGrammar`, wherever the
    // names came from.
    func contracts(_ text: String) throws -> Set<Name> {
        try contracts(TypeParser().bound(text))
    }

    // The same, the bound already cut.
    func contracts(_ bound: TypeSyntax.Bound) throws -> Set<Name> {
        try bound.contracts.reduce(into: Set<Name>()) { names, part in
            names.insert(try named(part))
        }
    }

    // MARK: - Private
    // The syntax a spelling is cut into, `steps.count` containers deep.
    private func parsed(_ text: String) throws -> TypeSyntax {
        do {
            return try TypeParser().parse(text, at: steps.count)
        } catch let refusal as TypeSyntaxError {
            throw TypeFormError(refusal.message)
        }
    }

    // The type a syntax says. The forms holding a type are judged in
    // functions of their own, so a level of the walk holds little more than
    // the dispatch.
    private mutating func judged(_ syntax: TypeSyntax) throws -> TypeExpression {
        switch syntax {
        case let .name(text):
            return try named(type: text)

        case let .applied(head, arguments):
            return try applied(head, arguments)

        case let .optional(inner):
            return .optional(try judged(inner))

        case let .composition(names):
            return try composition(names)

        case let .parameter(introduced):
            return try parameter(introduced)

        case let .associated(associated):
            return try associatedType(associated)

        case let .marked(mark, inner):
            return try marked(mark, inner)

        case let .modified(modifiers, inner):
            return try modified(modifiers, inner)

        case let .procedure(parameters, throwing, returns):
            return .procedure(try procedure(parameters, throwing, returns))
        }
    }

    // A type the language names, or a name some module declares.
    private func named(type text: String) throws -> TypeExpression {
        let name = try named(text)

        if let keyword = TypeExpression.keywords[name] {
            return keyword
        }

        return .named(name)
    }

    // A built-in or a declared struct applied to the types its brackets
    // hold.
    private mutating func applied(_ head: String, _ arguments: [TypeSyntax]) throws -> TypeExpression {
        if let builtin = GenericBuiltin(spelling: head) {
            return try held(try types(arguments), in: builtin, as: head, arguments)
        }

        let name = try applicable(head)

        return .named(name, arguments: try types(arguments))
    }

    private func held(
        _ parts: [TypeExpression],
        in builtin: GenericBuiltin,
        as head: String,
        _ arguments: [TypeSyntax]
    ) throws -> TypeExpression {
        guard let held = builtin.applied(to: parts) else {
            throw TypeFormError(
                "type '\(TypeSyntax.applied(head, arguments).spelling)' is written with another count of types,"
                    + " and `\(builtin.spelling)` takes \(builtin.arguments)"
            )
        }

        return held
    }

    private mutating func types(_ syntaxes: [TypeSyntax]) throws -> [TypeExpression] {
        var types: [TypeExpression] = []

        for syntax in syntaxes {
            types.append(try judged(syntax))
        }

        return types
    }

    // A declared name applied to types is a struct taking type parameters,
    // and how many it takes is its declaration's, which the build reads where
    // the name resolves. A type the language names takes none.
    private func applicable(_ head: String) throws -> Name {
        let name = try named(head)

        guard TypeExpression.keywords[name] == nil else {
            throw TypeFormError(
                "type '\(head)' takes no argument. Only "
                    + GenericBuiltin.allCases.map { builtin in "`\(builtin.spelling)<…>`" }.joined(separator: ", ")
                    + " and a struct a module declares with type parameters do"
            )
        }

        return name
    }

    // `A & B`: the names a value conforms to, and nothing else. Names joining to
    // one name one contract, which is that name.
    private func composition(_ joined: TypeSyntax.Bound) throws -> TypeExpression {
        let names = try contracts(joined)

        if names.count == 1, let only = names.first {
            return .named(only)
        }

        return .composition(names)
    }

    // A type parameter rather than a name: `some T` is worked out from the
    // call, where `T` alone would be looked up in the table of declared
    // types. Where it is introduced, the contracts it is bounded by stand
    // beside it, `some T: Hashable & Equatable`.
    private mutating func parameter(_ introduced: TypeSyntax.Introduced) throws -> TypeExpression {
        let label = introduced.name

        guard let bound = introduced.bound else {
            let name = try named(label)

            namings.append(Naming(name: name, bound: nil, steps: steps))

            return .parameter(name: name)
        }

        guard !label.contains(".") else {
            throw TypeFormError(
                "writes a bound beside '\(label)', an associated type, and a bound stands beside a type"
                    + " parameter where it is introduced. An associated type is held to what the contract asking"
                    + " it says, and in a signature also to its `bounds`, keyed by '\(label)'"
            )
        }

        let name = try named(label)

        namings.append(Naming(name: name, bound: try contracts(bound), steps: steps))

        return .parameter(name: name)
    }

    private mutating func marked(_ mark: TypeSyntax.Mark, _ inner: TypeSyntax) throws -> TypeExpression {
        let type = try judged(inner)

        switch mark {
        case .variable:
            return .variable(type)

        case .inout:
            return .inout(type)
        }
    }

    // A modifier stands in front of a procedure type, the one it is written
    // on, or of `Procedure`, which says no signature.
    private mutating func modified(_ modifiers: [TypeSyntax.Modifier], _ inner: TypeSyntax) throws -> TypeExpression {
        let (constness, isolation) = try effects(modifiers, on: inner)

        guard case let .procedure(parameters, throwing, returns) = inner else {
            return .procedure(nil, constness, isolation)
        }

        return .procedure(try procedure(parameters, throwing, returns), constness, isolation)
    }

    // What the modifiers say, where they stand on a procedure type or on
    // `Procedure`. One written twice says it once, and the load's write-back
    // holds a document to one spelling.
    private func effects(
        _ modifiers: [TypeSyntax.Modifier],
        on inner: TypeSyntax
    ) throws -> (Constness, Isolation) {
        switch inner {
        case .procedure, .name(TypeSpelling.procedure.spelling):
            break

        default:
            throw TypeFormError(
                "type '\(TypeSyntax.modified(modifiers, inner).spelling)' writes a modifier in front of what is no"
                    + " procedure type. A modifier stands in front of a procedure type, and its Optional is written"
                    + " in parentheses before the `?`: `(const Procedure)?`"
            )
        }

        return (
            modifiers.contains(.const) ? .const : .unstated,
            modifiers.contains(.isolated) ? .isolated : .unstated
        )
    }

    // A procedure type: the types it is called with, what it may fail with,
    // and what it returns. Leaving `throws` out says it fails with nothing,
    // `throws` alone that it may fail with anything, and `throws(a, b)` with
    // those.
    private mutating func procedure(
        _ parameters: [TypeSyntax],
        _ throwing: TypeSyntax.Throwing?,
        _ returns: TypeSyntax
    ) throws -> ProcedureType {
        let failing: Failing = switch throwing {
        case nil: .these([])
        case .anything: .anything
        case let .these(failures): .these(Set(failures))
        }

        return ProcedureType(parameters: try types(parameters), returns: try judged(returns), failing: failing)
    }

    // `some T.Item` is the type the type filling `T` gives under `Item`,
    // and `Self.Item` the type the type conforming to a contract does. The base
    // and each member are a name.
    private func associatedType(_ associated: TypeSyntax.Associated) throws -> TypeExpression {
        .associatedType(AssociatedType(base: try named(associated.base.name), members: try associated.members.map(named)))
    }

    // A written type's name, refused as a `TypeFormError` like every other
    // refusal a type's spelling earns.
    private func named(_ text: String) throws -> Name {
        do {
            return try Name(text)
        } catch let refusal as NameRefused {
            throw TypeFormError(refusal.message)
        }
    }

    // Why a bound stands nowhere but where a type parameter is introduced.
    private static func unintroduced(_ name: Name) -> String {
        "bounds '\(name)' where no bound is written. A type parameter is bounded where it is introduced:"
            + " at the first `some \(name)` a procedure's slots write, in a struct's `typeParameters`,"
            + " in a contract's `types` and in an extension's head"
    }
}
