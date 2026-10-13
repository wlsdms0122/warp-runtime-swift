//
//  TypeReader.swift
//  WarpSyntax
//
//  Created by JSilver on 8/17/26.
//

import Foundation
import Warp

// How a document spells a type. Two readings, because a type is written two
// ways:
//
//   String / Any / Procedure  . A built-in, by its own name
//   Array<String>             . A built-in applied to another type
//   Dictionary<String, Task>  . The same, for a map: its key's type and its
//                                value's
//   Task                      . A name some module declares
//   Box<Int>                  . A struct some module declares, applied to
//                                the types its type parameters stand for
//   { procedure: { parameters: [], returns:, failing: [] } }
//                             . A procedure, written as the types it is called
//                                with, what it answers and what it may fail
//                                with. Bare `Procedure` says only that it is one
//
// A mapping is one of these by its one key. A struct is a structure a
// module declares under `types`, and a type names it.
struct TypeReader: Decodable {
    // The inside of a procedure type: the types a value is applied with, in
    // position order, what it answers and what it may fail with. No names,
    // since a value carries none.
    struct ProcedureTypeReader: Decodable {
        enum CodingKeys: String, CodingKey, CaseIterable {
            case parameters
            case returns
            case failing
        }

        // MARK: - Property
        let type: ProcedureType

        // MARK: - Initializer
        init(from decoder: Decoder) throws {
            try KeyGate().rejectUnknownKeys(
                in: decoder,
                known: CodingKeys.self,
                context: "procedure type"
            )

            let container = try decoder.container(keyedBy: CodingKeys.self)

            self.type = ProcedureType(
                parameters: try container
                    .decodeIfPresent([TypeReader].self, forKey: .parameters)?
                    .map(\.type) ?? [],
                returns: try container
                    .decodeIfPresent(TypeReader.self, forKey: .returns)?
                    .type,
                failing: try container
                    .decodeIfPresent([String].self, forKey: .failing)
                    .map { failures in .these(Set(failures)) } ?? .unstated
            )
        }

        // MARK: - Public
        // MARK: - Private
    }

    // The inside of a map type written as a form: its key's type and its
    // value's, each under its own key.
    struct DictionaryTypeReader: Decodable {
        enum CodingKeys: String, CodingKey, CaseIterable {
            case key
            case value
        }

        // MARK: - Property
        let type: TypeExpression

        // MARK: - Initializer
        init(from decoder: Decoder) throws {
            try KeyGate().rejectUnknownKeys(
                in: decoder,
                known: CodingKeys.self,
                context: "map type"
            )

            let container = try decoder.container(keyedBy: CodingKeys.self)

            self.type = .dictionary(
                key: try container.decode(TypeReader.self, forKey: .key).type,
                value: try container.decode(TypeReader.self, forKey: .value).type
            )
        }

        // MARK: - Public
        // MARK: - Private
    }

    // A built-in taking other types, written under its own key where an
    // inner type has no spelling of its own. `Array<String>` is a name; an
    // array of procedures is not, and this is the form that carries it. The
    // key is the raw value, and the name is spelled like every type's.
    enum Holding: String, CaseIterable {
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

    // Where a procedure type's head is written: as a type's name, `Procedure`,
    // or as the key of the form that carries its signature, `procedure`.
    enum ProcedureHead {
        case name
        case key
    }

    // MARK: - Property
    let type: TypeExpression

    // The key a procedure type is written under.
    static let procedureKey: Name = "procedure"

    // What a type that is neither a spelling nor a form is refused with.
    static let unread = "a type is a name like `String`, `Array<String>` or"
        + " `Task`, or a mapping under one of `procedure`, `array`"
        + " and `dictionary`. A struct is declared under its name in `types`"
        + " as `{ struct: { … } }`, and named everywhere else"

    // MARK: - Initializer
    // A type's own refusals do not know where in a document they happened, and
    // every one of them arrives here, so the place is put on them in one
    // statement rather than in whichever branch threw.
    init(from decoder: Decoder) throws {
        do {
            self.type = try Self.read(from: decoder)
        } catch let error as TypeFormError {
            throw ReadingError(error.message, at: decoder.steps)
        }
    }

    // MARK: - Public
    // A type from its spelling, a declared name written short standing for
    // what the notation reads it as.
    static func parse(_ written: String, in notation: Notation = .canonical) throws -> TypeExpression {
        try parse(written) { name in notation.qualified(name, as: .type) }
    }

    // What a document gives something to, from the key it writes it under:
    // a type's name, or the type applied to what its brackets hold, where a
    // `some T` may stand beside its bounds, `some T: Hashable & Equatable`.
    // A type parameter is bounded where the head first names it, and the
    // head is a type a value is an instance of.
    static func head(_ written: String, in notation: Notation = .canonical) throws -> Head {
        var bounds: [Name: Set<Name>] = [:]
        var named: Set<Name> = []
        let type = try parse(written, qualifying: { name in notation.qualified(name, as: .type) }) { name, written in
            let first = named.insert(name).inserted

            guard let written else { return }

            guard first else {
                throw TypeFormError(
                    "bounds '\(name)' where it is named again. A head bounds a type parameter where it first names it"
                )
            }

            bounds[name] = written
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

    // Whether the reading takes this key as a procedure form's. Asked of the
    // reading itself rather than of a list beside it, because a list and a
    // parser drift and what they disagree about is a document one of them
    // writes and the other refuses.
    static func readsAsAProcedure(_ key: Name) -> Bool {
        procedureKeywords(of: key.spelling) != nil
    }

    // What a procedure form's key says, read front to back: a slot's mark if one
    // is written, the modifiers in either order, and `procedure`. Nil where the
    // key is not a procedure form's.
    //
    // One mark, because that is what a slot writes. A key carrying two is not
    // this form's, so a mapping keyed by it is no type form at all.
    //
    // The mark comes back as itself rather than as something that applies it,
    // so that what was read stays a value the caller can ask about.
    static func procedureKeywords(
        of key: String
    ) -> (mark: SlotMark?, constness: Constness, isolation: Isolation)? {
        let (mark, rest) = SlotMark.leading(of: key).map { read in (Optional(read.mark), read.rest) } ?? (nil, key)

        guard
            let (constness, isolation, head) = modifiers(of: rest),
            head == procedureKey.spelling
        else {
            return nil
        }

        return (mark, constness, isolation)
    }

    // The one spelling of a procedure type's head: `const` before `isolated`,
    // both before the head.
    static func procedureSpelling(_ constness: Constness, _ isolation: Isolation, as head: ProcedureHead) -> String {
        [
            constness == .const ? TypeSpelling.const.spelling : nil,
            isolation == .isolated ? TypeSpelling.isolated.spelling : nil,
            head == .name ? TypeSpelling.procedure.spelling : procedureKey.spelling
        ]
        .compactMap { part in part }
        .joined(separator: " ")
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
    // the spelling's parts.
    private static func parse(
        _ written: String,
        qualifying: (Name) -> Name,
        bounding: ((Name, Set<Name>?) throws -> Void)? = nil
    ) throws -> TypeExpression {
        let text = written.trimmingCharacters(in: Path.whiteSpace)

        guard !text.isEmpty else {
            throw TypeFormError("a type name must not be empty")
        }

        // `inout` and `var` stand in front of the whole type, including a
        // trailing `?`, so they are read before anything else is.
        if let (mark, bare) = SlotMark.leading(of: text) {
            return mark.marking(try parse(bare, qualifying: qualifying, bounding: bounding))
        }

        // A trailing `?` reads next because it wraps the whole spelling under
        // the mark: `Array<Int>?` is a nullable array, `const Procedure?` a
        // nullable procedure and `A & B?` a nullable composition, and what may
        // be inside the brackets never carries one.
        if text.hasSuffix("?") {
            return .nullable(try parse(String(text.dropLast()), qualifying: qualifying, bounding: bounding))
        }

        guard let (constness, isolation, rest) = Self.modifiers(of: text) else {
            throw TypeFormError("type '\(text)' writes a modifier twice. Once says it")
        }

        if constness == .const || isolation == .isolated {
            guard case let .procedure(signature, _, _) = try parse(rest, qualifying: qualifying, bounding: bounding) else {
                throw TypeFormError("only a procedure is written const or isolated")
            }

            return .procedure(signature, constness, isolation)
        }

        // A head's own type parameter, beside the contracts it is bounded by.
        // Read before `&`, which joins the bounds here.
        if let bounding, let parameter = dropPrefixed("\(TypeSpelling.some) ", from: text) {
            let parts = parameter.split(separator: ":", maxSplits: 1)

            // An associated type read as one, for the load to say a head
            // writes none.
            if parts.count == 1, let associated = try associatedType(String(parameter)) {
                return associated
            }

            let name = try named(parts[0].trimmingCharacters(in: Path.whiteSpace))

            try bounding(name, parts.count > 1 ? try contracts(String(parts[1]), qualifying: qualifying) : nil)

            return .parameter(name: name)
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

        // A type parameter rather than a name: `some T` is worked out from the
        // call, where `T` alone would be looked up in the table of declared
        // types. A slot only names the parameter; its bound is the
        // signature's, under `BoundsReader`.
        //
        // `some T.Item` is the type the type filling `T` gives under `Item`,
        // and `Self.Item` the type the type answering a contract does.
        if text == TypeSpelling.some.spelling || text.hasPrefix("\(TypeSpelling.some) ") {
            let written = text.dropFirst(TypeSpelling.some.spelling.count).trimmingCharacters(in: Path.whiteSpace)

            if let associated = try associatedType(written) {
                return associated
            }

            return .parameter(name: try named(written))
        }

        if text.hasPrefix("\(TypeSpelling.selfType.spelling)."), let associated = try associatedType(text) {
            return associated
        }

        guard let open = text.firstIndex(of: "<") else {
            guard !text.contains(">") else {
                throw TypeFormError("type '\(text)' closes an argument it never opened")
            }

            let name = try named(text)

            return TypeExpression.keywords[name] ?? .named(qualifying(name))
        }

        let head = String(text[text.startIndex ..< open])

        guard text.hasSuffix(">") else {
            throw TypeFormError("type '\(text)' opens an argument it never closes")
        }

        let inner = String(text[text.index(after: open) ..< text.index(before: text.endIndex)])

        // A declared name applied to types is a struct taking type
        // parameters, and how many it takes is its declaration's, which the
        // build reads where the name resolves. A type the language names
        // takes none.
        guard let holding = Holding(spelling: head) else {
            let name = try named(head.trimmingCharacters(in: Path.whiteSpace))

            guard TypeExpression.keywords[name] == nil else {
                throw TypeFormError(
                    "type '\(head)' takes no argument. Only "
                        + Holding.allCases.map { holding in "`\(holding.spelling)<…>`" }.joined(separator: ", ")
                        + " and a struct a module declares with type parameters do"
                )
            }

            return .named(
                qualifying(name),
                arguments: try arguments(inner).map { argument in try parse(argument, qualifying: qualifying, bounding: bounding) }
            )
        }

        let parts = try arguments(inner).map { argument in try parse(argument, qualifying: qualifying, bounding: bounding) }

        guard let held = holding.holding(parts) else {
            throw TypeFormError(
                "type '\(text)' is written with another count of types,"
                    + " and `\(holding.spelling)` takes \(holding.arguments)"
            )
        }

        return held
    }

    // An associated type's spelling, what it is the associated type of and its
    // own name with a dot between them, or nil where the spelling writes no
    // dot. Read at the last dot, so `T.Item.Key` is `T.Item`'s `Key`.
    private static func associatedType(_ text: String) throws -> TypeExpression? {
        guard let dot = text.firstIndex(of: ".") else { return nil }

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
    // outside every inner bracket.
    private static func arguments(_ text: String) -> [String] {
        var depth = 0
        var parts: [String] = []
        var start = text.startIndex

        for index in text.indices {
            switch text[index] {
            case "<": depth += 1
            case ">": depth -= 1
            case "," where depth == 0:
                parts.append(String(text[start ..< index]))
                start = text.index(after: index)

            default: break
            }
        }

        return parts + [String(text[start...])]
    }

    // The parts an `&` at the top of a spelling joins, or nothing where the
    // spelling has no such `&`: one inside brackets belongs to the argument.
    private static func joined(_ text: String) -> [Substring]? {
        var depth = 0
        var parts: [Substring] = []
        var start = text.startIndex

        for index in text.indices {
            switch text[index] {
            case "<": depth += 1
            case ">": depth -= 1
            case "&" where depth == 0:
                parts.append(text[start ..< index])
                start = text.index(after: index)

            default: break
            }
        }

        guard !parts.isEmpty else { return nil }

        parts.append(text[start...])

        return parts
    }

    private static func read(from decoder: Decoder) throws -> TypeExpression {
        let notation = decoder.notation

        if let written = try? decoder.singleValueContainer().decode(String.self) {
            return try parse(written, in: notation)
        }

        guard case .dictionary = try ValueReader(from: decoder).value else {
            throw ReadingError(Self.unread, at: decoder.steps)
        }

        let keyed = try decoder.container(keyedBy: AnyCodingKey.self)

        // A mapping is a form by its one key. The form is committed by its key
        // *before* what is under it is read, so a malformed signature refuses
        // as the procedure type it claimed to be.
        switch Tagging(keyed.allKeys.map { key in (name: key.name, value: key) }, reading: TypeForm.init) {
        case let .one(.procedure(mark, constness, isolation), key):
            let form = try keyed.decode(ProcedureTypeReader.self, forKey: key)
            let written = TypeExpression.procedure(form.type, constness, isolation)

            return mark?.marking(written) ?? written

        // An array or a dictionary of something with no spelling of its own:
        // an array of procedures has no name, so it is written here.
        case let .one(.holding(.array), key):
            return .array(try keyed.decode(TypeReader.self, forKey: key).type)

        case let .one(.holding(.dictionary), key):
            return try keyed.decode(DictionaryTypeReader.self, forKey: key).type

        case let .among(tags):
            throw ReadingError(
                "\(tags.map { tag in "`\(tag)`" }.joined(separator: ", ")) stands alone in its mapping"
                    + " (found keys: \(keyed.allKeys.map(\.stringValue).sorted()))",
                at: decoder.steps
            )

        case .none:
            throw ReadingError(Self.unread, at: decoder.steps)
        }
    }

    // The rest of the text where it begins with this, and nothing where it does
    // not.
    private static func dropPrefixed(_ prefix: String, from text: String) -> Substring? {
        text.hasPrefix(prefix) ? text.dropFirst(prefix.count) : nil
    }
}
