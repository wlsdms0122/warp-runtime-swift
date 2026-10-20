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
//   Dictionary<String, Task>  . The same, for a map: its key's type and its
//                                value's
//   Task                      . A name some module declares
//   Box<Int>                  . A struct some module declares, applied to
//                                the types its type parameters stand for
//   (Int, String) throws(aborted) -> Bool
//                             . A procedure: the types it is called with,
//                                what it may fail with, and after `->` what
//                                it answers. Bare `Procedure` says only that
//                                it is one
//
// A struct is a structure a module declares under `types`, and a type names
// it.
struct TypeReader: Decodable {
    // A built-in taking other types between its brackets.
    enum Holding: CaseIterable {
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
            guard let holding = Self.allCases.first(where: { holding in holding.spelling == spelling }) else {
                return nil
            }

            self = holding
        }

        // MARK: - Public
        // The type holding these, or nil where they are not as many as it
        // takes.
        func holding(_ inner: [TypeExpression]) -> TypeExpression? {
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

    // MARK: - Property
    // What is written. Taken through `unbounded()` where no bound may stand,
    // and with `namings` in a slot, which a bound may stand beside.
    private let written: TypeExpression

    // The type parameters the type names, in the order the reading meets
    // them, a procedure type's and a map type's included.
    let namings: [Naming]

    // What a slot reads: the type, and the type parameters it names.
    var bounded: (type: TypeExpression, namings: [Naming]) { (written, namings) }

    // What a type written as anything but a string is refused with.
    static let unread = "a type is written as a string like `String`, `Array<String>`, `Task` or"
        + " `(Int) -> Bool`. A struct is declared under its name in `types` as `{ struct: { … } }`,"
        + " and named everywhere else"

    // MARK: - Initializer
    // A type's own refusals do not know where in a document they happened, and
    // every one of them arrives here, so the place is put on them in one
    // statement rather than in whichever branch threw.
    init(from decoder: Decoder) throws {
        do {
            (self.written, self.namings) = try Self.read(from: decoder)
        } catch let error as TypeFormError {
            throw ReadingError(error.message, at: decoder.steps)
        }
    }

    private init(_ written: TypeExpression, namings: [Naming]) {
        self.written = written
        self.namings = namings
    }

    // MARK: - Public
    // The type, where nothing it names is bounded here. A type parameter is
    // bounded where it is introduced, and a type read through this is not
    // where one is.
    func unbounded() throws -> TypeExpression {
        if let bounded = namings.first(where: { naming in naming.bound != nil }) {
            throw ReadingError(Self.unintroduced(bounded.name), at: bounded.steps)
        }

        return written
    }

    // A type from its spelling, a declared name written short standing for
    // what the notation reads it as. `steps` are where its string is written,
    // and the type stands as deep as the containers they enter.
    static func reading(
        _ written: String,
        in notation: Notation = .canonical,
        at steps: [Place.Step] = []
    ) throws -> TypeReader {
        var namings: [Naming] = []
        let type = try parse(written, depth: steps.count, qualifying: { name in notation.qualified(name, as: .type) }) { name, bound in
            namings.append(Naming(name: name, bound: bound, steps: steps))
        }

        return TypeReader(type, namings: namings)
    }

    // The bound written beside each type parameter's first naming, and the
    // first naming written with a bound after the name was already named,
    // which the caller refuses in its own words.
    static func introduced(_ namings: [Naming]) -> (bounds: [Name: Set<Name>], again: Naming?) {
        var named: Set<Name> = []
        var bounds: [Name: Set<Name>] = [:]

        for naming in namings {
            let first = named.insert(naming.name).inserted

            guard let bound = naming.bound else { continue }
            guard first else { return (bounds, naming) }

            bounds[naming.name] = bound
        }

        return (bounds, nil)
    }

    // The same, where no bound may stand.
    static func parse(
        _ written: String,
        in notation: Notation = .canonical,
        at steps: [Place.Step] = []
    ) throws -> TypeExpression {
        let read = try reading(written, in: notation, at: steps)

        if let bounded = read.namings.first(where: { naming in naming.bound != nil }) {
            throw TypeFormError(unintroduced(bounded.name))
        }

        return read.written
    }

    // What a document gives something to, from the key it writes it under:
    // a type's name, or the type applied to what its brackets hold, where a
    // `some T` may stand beside its bounds, `some T: Hashable & Equatable`.
    // A type parameter is bounded where the head first names it, and the
    // head is a type a value is an instance of.
    static func head(
        _ written: String,
        in notation: Notation = .canonical,
        at steps: [Place.Step] = []
    ) throws -> Head {
        let read = try reading(written, in: notation, at: steps)
        let (bounds, again) = introduced(read.namings)
        let type = read.written

        if let again {
            throw TypeFormError(
                "bounds '\(again.name)' where it is named again. A head bounds a type parameter where it first names it"
            )
        }

        switch type {
        case let .named(name, arguments):
            return Head(name, arguments: arguments, bounds: bounds)

        case let .array(element):
            return Head(TypeSpelling.array, arguments: [element], bounds: bounds)

        case let .dictionary(key, value):
            return Head(TypeSpelling.dictionary, arguments: [key, value], bounds: bounds)

        default:
            guard let name = TypeExpression.keywords.first(where: { _, keyword in keyword == type })?.key else {
                throw TypeFormError(
                    "'\(written)' is no type a value is an instance of, and an extension is of one: a type,"
                        + " or a type applied to what its brackets hold"
                )
            }

            return Head(name)
        }
    }

    // The contracts a bound names: the parts an `&` joins, or the one name
    // where none does. Each part is read as a name, and which names a
    // contract may be called is the load's, by `NameGrammar`, wherever the
    // names came from.
    static func contracts(_ written: String, in notation: Notation) throws -> Set<Name> {
        try contracts(TypeParser().names(written)) { name in notation.qualified(name, as: .type) }
    }

    // A written type's name, said in this notation's own terms: every other
    // refusal a type's spelling earns is a `TypeFormError`.
    static func named(_ text: String) throws -> Name {
        do {
            return try Name(text)
        } catch let refusal as NameRefused {
            throw TypeFormError(refusal.message)
        }
    }

    // MARK: - Private
    // `qualifying` is the notation's reading of a declared name, handed down
    // the syntax's parts. `depth` is how many containers stand around the
    // string.
    private static func parse(
        _ written: String,
        depth: Int,
        qualifying: (Name) -> Name,
        bounding: (Name, Set<Name>?) throws -> Void
    ) throws -> TypeExpression {
        let syntax: TypeSyntax

        do {
            syntax = try TypeParser().parse(written, at: depth)
        } catch let refusal as TypeSyntaxError {
            throw TypeFormError(refusal.message)
        }

        return try judged(syntax, qualifying: qualifying, bounding: bounding)
    }

    // The type a syntax says. The forms holding a type are judged in
    // functions of their own, so a level of the walk holds little more than
    // the dispatch.
    private static func judged(
        _ syntax: TypeSyntax,
        qualifying: (Name) -> Name,
        bounding: (Name, Set<Name>?) throws -> Void
    ) throws -> TypeExpression {
        switch syntax {
        case let .name(text):
            return try named(text, qualifying: qualifying)

        case let .applied(head, arguments):
            return try applied(head, arguments, qualifying: qualifying, bounding: bounding)

        case let .nullable(inner):
            return .nullable(try judged(inner, qualifying: qualifying, bounding: bounding))

        case let .composition(names):
            return try composition(names, qualifying: qualifying)

        case let .parameter(label, bound):
            return try parameter(label, bound, qualifying: qualifying, bounding: bounding)

        case let .marked(mark, inner):
            return try marked(mark, inner, qualifying: qualifying, bounding: bounding)

        case let .modified(modifiers, inner):
            return try modified(modifiers, inner, qualifying: qualifying, bounding: bounding)

        case let .procedure(parameters, throwing, returns):
            return .procedure(try procedure(parameters, throwing, returns, qualifying: qualifying, bounding: bounding))
        }
    }

    // A type the language names, an associated type of `Self`, or a name
    // some module declares.
    private static func named(_ text: String, qualifying: (Name) -> Name) throws -> TypeExpression {
        if text.hasPrefix("\(TypeSpelling.selfType.spelling)."), let associated = try associatedType(text) {
            return associated
        }

        let name = try named(text)

        return TypeExpression.keywords[name] ?? .named(qualifying(name))
    }

    // A built-in or a declared struct applied to the types its brackets
    // hold.
    private static func applied(
        _ head: String,
        _ arguments: [TypeSyntax],
        qualifying: (Name) -> Name,
        bounding: (Name, Set<Name>?) throws -> Void
    ) throws -> TypeExpression {
        if let holding = Holding(spelling: head) {
            return try held(try types(arguments, qualifying: qualifying, bounding: bounding), in: holding, as: head, arguments)
        }

        let name = try applicable(head)

        return .named(qualifying(name), arguments: try types(arguments, qualifying: qualifying, bounding: bounding))
    }

    private static func held(
        _ parts: [TypeExpression],
        in holding: Holding,
        as head: String,
        _ arguments: [TypeSyntax]
    ) throws -> TypeExpression {
        guard let held = holding.holding(parts) else {
            throw TypeFormError(
                "type '\(TypeSyntax.applied(head, arguments).spelling)' is written with another count of types,"
                    + " and `\(holding.spelling)` takes \(holding.arguments)"
            )
        }

        return held
    }

    private static func types(
        _ syntaxes: [TypeSyntax],
        qualifying: (Name) -> Name,
        bounding: (Name, Set<Name>?) throws -> Void
    ) throws -> [TypeExpression] {
        var types: [TypeExpression] = []

        for syntax in syntaxes {
            types.append(try judged(syntax, qualifying: qualifying, bounding: bounding))
        }

        return types
    }

    // A declared name applied to types is a struct taking type parameters,
    // and how many it takes is its declaration's, which the build reads where
    // the name resolves. A type the language names takes none.
    private static func applicable(_ head: String) throws -> Name {
        let name = try named(head)

        guard TypeExpression.keywords[name] == nil else {
            throw TypeFormError(
                "type '\(head)' takes no argument. Only "
                    + Holding.allCases.map { holding in "`\(holding.spelling)<…>`" }.joined(separator: ", ")
                    + " and a struct a module declares with type parameters do"
            )
        }

        return name
    }

    // `A & B`: the names a value answers, and nothing else. Names joining to
    // one name one contract, which is that name.
    private static func composition(_ parts: [String], qualifying: (Name) -> Name) throws -> TypeExpression {
        let names = try contracts(parts, qualifying: qualifying)

        if names.count == 1, let only = names.first {
            return .named(only)
        }

        return .composition(names)
    }

    // A type parameter rather than a name: `some T` is worked out from the
    // call, where `T` alone would be looked up in the table of declared
    // types. Where it is introduced, the contracts it is bounded by stand
    // beside it, `some T: Hashable & Equatable`.
    //
    // `some T.Item` is the type the type filling `T` gives under `Item`,
    // and `Self.Item` the type the type answering a contract does.
    private static func parameter(
        _ label: String,
        _ bound: [String]?,
        qualifying: (Name) -> Name,
        bounding: (Name, Set<Name>?) throws -> Void
    ) throws -> TypeExpression {
        guard let bound else {
            if let associated = try associatedType(label) {
                return associated
            }

            let name = try named(label)

            try bounding(name, nil)

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

        try bounding(name, try contracts(bound, qualifying: qualifying))

        return .parameter(name: name)
    }

    private static func marked(
        _ mark: TypeSyntax.Mark,
        _ inner: TypeSyntax,
        qualifying: (Name) -> Name,
        bounding: (Name, Set<Name>?) throws -> Void
    ) throws -> TypeExpression {
        let type = try judged(inner, qualifying: qualifying, bounding: bounding)

        switch mark {
        case .variable:
            return .variable(type)

        case .inout:
            return .inout(type)
        }
    }

    // A modifier stands in front of a procedure type, the one it is written
    // on, or of `Procedure`, which says no signature.
    private static func modified(
        _ modifiers: [TypeSyntax.Modifier],
        _ inner: TypeSyntax,
        qualifying: (Name) -> Name,
        bounding: (Name, Set<Name>?) throws -> Void
    ) throws -> TypeExpression {
        let (constness, isolation) = try effects(modifiers, on: inner)

        guard case let .procedure(parameters, throwing, returns) = inner else {
            return .procedure(nil, constness, isolation)
        }

        return .procedure(
            try procedure(parameters, throwing, returns, qualifying: qualifying, bounding: bounding),
            constness,
            isolation
        )
    }

    // What the modifiers say, where they stand on a procedure type or on
    // `Procedure`, each once.
    private static func effects(
        _ modifiers: [TypeSyntax.Modifier],
        on inner: TypeSyntax
    ) throws -> (Constness, Isolation) {
        guard Set(modifiers).count == modifiers.count else {
            throw TypeFormError("type '\(TypeSyntax.modified(modifiers, inner).spelling)' writes a modifier twice. Once says it")
        }

        switch inner {
        case .procedure, .name(TypeSpelling.procedure.spelling):
            break

        default:
            throw TypeFormError(
                "type '\(TypeSyntax.modified(modifiers, inner).spelling)' writes a modifier in front of what is no"
                    + " procedure type. A modifier stands in front of a procedure type, and one that may be null is"
                    + " written in parentheses before the `?`: `(const Procedure)?`"
            )
        }

        return (
            modifiers.contains(.const) ? .const : .unstated,
            modifiers.contains(.isolated) ? .isolated : .unstated
        )
    }

    // A procedure type: the types it is called with, what it may fail with,
    // and what it answers. Leaving `throws` out says it fails with nothing,
    // `throws` alone that it may fail with anything, and `throws(a, b)` with
    // those.
    private static func procedure(
        _ parameters: [TypeSyntax],
        _ throwing: TypeSyntax.Throwing?,
        _ returns: TypeSyntax,
        qualifying: (Name) -> Name,
        bounding: (Name, Set<Name>?) throws -> Void
    ) throws -> ProcedureType {
        let failing: Failing = switch throwing {
        case nil: .these([])
        case .anything: .anything
        case let .these(failures): .these(Set(failures))
        }

        return ProcedureType(
            parameters: try types(parameters, qualifying: qualifying, bounding: bounding),
            returns: try judged(returns, qualifying: qualifying, bounding: bounding),
            failing: failing
        )
    }

    // An associated type's spelling, what it is the associated type of and its
    // own name with a dot between them, or nil where the spelling writes no
    // dot. Read at the last dot, so `T.Item.Key` is `T.Item`'s `Key`.
    private static func associatedType(_ text: String) throws -> TypeExpression? {
        guard let dot = text.lastIndex(of: ".") else { return nil }

        return .associatedType(
            of: try named(String(text[..<dot]).trimmingCharacters(in: Path.whiteSpace)),
            name: try named(String(text[text.index(after: dot)...]).trimmingCharacters(in: Path.whiteSpace))
        )
    }

    // The names the parts of a bound or a composition are.
    private static func contracts(_ parts: [String], qualifying: (Name) -> Name) throws -> Set<Name> {
        try parts.reduce(into: Set<Name>()) { names, part in
            names.insert(qualifying(try named(part)))
        }
    }

    private static func read(from decoder: Decoder) throws -> (TypeExpression, [Naming]) {
        guard let written = try? decoder.singleValueContainer().decode(String.self) else {
            throw ReadingError(Self.unread, at: decoder.steps)
        }

        let read = try reading(written, in: decoder.notation, at: decoder.steps)

        return (read.written, read.namings)
    }

    // Why a bound stands nowhere but where a type parameter is introduced.
    private static func unintroduced(_ name: Name) -> String {
        "bounds '\(name)' where no bound is written. A type parameter is bounded where it is introduced:"
            + " at the first `some \(name)` a procedure's slots write, in a struct's `typeParameters`,"
            + " in a contract's `types` and in an extension's head"
    }
}
