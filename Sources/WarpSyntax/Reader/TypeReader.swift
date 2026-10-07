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
//   string / any / procedure  . A built-in, by its own name
//   array<string>             . A built-in applied to another type
//   dictionary<Task>          . The same, for a map of string keys
//   Task                      . A name some module declares
//   { record: { id: string } }. A record, its fields under `record`
//   { procedure: { parameters: [], returns: } }
//                             . A procedure, written as the types it is called
//                                with and what it answers. Bare `procedure` says
//                                only that it is one
//
// A mapping is one of these by its one key, so a record's field names are
// never keys the grammar reads.
public struct TypeReader: Decodable {
    // The inside of a procedure type: the types a value is applied with, in
    // position order, and what it answers. No names, since a value carries
    // none.
    struct ProcedureTypeReader: Decodable {
        // No `bounds` here on purpose: a nested procedure type's parameters are
        // the declaring procedure's own slots, so the declaring signature owns
        // every bound. Two `bounds` records binding one name would be two claims
        // about one thing, written a document apart.
        enum CodingKeys: String, CodingKey, CaseIterable {
            case parameters
            case returns
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
                    .type
            )
        }

        // MARK: - Public
        // MARK: - Private
    }

    // A built-in taking another type, written under its own key where the
    // inner type has no spelling of its own. `Array<String>` is a name; an
    // array of procedures is not, and this is the form that carries it. The
    // key is the raw value, and the name is spelled like every type's.
    enum Holding: String, CaseIterable {
        case array
        case dictionary

        // MARK: - Property
        var spelling: String {
            switch self {
            case .array: "Array"
            case .dictionary: "Dictionary"
            }
        }

        // MARK: - Initializer
        init?(spelling: String) {
            guard let holding = Self.allCases.first(where: { holding in holding.spelling == spelling }) else { return nil }

            self = holding
        }

        // MARK: - Public
        func holding(_ inner: TypeExpression) -> TypeExpression {
            switch self {
            case .array: .array(inner)
            case .dictionary: .dictionary(inner)
            }
        }

        // MARK: - Private
    }

    // MARK: - Property
    public let type: TypeExpression

    // The one key a type handed on once is written under.
    public static let linearKey: Name = "linear"

    // The one key a record type is written under.
    public static let recordKey: Name = "record"

    // What a type that is neither a spelling nor a form is refused with.
    private static let unread = "a type is a name like `String`, `Array<String>` or"
        + " `Task`, or a mapping under one of `record`, `procedure`, `linear`, `array`"
        + " and `dictionary`. A record type is written { record: { id: String } }"

    // MARK: - Initializer
    // A type's own refusals do not know where in a document they happened, and
    // every one of them arrives here, so the place is put on them in one
    // statement rather than in whichever branch threw.
    public init(from decoder: Decoder) throws {
        do {
            self.type = try Self.read(from: decoder)
        } catch let error as TypeFormError {
            throw ReadingError(error.message, at: decoder.steps)
        }
    }

    // MARK: - Public
    // A type from its spelling. `qualifying` is what a declared name written
    // short stands for, which is the notation's answer where a text may write
    // one short and the name itself where every name is written full.
    public static func parse(
        _ written: String,
        qualifying: (Name) -> Name = { name in name }
    ) throws -> TypeExpression {
        let text = written.trimmingCharacters(in: .whitespaces)

        guard !text.isEmpty else {
            throw TypeFormError("a type name must not be empty")
        }

        // A trailing `?` reads first because it wraps the whole spelling:
        // `Array<Int>?` is a nullable array, and what may be inside the
        // brackets never carries one. `?` speaks about a slot, and only the
        // whole spelling is one. `inout` and `var` stand in front of the whole
        // type, including a trailing `?`, so they are read before anything else
        // is.
        if let (mark, bare) = SlotMark.leading(of: text) {
            let inner = try parse(bare, qualifying: qualifying)

            if let refusal = SlotMark.refusal(marking: inner, under: mark) {
                throw TypeFormError(refusal)
            }

            return mark.marking(inner)
        }

        guard let (constness, isolation, rest) = Self.modifiers(of: text) else {
            throw TypeFormError("type '\(text)' writes a modifier twice. Once says it")
        }

        if constness == .const || isolation == .isolated {
            guard case let .procedure(signature, _, _) = try parse(rest, qualifying: qualifying) else {
                throw TypeFormError("only a procedure is written const or isolated")
            }

            return .procedure(signature, constness, isolation)
        }

        // `A & B`: the names a value answers, and nothing else. Read before
        // `?` and the rest so that every part is held to being a name; a `?`
        // on a part is a part that is not one, and a composition is not a
        // slot to mark.
        if let parts = joined(text) {
            let names = try parts.map { part -> Name in
                let parsed = try parse(part.trimmingCharacters(in: .whitespaces), qualifying: qualifying)

                guard case let .named(name) = parsed else {
                    throw TypeFormError(
                        "type '\(text)' joins '\(part.trimmingCharacters(in: .whitespaces))' with `&`,"
                            + " and `&` joins the names of contracts and memberships, each a bare name"
                    )
                }

                return name
            }

            guard Set(names).count == names.count else {
                throw TypeFormError("type '\(text)' names one bound twice")
            }

            return .composition(names.sorted())
        }

        if text.hasSuffix("?") {
            let inner = try parse(String(text.dropLast()), qualifying: qualifying)

            switch inner {
            // What already admits null gains nothing from saying so again,
            // and a spelling that says one thing twice reads as two things.
            case .nullable:
                throw TypeFormError("type '\(text)' writes `?` twice. Once says it")

            case .null, .any:
                throw TypeFormError(
                    "type '\(text)' writes `?` on what already admits null"
                )

            case .never:
                throw TypeFormError(
                    "type '\(text)' writes `?` on Never, which no value is"
                )

            // A type parameter stands for what the call puts there, and what
            // the call puts there is a type of its own. Nullability rides on
            // the filling, not on the mention.
            case .parameter:
                throw TypeFormError(
                    "type '\(text)' writes `?` on a type parameter. A"
                        + " parameter stands for the whole type the call fills in"
                )

            default:
                return .nullable(inner)
            }
        }

        // Constness is a keyword in front rather than an argument, because it says
        // what a slot requires of the whole procedure rather than of a part of
        // it. The same place a reader expects an adjective. A type parameter
        // rather than a name: `some T` is worked out from the call, where `T`
        // alone would be looked up in the table of declared types. A slot only
        // names the parameter. Its constraint is declared once, in the
        // signature's `bounds`, because the signature owns what its names mean
        // and a bound repeated per slot is one claim written several times.
        if text == "some" || text.hasPrefix("some ") {
            let bare = text.dropFirst("some".count).trimmingCharacters(in: .whitespaces)

            // A bare one: the signature declares the parameter itself, so a
            // dotted spelling names something declared elsewhere and there is
            // nothing here for it to mean. It is also what keeps a declared
            // parameter apart from the projection the build derives for a walk
            // through one, which is named for the dotted path that reached it.
            guard isName(bare), !bare.contains(".") else {
                throw TypeFormError(
                    "type '\(text)' names no type parameter. Write `some` and one"
                        + " bare name; a constraint is declared in the signature's `bounds`"
                )
            }

            return .parameter(name: try named(bare))
        }

        // A range is spelled into the name: `Int(0...255)`,
        // `Double(0.0..<1.0)`. Either bound optional but not both, and `..<`
        // leaving the far bound outside. Only a number takes one: a range is a
        // condition on a number, and no other kind is one. Which kind is
        // written out, because a bound is a value of the kind it bounds and the
        // two read their spellings differently.
        for kind in ["Int", "Double"] where text.hasPrefix("\(kind)(") && text.hasSuffix(")") {
            let inner = String(text.dropFirst("\(kind)(".count).dropLast())

            // `..<` first: `...` is inside neither spelling of the other, but
            // `..<` holds two of the three dots `...` is looked for by.
            let open = inner.range(of: "..<")
            let dots = open ?? inner.range(of: "...")

            guard let dots else {
                throw TypeFormError(
                    "type '\(text)' writes a range without `...` or `..<`. A"
                        + " range is spelled `\(kind)(0...255)`, either bound"
                        + " optional"
                )
            }

            let written = (lower: inner[..<dots.lowerBound], upper: inner[dots.upperBound...])

            guard !written.upper.isEmpty || open == nil else {
                throw TypeFormError(
                    "type '\(text)' writes `..<` with nothing after it. `..<`"
                        + " says the far bound is outside the range, and there"
                        + " is no far bound"
                )
            }

            guard !written.lower.isEmpty || !written.upper.isEmpty else {
                throw TypeFormError(
                    "type '\(text)' writes a range with neither bound. A range"
                        + " that says nothing is spelled `\(kind)`"
                )
            }

            return kind == "Int"
                ? .ranged(.whole(
                    from: try whole(written.lower, of: text),
                    to: edge(try whole(written.upper, of: text), excluding: open != nil)
                ))
                : .ranged(.fraction(
                    from: try fraction(written.lower, of: text),
                    to: edge(try fraction(written.upper, of: text), excluding: open != nil)
                ))
        }

        guard let open = text.firstIndex(of: "<") else {
            guard !text.contains(">") else {
                throw TypeFormError("type '\(text)' closes an argument it never opened")
            }

            // A list or a map says what it holds. `Array<Any>` is a list of
            // anything, and the bare word is not a second spelling of it.
            guard Holding(spelling: text) == nil else {
                throw TypeFormError(
                    "type '\(text)' says nothing of what it holds. Write `\(text)<Any>`"
                        + " for one of anything"
                )
            }

            let name = try named(text)

            return TypeExpression.keywords[name] ?? .named(qualifying(name))
        }

        let head = String(text[text.startIndex ..< open])

        guard text.hasSuffix(">") else {
            throw TypeFormError("type '\(text)' opens an argument it never closes")
        }

        let inner = String(text[text.index(after: open) ..< text.index(before: text.endIndex)])

        guard let holding = Holding(spelling: head) else {
            throw TypeFormError(
                "type '\(head)' takes no argument. Only "
                    + Holding.allCases.map { holding in "`\(holding.spelling)<…>`" }.joined(separator: " and ")
                    + " do"
            )
        }

        return holding.holding(try parse(inner, qualifying: qualifying))
    }

    // Whether the reading takes this key as a procedure form's. Asked of the
    // reading itself rather than of a list beside it, because a list and a
    // parser drift and what they disagree about is a document one of them
    // writes and the other refuses.
    public static func readsAsAProcedure(_ key: Name) -> Bool {
        procedureKeywords(of: key.spelling) != nil
    }

    // What a procedure form's key says, read front to back: a slot's mark if one
    // is written, the modifiers in either order, and `procedure`. Nil where the
    // key is not a procedure form's, which a record's field name is.
    //
    // One mark, because that is what a slot writes. A key carrying two is not
    // this form's and so is a field name, the way any other key that is not
    // this form's is: what the spelling of a whole type refuses, a key that
    // never claimed to be one is not asked.
    //
    // The mark comes back as itself rather than as something that applies it,
    // so that what was read stays a value the caller can ask about.
    static func procedureKeywords(
        of key: String
    ) -> (mark: SlotMark?, constness: Constness, isolation: Isolation)? {
        let (mark, rest) = SlotMark.leading(of: key).map { read in (Optional(read.mark), read.rest) } ?? (nil, key)

        guard
            let (constness, isolation, head) = modifiers(of: rest),
            head == "procedure"
        else {
            return nil
        }

        return (mark, constness, isolation)
    }

    // Where a procedure type's head is written: as a type's name, `Procedure`,
    // or as the key of the form that carries its signature, `procedure`.
    public enum ProcedureHead {
        case name
        case key
    }

    // The one spelling of a procedure type's head: `const` before `isolated`,
    // both before the head.
    public static func procedureSpelling(_ constness: Constness, _ isolation: Isolation, as head: ProcedureHead) -> String {
        [constness == .const ? "const" : nil, isolation == .isolated ? "isolated" : nil, head == .name ? "Procedure" : "procedure"]
            .compactMap { part in part }
            .joined(separator: " ")
    }

    // The modifiers at the front of a type's text, in either order, and the
    // text left after them. Nil where a modifier is written twice.
    static func modifiers(of text: String) -> (Constness, Isolation, String)? {
        var rest = text
        var constness = Constness.unstated
        var isolation = Isolation.unstated

        while true {
            if let bare = dropPrefixed("const ", from: rest) {
                guard constness == .unstated else { return nil }
                constness = .const
                rest = String(bare)
            } else if let bare = dropPrefixed("isolated ", from: rest) {
                guard isolation == .unstated else { return nil }
                isolation = .isolated
                rest = String(bare)
            } else {
                return (constness, isolation, rest)
            }
        }
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

    // One name with nothing structural in it: what a type parameter's
    // spelling has to be.
    static func isName(_ text: String) -> Bool {
        !text.isEmpty && !text.contains("<") && !text.contains(">")
            && !text.contains(" ") && !text.contains(":")
    }

    // MARK: - Private
    // The parts an `&` at the top of a spelling joins, or nothing where the
    // spelling has no such `&`: one inside brackets belongs to the argument.
    private static func joined(_ text: String) -> [Substring]? {
        var depth = 0
        var parts: [Substring] = []
        var start = text.startIndex

        for index in text.indices {
            switch text[index] {
            // `..<` is a range's far edge, and opens nothing.
            case "<" where !text[..<index].hasSuffix(".."): depth += 1
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
            return try parse(written) { name in notation.qualified(name, as: .type) }
        }

        guard let keyed = try? decoder.container(keyedBy: AnyCodingKey.self) else {
            throw ReadingError(Self.unread, at: decoder.steps)
        }

        // A mapping is a form by its one key. The form is committed by its key
        // *before* what is under it is read, so a malformed signature refuses
        // as the procedure type it claimed to be.
        switch Tagging(keyed.allKeys.map { key in (name: key.name, value: key) }, reading: TypeForm.init) {
        case let .one(.procedure(mark, constness, isolation), key):
            let form = try keyed.decode(ProcedureTypeReader.self, forKey: key)
            let written = TypeExpression.procedure(form.type, constness, isolation)

            return mark?.marking(written) ?? written

        // A declared type handed on once.
        case let .one(.linear, key):
            return .linear(try keyed.decode(TypeReader.self, forKey: key).type)

        // An array or a dictionary of something with no spelling of its own:
        // an array of procedures has no name, so it is written here.
        case let .one(.holding(holding), key):
            return holding.holding(try keyed.decode(TypeReader.self, forKey: key).type)

        case let .one(.record, key):
            return try record(from: try keyed.superDecoder(forKey: key))

        case let .among(tags):
            throw ReadingError(
                "\(tags.map { tag in "`\(tag)`" }.joined(separator: ", ")) stands alone in its mapping."
                    + " A record type with that field is written { \(recordKey): { … } }"
                    + " (found keys: \(keyed.allKeys.map(\.stringValue).sorted()))",
                at: decoder.steps
            )

        case .none:
            guard notation.readsBareRecords else { throw ReadingError(Self.unread, at: decoder.steps) }

            return try record(from: decoder)
        }
    }

    // A record type's fields, each a type.
    private static func record(from decoder: Decoder) throws -> TypeExpression {
        guard (try? decoder.container(keyedBy: AnyCodingKey.self)) != nil else {
            throw ReadingError("a record type is a mapping of its fields to their types", at: decoder.steps)
        }

        // Each field read where it stands, so a refusal inside one keeps its
        // own place and its own sentence.
        return .record(try decoder.read([Name: TypeReader].self).mapValues(\.type))
    }

    // One value, one spelling (a padded or signed-zero bound would be a second
    // spelling of the same range) and the two whole-number refusals are
    // different facts, told apart by the one reading the grammar lives in.
    private static func whole(_ written: Substring, of text: String) throws -> Int? {
        guard !written.isEmpty else { return nil }

        switch IntSpelling(String(written)) {
        case let .int(number):
            return number

        case .notOneSpelling:
            throw TypeFormError(
                "type '\(text)' bounds a range with '\(written)',"
                    + " which is not a whole number's one spelling"
            )

        case .overflow:
            throw TypeFormError(
                "type '\(text)' bounds a range with '\(written)',"
                    + " a whole number past what an Int holds"
            )
        }
    }

    // A fraction bound reads a fraction's one spelling (the same door the
    // boundary and the writer read) so `1` bounds a whole range and `1.0` a
    // fraction one, and neither spells the other's.
    private static func fraction(_ written: Substring, of text: String) throws -> Double? {
        guard !written.isEmpty else { return nil }

        guard let number = Double(spelling: String(written)) else {
            throw TypeFormError(
                "type '\(text)' bounds a range with '\(written)',"
                    + " which is not a fraction's one spelling"
            )
        }

        return number
    }

    // Which dots were written, said once: `..<` leaves the bound outside and
    // `...` holds it, and a range with no far bound has no edge to say it of.
    private static func edge<Bound: Sendable & Equatable & Comparable>(
        _ bound: Bound?,
        excluding: Bool
    ) -> TypeExpression.Refinement.Edge<Bound>? {
        guard let bound else { return nil }

        return excluding ? .upTo(bound) : .through(bound)
    }

    // The rest of the text where it begins with this, and nothing where it does
    // not.
    private static func dropPrefixed(_ prefix: String, from text: String) -> Substring? {
        text.hasPrefix(prefix) ? text.dropFirst(prefix.count) : nil
    }
}
