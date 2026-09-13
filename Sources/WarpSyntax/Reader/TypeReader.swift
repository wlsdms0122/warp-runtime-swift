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
//   dictionary<Task>              . The same, for a map of string keys
//   Task                      . A name some module declares
//   { id: string, done: bool }. A record, written as the record it describes
//   { procedure: { parameters:, returns: } }
//                             . A procedure, written as the signature it takes.
//                                Bare `procedure` says only that it is one
//
// A record is a mapping and a parameter is also written as a mapping, which
// would be ambiguous if both could appear in the same slot. They cannot: a
// parameter's record always carries `type`, and a record type is only ever the
// value of that key.
public struct TypeReader: Decodable {
    // MARK: - Property
    public let type: TypeExpression

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
    // The one key a type handed on once is written under.
    public static let linearKey = "linear"

    public static func parse(_ written: String) throws -> TypeExpression {
        let text = written.trimmingCharacters(in: .whitespaces)

        guard !text.isEmpty else {
            throw TypeFormError("a type name must not be empty")
        }

        // A trailing `?` reads first because it wraps the whole spelling:
        // `array<int>?` is a nullable array, and what may be inside the
        // brackets never carries one. `?` speaks about a slot, and only the
        // whole spelling is one. `inout` and `var` stand in front of the whole
        // type, including a trailing `?`, so they are read before anything else
        // is.
        if let (mark, bare) = SlotMark.leading(of: text) {
            let inner = try parse(bare)

            if let inside = SlotMark.marked(inner) {
                throw TypeFormError(
                    "type '\(text)' writes `\(inside.rawValue)` inside"
                        + " `\(mark.rawValue)`. \(SlotMark.saysOneThing)"
                )
            }

            return mark.marking(inner)
        }

        guard let (purity, isolation, rest) = Self.modifiers(of: text) else {
            throw TypeFormError("type '\(text)' writes a procedure twice. Once says it")
        }

        if purity == .pure || isolation == .isolated {
            guard case let .procedure(signature, _, _) = try parse(rest) else {
                throw TypeFormError("only a procedure is written pure or isolated")
            }

            return .procedure(signature, purity, isolation)
        }

        if text.hasSuffix("?") {
            let inner = try parse(String(text.dropLast()))

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
                    "type '\(text)' writes `?` on never, which no value is"
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

        // Purity is a keyword in front rather than an argument, because it says
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
            // parameter apart from the reading the link derives for a walk
            // through one, which is named for the dotted path that reached it.
            guard isName(bare), !bare.contains(".") else {
                throw TypeFormError(
                    "type '\(text)' names no type parameter. Write `some` and one"
                        + " bare name; a constraint is declared in the signature's `bounds`"
                )
            }

            return .parameter(name: try named(bare))
        }


        // A range is spelled into the name: `int(0...255)`,
        // `double(0.0..<1.0)`. Either bound optional but not both, and `..<`
        // leaving the far bound outside. Only a number takes one: a range is a
        // condition on a number, and no other kind is one. Which kind is
        // written out, because a bound is a value of the kind it bounds and the
        // two read their spellings differently.
        for kind in ["int", "double"] where text.hasPrefix("\(kind)(") && text.hasSuffix(")") {
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

            return kind == "int"
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

            let name = try named(text)

            return Self.builtins[name] ?? .named(name)
        }

        let head = String(text[text.startIndex ..< open])

        guard text.hasSuffix(">") else {
            throw TypeFormError("type '\(text)' opens an argument it never closes")
        }

        let inner = String(text[text.index(after: open) ..< text.index(before: text.endIndex)])

        switch head {
        case "array":
            return .array(try parse(inner))

        case "dictionary":
            return .dictionary(try parse(inner))

        default:
            throw TypeFormError(
                "type '\(head)' takes no argument. Only `array<…>` and `dictionary<…>` do"
            )
        }
    }

    // The names this notation answers with a type of its own, and the keys that
    // make a mapping a procedure rather than a record. Both are read here and
    // both decide what a document *cannot* say, so writing one asks for them.
    public static var builtinNames: Set<Name> { Set(builtins.keys) }

    // Whether the reading takes this key as a procedure form's. Asked of the
    // reading itself rather than of a list beside it, because a list and a
    // parser drift and what they disagree about is a document one of them
    // writes and the other refuses.
    public static func readsAsAProcedure(_ key: Name) -> Bool {
        ((try? procedureKeywords(of: key.spelling)) ?? nil) != nil
    }

    // Whether the reading takes this key as anything but a record's field
    // name, the keys it refuses outright included: a record written under one
    // would come back as something else, or not come back.
    public static func readsPastARecord(_ key: Name) -> Bool {
        do {
            return try procedureKeywords(of: key.spelling) != nil || key.spelling == linearKey
        } catch {
            return true
        }
    }

    // What a procedure form's key says, read front to back: a slot's mark if one
    // is written, the modifiers in either order, and `procedure`. Nil where the
    // key is not a procedure form's.
    //
    // The mark comes back as itself rather than as something that applies it,
    // so that what was read stays a value the caller can ask about.
    static func procedureKeywords(
        of key: String
    ) throws -> (mark: SlotMark?, purity: Purity, isolation: Isolation)? {
        let (mark, rest) = SlotMark.leading(of: key).map { read in (Optional(read.mark), read.rest) } ?? (nil, key)

        // The same rule the spelling of a whole type is read by, on the key a
        // procedure form is written under. Without it a second mark leaves the
        // key unread and the form comes back as a record named after it.
        //
        // Asked only of a key that is otherwise a procedure form's. Any other
        // key is a record's field name, and a field is named whatever a
        // document named it.
        if
            let mark,
            let inside = SlotMark.leading(of: rest)?.mark,
            let (_, _, head) = modifiers(of: SlotMark.unmarked(rest)),
            head == "procedure"
        {
            throw TypeFormError(
                "type '\(key)' writes `\(inside.rawValue)` inside `\(mark.rawValue)`."
                    + " \(SlotMark.saysOneThing)"
            )
        }

        guard
            let (purity, isolation, head) = modifiers(of: rest),
            head == "procedure"
        else {
            return nil
        }

        return (mark, purity, isolation)
    }

    // The one spelling of a procedure type's head: `pure` before `isolated`,
    // both before `procedure`.
    public static func procedureSpelling(_ purity: Purity, _ isolation: Isolation) -> String {
        [purity == .pure ? "pure" : nil, isolation == .isolated ? "isolated" : nil, "procedure"]
            .compactMap { part in part }
            .joined(separator: " ")
    }

    // The modifiers at the front of a type's text, in either order, and the
    // text left after them. Nil where a modifier is written twice.
    static func modifiers(of text: String) -> (Purity, Isolation, String)? {
        var rest = text
        var purity = Purity.unstated
        var isolation = Isolation.unstated

        while true {
            if let bare = rest.dropPrefixed("pure ") {
                guard purity == .unstated else { return nil }
                purity = .pure
                rest = String(bare)
            } else if let bare = rest.dropPrefixed("isolated ") {
                guard isolation == .unstated else { return nil }
                isolation = .isolated
                rest = String(bare)
            } else {
                return (purity, isolation, rest)
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

    // One name with nothing structural in it. What a type parameter's spelling
    // has to be, and what a `bounds` value has to be: the two halves of one
    // notation, held to one predicate.
    static func isName(_ text: String) -> Bool {
        !text.isEmpty && !text.contains("<") && !text.contains(">")
            && !text.contains(" ") && !text.contains(":")
    }

    // MARK: - Private
    private static func read(from decoder: Decoder) throws -> TypeExpression {
        if let written = try? decoder.singleValueContainer().decode(String.self) {
            return try parse(written)
        }

        // A record and a procedure are both mappings, so one of them has to be
        // told apart by its key. A single `procedure` key is the procedure
        // form; anything else is a record, and a record cannot have a lone
        // field by that name, which the writer refuses to produce for the same
        // reason. The form is committed by its key *before* the signature is
        // read, so a malformed signature refuses as the procedure type it
        // claimed to be rather than quietly reading as a record.
        if
            let keyed = try? decoder.container(keyedBy: AnyCodingKey.self),
            keyed.allKeys.count == 1,
            let key = keyed.allKeys.first,
            let (mark, purity, isolation) = try procedureKeywords(of: key.stringValue)
        {
            let signature = try keyed.decode(SignatureFormReader.self, forKey: key)
            let written = TypeExpression.procedure(signature.signature, purity, isolation)

            return mark?.marking(written) ?? written
        }

        // A declared type handed on once, told apart by its key the way the
        // procedure form is. A record cannot have a lone field by that name,
        // which the writer refuses to produce for the same reason.
        if
            let keyed = try? decoder.container(keyedBy: AnyCodingKey.self),
            keyed.allKeys.count == 1,
            let key = keyed.allKeys.first,
            key.stringValue == linearKey
        {
            return .linear(try keyed.decode(TypeReader.self, forKey: key).type)
        }

        guard
            let fields = try? decoder
                .singleValueContainer()
                .decode([String: TypeReader].self)
        else {
            throw ReadingError(
                "a type is a name like `string`, `array<string>` or"
                    + " `Task`, or a record like { id: string }",
                at: decoder.steps
            )
        }

        return .record(try fields.mapValues(\.type).named(at: decoder.steps))
    }

    // One value, one spelling (a padded or signed-zero bound would be a second
    // spelling of the same range) and the two whole-number refusals are
    // different facts, told apart by the one reading the grammar lives in.
    private static func whole(_ written: Substring, of text: String) throws -> Int? {
        guard !written.isEmpty else { return nil }

        switch Int.reading(spelling: String(written)) {
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
                    + " a whole number past what an int holds"
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

    private static let builtins: [Name: TypeExpression] = [
        "any": .any,
        // A declaration a call never comes back from. Written out loud because
        // a procedure that always refuses is a procedure an author may declare.
        "never": .never,
        "null": .null,
        "bool": .bool,
        "int": .int,
        "double": .double,
        "string": .string,
        "bytes": .bytes,
        // Whole or fraction, for a slot that means both.
        "number": .number,
        // Bare, these mean "a list of anything" and "a map of anything". The
        // most a declaration could say before it could say more.
        "array": .array(.any),
        "dictionary": .dictionary(.any),
        "procedure": .procedure(nil)
    ]

}

private extension String {
    // The rest of the text where it begins with this, and nothing where it does
    // not.
    func dropPrefixed(_ prefix: String) -> Substring? {
        hasPrefix(prefix) ? dropFirst(prefix.count) : nil
    }
}

// The signature inside a procedure type: what a call may pass and what it gets
// back, written the way a procedure writes them.
private struct SignatureFormReader: Decodable {
    // No `bounds` here on purpose: a nested signature's parameters are the
    // declaring procedure's own slots, so the declaring signature owns every
    // bound. Two `bounds` records binding one name would be two claims about
    // one thing, written a document apart.
    private enum CodingKeys: String, CodingKey, CaseIterable {
        case parameters
        case receiver
        case returns
    }

    // MARK: - Property
    let signature: Signature

    // MARK: - Initializer
    init(from decoder: Decoder) throws {
        try KeyGate().rejectUnknownKeys(
            in: decoder,
            known: CodingKeys.self,
            context: "procedure type"
        )

        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.signature = Signature(
            receiver: try container.decodeIfPresent(String.self, forKey: .receiver)
                .map { spelling in try Name.read(spelling, at: decoder.steps) },
            parameters: try container
                .decodeIfPresent(SignatureReader.self, forKey: .parameters)?
                .signature.parameters ?? [:],
            returns: try container
                .decodeIfPresent(TypeReader.self, forKey: .returns)?
                .type
        )
    }

    // MARK: - Public
    // MARK: - Private
}
