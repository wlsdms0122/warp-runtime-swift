//
//  TypeReader.swift
//  WarpSyntax
//
//  Created by JSilver on 8/17/26.
//

import Foundation
import Warp

// How a document spells a type: as a string, read as its parts.
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

    private static let deeper = "the type nests deeper than a document may, \(Value.nestingBound) levels: the containers"
        + " around its string count, and a type written inside another is one level deeper than it"

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

    // The modifiers at the front of a type's text, in either order, and the
    // text left after them. Nil where a modifier is written twice. A modifier
    // is a keyword in front rather than an argument, because it says what a
    // slot requires of the whole procedure rather than of a part of it.
    static func modifiers(of text: String) -> (Constness, Isolation, String)? {
        var rest = text
        var constness = Constness.unstated
        var isolation = Isolation.unstated

        while true {
            if let bare = dropPrefixed("\(TypeSpelling.const) ", from: rest) {
                guard constness == .unstated else { return nil }
                constness = .const
                rest = String(bare)
            } else if let bare = dropPrefixed("\(TypeSpelling.isolated) ", from: rest) {
                guard isolation == .unstated else { return nil }
                isolation = .isolated
                rest = String(bare)
            } else {
                return (constness, isolation, rest)
            }
        }
    }

    // The contracts a bound names: the parts an `&` joins, or the one name
    // where none does. Each part is read as a name, and which names a
    // contract may be called is the load's, by `NameGrammar`, wherever the
    // names came from.
    static func contracts(_ written: String, in notation: Notation) throws -> Set<Name> {
        try contracts(written) { name in notation.qualified(name, as: .type) }
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
    // the spelling's parts. A type written inside another is one deeper, and
    // a type nests no deeper than a document may, counted on from the
    // containers around its string. The forms holding a type
    // are read in functions of their own, and every check that ends the walk
    // in others, so a level of the walk holds little more than the dispatch.
    private static func parse(
        _ written: String,
        depth: Int,
        qualifying: (Name) -> Name,
        bounding: (Name, Set<Name>?) throws -> Void
    ) throws -> TypeExpression {
        guard depth <= Value.nestingBound else {
            throw TypeFormError(deeper)
        }

        let text = try trimmed(written)

        if let marked = try marked(text, depth: depth, qualifying: qualifying, bounding: bounding) {
            return marked
        }

        if let modified = try modified(text, depth: depth, qualifying: qualifying, bounding: bounding) {
            return modified
        }

        if let procedure = try procedure(text, depth: depth, qualifying: qualifying, bounding: bounding) {
            return procedure
        }

        if let nullable = try nullable(text, depth: depth, qualifying: qualifying, bounding: bounding) {
            return nullable
        }

        if let unapplied = try unapplied(text, qualifying: qualifying, bounding: bounding) {
            return unapplied
        }

        return try applied(text, depth: depth, qualifying: qualifying, bounding: bounding)
    }

    // `inout` and `var` stand in front of the whole type, including a
    // trailing `?`, so they are read before anything else is.
    private static func marked(
        _ text: String,
        depth: Int,
        qualifying: (Name) -> Name,
        bounding: (Name, Set<Name>?) throws -> Void
    ) throws -> TypeExpression? {
        guard let (mark, bare) = SlotMark.leading(of: text) else { return nil }

        return mark.marking(try parse(bare, depth: depth + 1, qualifying: qualifying, bounding: bounding))
    }

    // What follows `->` is a procedure's answer to the end of the spelling,
    // so the arrow reads before a trailing `?`: `(Int) -> Int?` answers what
    // may be null.
    private static func procedure(
        _ text: String,
        depth: Int,
        qualifying: (Name) -> Name,
        bounding: (Name, Set<Name>?) throws -> Void
    ) throws -> TypeExpression? {
        guard let arrow = Self.arrow(in: text) else { return nil }

        return try procedure(text, at: arrow, depth: depth, qualifying: qualifying, bounding: bounding)
    }

    // A trailing `?` wraps the whole spelling before it: `Array<Int>?` is a
    // nullable array and `A & B?` a nullable composition, and what may be
    // inside the brackets never carries one. Parentheses before it group
    // what it wraps.
    private static func nullable(
        _ text: String,
        depth: Int,
        qualifying: (Name) -> Name,
        bounding: (Name, Set<Name>?) throws -> Void
    ) throws -> TypeExpression? {
        guard text.hasSuffix("?") else { return nil }

        let inner = String(text.dropLast()).trimmingCharacters(in: Path.whiteSpace)

        return .nullable(try parse(parenthesized(inner) ?? inner, depth: depth + 1, qualifying: qualifying, bounding: bounding))
    }

    // The text without the white space around it. Parentheses group a type
    // where a `?` follows them and nowhere else, so the `?` is the whole
    // procedure type's: `((Int) -> Int)?`, `(const Procedure)?`. A type is
    // written one way, so a group standing anywhere else is refused.
    private static func trimmed(_ written: String) throws -> String {
        let text = written.trimmingCharacters(in: Path.whiteSpace)

        guard !text.isEmpty else {
            throw TypeFormError("a type name must not be empty")
        }

        guard parenthesized(text) == nil else {
            throw TypeFormError(
                "type '\(text)' groups a type where no `?` follows. Parentheses group a procedure type before"
                    + " its `?`, `((Int) -> Int)?`, and nowhere else"
            )
        }

        return text
    }

    // A modifier stands in front of the whole procedure type after it, so a
    // nullable one is written `(const Procedure)?`. The procedure is the type
    // the modifiers are written on, at their depth, and writes none of its
    // own. Nil where the text writes no modifier.
    private static func modified(
        _ text: String,
        depth: Int,
        qualifying: (Name) -> Name,
        bounding: (Name, Set<Name>?) throws -> Void
    ) throws -> TypeExpression? {
        guard let (constness, isolation, bare) = try modifiers(written: text) else { return nil }

        // The procedure is read here rather than through the dispatch, so a
        // modifier adds no level to the walk.
        guard let arrow = Self.arrow(in: bare) else {
            return .procedure(try procedure(named: bare, as: text), constness, isolation)
        }

        guard
            case let .procedure(signature, _, _) = try procedure(
                bare,
                at: arrow,
                depth: depth,
                qualifying: qualifying,
                bounding: bounding
            )
        else {
            throw unmodifiable(text)
        }

        return .procedure(signature, constness, isolation)
    }

    // The modifiers a text writes and the procedure type they stand in front
    // of, out of the parentheses that may group it. Nil where it writes none.
    private static func modifiers(written text: String) throws -> (Constness, Isolation, String)? {
        guard let (constness, isolation, rest) = Self.modifiers(of: text) else {
            throw TypeFormError("type '\(text)' writes a modifier twice. Once says it")
        }

        guard constness == .const || isolation == .isolated else { return nil }

        let bare = try trimmed(rest)

        guard case (.unstated, .unstated, _)? = Self.modifiers(of: bare) else {
            throw unmodifiable(text)
        }

        return (constness, isolation, bare)
    }

    // `Procedure` under modifiers, which says no signature.
    private static func procedure(named bare: String, as text: String) throws -> ProcedureType? {
        guard let name = try? named(bare), case .procedure(nil, _, _)? = TypeExpression.keywords[name] else {
            throw unmodifiable(text)
        }

        return nil
    }

    private static func unmodifiable(_ text: String) -> TypeFormError {
        TypeFormError(
            "type '\(text)' writes a modifier in front of what is no procedure type. A modifier stands in"
                + " front of a procedure type, and one that may be null is written in parentheses before"
                + " the `?`: `(const Procedure)?`"
        )
    }

    // A type that holds no other: a type parameter, an associated type, or
    // contracts an `&` joins. Nil where the text is a name, applied to types
    // or not. A parenthesis that opens it opens nothing a type is.
    private static func unapplied(
        _ text: String,
        qualifying: (Name) -> Name,
        bounding: (Name, Set<Name>?) throws -> Void
    ) throws -> TypeExpression? {
        if text.hasPrefix("(") {
            throw TypeFormError(
                "type '\(text)' opens a parenthesis, and parentheses hold a procedure type's parameters before"
                    + " `->` and its answer, `(Int) -> Bool`, or group a type, `((Int) -> Int)?`"
            )
        }

        if text == TypeSpelling.some.spelling || text.hasPrefix("\(TypeSpelling.some) ") {
            return try parameter(text, qualifying: qualifying, bounding: bounding)
        }

        // `A & B`: the names a value answers, and nothing else. Names joining
        // to one name one contract, which is that name.
        if joined(text) != nil {
            let names = try contracts(text, qualifying: qualifying)

            if names.count == 1, let only = names.first {
                return .named(only)
            }

            return .composition(names)
        }

        if text.hasPrefix("\(TypeSpelling.selfType.spelling).") {
            return try associatedType(text)
        }

        return nil
    }

    // A type parameter rather than a name: `some T` is worked out from the
    // call, where `T` alone would be looked up in the table of declared
    // types. Where it is introduced, the contracts it is bounded by stand
    // beside it, `some T: Hashable & Equatable`, read before `&`, which
    // joins the bounds here.
    //
    // `some T.Item` is the type the type filling `T` gives under `Item`,
    // and `Self.Item` the type the type answering a contract does.
    private static func parameter(
        _ text: String,
        qualifying: (Name) -> Name,
        bounding: (Name, Set<Name>?) throws -> Void
    ) throws -> TypeExpression {
        let parameter = text.dropFirst(TypeSpelling.some.spelling.count)
        let parts = parameter.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        let label = parts[0].trimmingCharacters(in: Path.whiteSpace)

        guard parts.count > 1 else {
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

        try bounding(name, try contracts(String(parts[1]), qualifying: qualifying))

        return .parameter(name: name)
    }

    // A name and what its brackets hold, or nil where it is written without
    // them.
    private static func application(of text: String) throws -> (head: String, inner: String)? {
        guard let open = text.firstIndex(of: "<") else {
            guard !text.contains(">") else {
                throw TypeFormError("type '\(text)' closes an argument it never opened")
            }

            return nil
        }

        guard text.hasSuffix(">") else {
            throw TypeFormError("type '\(text)' opens an argument it never closes")
        }

        return (
            String(text[text.startIndex ..< open]),
            String(text[text.index(after: open) ..< text.index(before: text.endIndex)])
        )
    }

    // A name, or a built-in or a declared struct applied to the types its
    // brackets hold.
    private static func applied(
        _ text: String,
        depth: Int,
        qualifying: (Name) -> Name,
        bounding: (Name, Set<Name>?) throws -> Void
    ) throws -> TypeExpression {
        guard let (head, inner) = try application(of: text) else {
            let name = try named(text)

            return TypeExpression.keywords[name] ?? .named(qualifying(name))
        }

        if let holding = Holding(spelling: head) {
            return try held(
                try types(inner, depth: depth, qualifying: qualifying, bounding: bounding),
                in: holding,
                as: head,
                inner
            )
        }

        let name = try applicable(head)

        return .named(qualifying(name), arguments: try types(inner, depth: depth, qualifying: qualifying, bounding: bounding))
    }

    // The types a spelling's brackets hold, a level deeper than it.
    private static func types(
        _ inner: String,
        depth: Int,
        qualifying: (Name) -> Name,
        bounding: (Name, Set<Name>?) throws -> Void
    ) throws -> [TypeExpression] {
        var types: [TypeExpression] = []

        for argument in arguments(inner) {
            types.append(try parse(argument, depth: depth + 1, qualifying: qualifying, bounding: bounding))
        }

        return types
    }

    // A declared name applied to types is a struct taking type parameters,
    // and how many it takes is its declaration's, which the build reads where
    // the name resolves. A type the language names takes none.
    private static func applicable(_ head: String) throws -> Name {
        let name = try named(head.trimmingCharacters(in: Path.whiteSpace))

        guard TypeExpression.keywords[name] == nil else {
            throw TypeFormError(
                "type '\(head)' takes no argument. Only "
                    + Holding.allCases.map { holding in "`\(holding.spelling)<…>`" }.joined(separator: ", ")
                    + " and a struct a module declares with type parameters do"
            )
        }

        return name
    }

    private static func held(
        _ parts: [TypeExpression],
        in holding: Holding,
        as head: String,
        _ inner: String
    ) throws -> TypeExpression {
        guard let held = holding.holding(parts) else {
            throw TypeFormError(
                "type '\(head)<\(inner)>' is written with another count of types,"
                    + " and `\(holding.spelling)` takes \(holding.arguments)"
            )
        }

        return held
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

    // The names the parts an `&` at the top of a spelling joins are, or the
    // one name the spelling is where it has no such `&`.
    private static func contracts(_ text: String, qualifying: (Name) -> Name) throws -> Set<Name> {
        try (joined(text) ?? [Substring(text)]).reduce(into: Set<Name>()) { names, part in
            names.insert(qualifying(try named(part.trimmingCharacters(in: Path.whiteSpace))))
        }
    }

    // The types a spelling's brackets hold, split at each comma that stands
    // outside every inner bracket and parenthesis.
    private static func arguments(_ text: String) -> [String] {
        split(text, at: ",").map(String.init)
    }

    // The parts an `&` at the top of a spelling joins, or nothing where the
    // spelling has no such `&`: one inside brackets belongs to the argument.
    private static func joined(_ text: String) -> [Substring]? {
        let parts = split(text, at: "&")

        return parts.count > 1 ? parts : nil
    }

    // The first `->` standing outside every bracket and parenthesis, which
    // ends a procedure type's parameters.
    private static func arrow(in text: String) -> String.Index? {
        outside(text).first { index in
            text[index...].hasPrefix("->")
        }
    }

    // What stands between a parenthesis opening the text and the one closing
    // it, where the one closing it is the text's last.
    private static func parenthesized(_ text: String) -> String? {
        guard text.hasPrefix("("), let close = closing(text), text.index(after: close) == text.endIndex else {
            return nil
        }

        return String(text[text.index(after: text.startIndex) ..< close])
    }

    // The parenthesis closing the one the text opens with.
    private static func closing(_ text: String) -> String.Index? {
        var depth = 0

        for (index, character) in zip(text.indices, text) {
            switch character {
            case "(": depth += 1
            case ")":
                depth -= 1
                if depth == 0 { return index }

            default: break
            }
        }

        return nil
    }

    // The text split at each `separator` standing outside every bracket and
    // parenthesis.
    private static func split(_ text: String, at separator: Character) -> [Substring] {
        var parts: [Substring] = []
        var start = text.startIndex

        for index in outside(text) where text[index] == separator {
            parts.append(text[start ..< index])
            start = text.index(after: index)
        }

        return parts + [text[start...]]
    }

    // Where the text stands outside every bracket and parenthesis. The `>` of
    // an arrow closes nothing.
    private static func outside(_ text: String) -> [String.Index] {
        var depth = 0
        var found: [String.Index] = []
        var previous: Character?

        for (index, character) in zip(text.indices, text) {
            switch character {
            case "<", "(":
                depth += 1

            case ">" where previous != "-", ")":
                depth -= 1

            default:
                if depth == 0 { found.append(index) }
            }

            previous = character
        }

        return found
    }

    private static func read(from decoder: Decoder) throws -> (TypeExpression, [Naming]) {
        guard let written = try? decoder.singleValueContainer().decode(String.self) else {
            throw ReadingError(Self.unread, at: decoder.steps)
        }

        let read = try reading(written, in: decoder.notation, at: decoder.steps)

        return (read.written, read.namings)
    }

    // A procedure type from what stands before its `->`, its parameters in
    // parentheses and then what it may fail with, and what stands after it.
    private static func procedure(
        _ text: String,
        at arrow: String.Index,
        depth: Int,
        qualifying: (Name) -> Name,
        bounding: (Name, Set<Name>?) throws -> Void
    ) throws -> TypeExpression {
        let (inside, failing) = try signature(String(text[..<arrow]))
        let parameters = inside.isEmpty ? [] : try types(inside, depth: depth, qualifying: qualifying, bounding: bounding)
        let returns = try parse(
            String(text[text.index(arrow, offsetBy: 2)...]),
            depth: depth + 1,
            qualifying: qualifying,
            bounding: bounding
        )

        return .procedure(ProcedureType(parameters: parameters, returns: returns, failing: failing))
    }

    // What stands between a procedure type's parentheses, and what it may
    // fail with. Leaving `throws` out says it fails with nothing, `throws`
    // alone that it may fail with anything, and `throws(a, b)` with those.
    private static func signature(_ head: String) throws -> (inside: String, failing: Failing) {
        let head = head.trimmingCharacters(in: Path.whiteSpace)

        guard head.hasPrefix("("), let close = closing(head) else {
            throw TypeFormError(
                "writes '\(head)' before `->`, and a procedure type writes its parameters in parentheses there:"
                    + " `(Int) -> Bool`"
            )
        }

        return (
            head[head.index(after: head.startIndex) ..< close].trimmingCharacters(in: Path.whiteSpace),
            try failing(String(head[head.index(after: close)...]))
        )
    }

    // What a procedure type says it may fail with, from what stands between
    // its parameters and `->`.
    private static func failing(_ written: String) throws -> Failing {
        let text = written.trimmingCharacters(in: Path.whiteSpace)

        guard !text.isEmpty else { return .these([]) }

        guard let rest = dropPrefixed(TypeSpelling.throws.spelling, from: text) else {
            throw TypeFormError(
                "writes '\(text)' between a procedure type's parameters and `->`, where `throws` stands, alone"
                    + " or with what it may fail with: `(Int) throws(aborted) -> Bool`"
            )
        }

        let listed = rest.trimmingCharacters(in: Path.whiteSpace)

        guard !listed.isEmpty else { return .anything }

        guard let names = parenthesized(listed)?.trimmingCharacters(in: Path.whiteSpace) else {
            throw TypeFormError("writes `throws\(rest)`, and what a procedure may fail with is listed in parentheses")
        }

        let failures = (names.isEmpty ? [] : arguments(names)).map { name in
            name.trimmingCharacters(in: Path.whiteSpace)
        }

        if failures.contains(where: \.isEmpty) {
            throw TypeFormError("writes `throws(\(names))`, which leaves a place in the list empty")
        }

        return .these(Set(failures))
    }

    // Why a bound stands nowhere but where a type parameter is introduced.
    private static func unintroduced(_ name: Name) -> String {
        "bounds '\(name)' where no bound is written. A type parameter is bounded where it is introduced:"
            + " at the first `some \(name)` a procedure's slots write, in a struct's `typeParameters`,"
            + " in a contract's `types` and in an extension's head"
    }

    // The rest of the text where it begins with this, and nothing where it does
    // not.
    private static func dropPrefixed(_ prefix: String, from text: String) -> Substring? {
        text.hasPrefix(prefix) ? text.dropFirst(prefix.count) : nil
    }
}
