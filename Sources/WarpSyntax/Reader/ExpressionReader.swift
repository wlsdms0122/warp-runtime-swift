//
//  ExpressionReader.swift
//  WarpSyntax
//
//  Created by JSilver on 8/16/26.
//

import Foundation
import Warp

// The expression grammar. `Expression` has constructs and no spelling; this is the
// spelling. No front end may hide an expression inside a string, so any
// notation that can write a record can write every expression:
//
//   scalar                  . A literal, and strings are always literal text
//   array                   . Elements are expressions
//   { ref: a.b[0] }         . A name to resolve in the scope that reads it
//   { record: { … } }       . A record whose fields are expressions
//   { call: <call> }        . A call where a value is wanted, the same form a
//                              statement writes
//   { closure: <procedure> }. A procedure written where a value is wanted
//   { as: { of:, type: } }  . The value read as that type; `as?` reads a
//                              mismatch as null
//
// A mapping is one of these by its one key, so a field name is never a key
// the grammar reads: a record is written under `record` whatever its fields
// are called.
//
// A string is never re-parsed into anything live.
public struct ExpressionReader: Decodable {
    // MARK: - Property
    // What a cast reads and the type it reads it as, inside the cast's own
    // mapping.
    static let subjectKey: Name = "of"
    static let typeKey: Name = "type"

    public let expression: Warp.Expression

    // MARK: - Initializer
    public init(from decoder: Decoder) throws {
        self.expression = try Self.read(try ValueReader(from: decoder).value, in: decoder)
    }

    // MARK: - Public
    // The decoder comes along because a closure carries statements, and which
    // construct keys a statement may write is the registry's answer, which
    // travels in the decoder.
    static func read(_ value: Value, in decoder: Decoder) throws -> Warp.Expression {
        try read(value, at: decoder.steps, in: decoder)
    }

    // MARK: - Private
    // A walk down an expression's value. The decoder stops at the key the
    // expression is written under, and the steps below it are this walk's, so
    // they travel here. A grammar refusal is given the innermost walk's
    // address here; one that already has an address is deeper and passes.
    private static func read(
        _ value: Value,
        at steps: [Place.Step],
        in decoder: Decoder
    ) throws -> Warp.Expression {
        do {
            switch value {
            case .null, .bool, .int, .double, .string, .bytes:
                return .literal(value)

            case let .array(array):
                return .array(
                    try array.enumerated().map { offset, element in
                        try read(element, at: steps + [.index(offset)], in: decoder)
                    }
                )

            case let .dictionary(fields):
                return try read(mapping: fields, at: steps, in: decoder)

            // A form is keys the notation reserved, and a name under which a
            // value stands is not one of them. So a record the document named
            // is read as the literal it spells, name included, and a procedure
            // as the value it is, for the `Validator` to refuse; reading
            // either as a form would drop what it is refused for.
            case .record, .procedure:
                return .literal(value)
            }
        } catch let error as ExpressionFormError {
            throw ReadingError(error.message, at: steps)
        }
    }

    // One form, one function, each with its own refusals.
    private static func read(
        mapping: Value.Dictionary,
        at steps: [Place.Step],
        in decoder: Decoder
    ) throws -> Warp.Expression {
        switch Tagging(try mapping.named(), reading: ExpressionTag.init) {
        case let .one(tag, written):
            let inside = steps + [.key(tag.rawValue)]

            switch tag {
            case .reference: return try reference(written, at: inside)
            case .record: return try fields(under: written, at: inside, in: decoder)
            case .dictionary: return try entries(written, at: inside, in: decoder)
            case .call: return try call(written, at: steps, in: decoder)
            case .closure: return try closure(written, at: steps, in: decoder)
            case .cast: return try cast(written, optional: false, at: inside, in: decoder)
            case .optionalCast: return try cast(written, optional: true, at: inside, in: decoder)
            }

        // A tag stands alone in every notation, whatever a notation's
        // spellings would make of the keys beside it.
        case let .among(tags):
            throw ExpressionFormError(
                "\(tags.map { tag in "`\(tag)`" }.joined(separator: ", ")) stands alone in its mapping."
                    + " A record with that field is written under `record`"
                    + " (found keys: \(try mapping.named().map(\.name)))"
            )

        case .none:
            break
        }

        if let spelled = try spelled(mapping, at: steps, in: decoder) { return spelled }

        if !Set(try mapping.named().map(\.name)).isDisjoint(with: Interpolation.keys) { return try template(in: mapping, at: steps, in: decoder) }

        throw ExpressionFormError(
            "a mapping where a value is wanted is one of"
                + " \(ExpressionTag.allCases.map { tag in "`\(tag.key)`" }.sorted().joined(separator: ", ")),"
                + " under its one key. A record is written under `record`"
                + " (found keys: \(try mapping.named().map(\.name)))"
        )
    }

    // A mapping the notation spells, read by the notation. Asked only of a
    // mapping that is not a tag's, and nothing where the notation spells
    // nothing or does not claim it.
    private static func spelled(
        _ mapping: Value.Dictionary,
        at steps: [Place.Step],
        in decoder: Decoder
    ) throws -> Warp.Expression? {
        guard
            let spelling = decoder.notation.spelling,
            spelling.claims(Set(try mapping.named().map(\.name)), in: decoder.notation)
        else { return nil }

        return try spelling.expression(
            from: ValueDecoder(standing: .dictionary(mapping), at: steps, in: decoder),
            in: decoder.notation
        )
    }

    // `{ record: { … } }`: the fields, each an expression, in the record's
    // order, so that a record with two bad fields refuses the same one every
    // run.
    private static func fields(
        under written: Value,
        at steps: [Place.Step],
        in decoder: Decoder
    ) throws -> Warp.Expression {
        // A named record is data written as itself, so it reads as the literal
        // it writes, and the load holds a literal to holding no record.
        if case .record = written {
            return .literal(written)
        }

        guard case let .dictionary(mapping) = written else {
            throw ExpressionFormError("`record` takes a mapping of its fields")
        }

        return .record(
            try mapping.named().reduce(into: [Name: Warp.Expression]()) { fields, entry in
                fields[entry.name] = try read(
                    entry.value,
                    at: steps + [.key(entry.name.spelling)],
                    in: decoder
                )
            }
        )
    }

    // `{ dictionary: [[<key>, <value>], …] }`: the entries in the order
    // written, each a list of two expressions.
    private static func entries(_ written: Value, at steps: [Place.Step], in decoder: Decoder) throws -> Warp.Expression {
        let refusal = "`dictionary` takes its entries as a list, each a list of two: its key and its value"

        guard case let .array(entries) = written else { throw ReadingError(refusal, at: steps) }

        return .dictionary(
            try entries.enumerated().map { position, entry in
                guard case let .array(pair) = entry, pair.count == 2 else {
                    throw ReadingError(refusal, at: steps + [.index(position)])
                }

                return (
                    key: try read(pair[0], at: steps + [.index(position), .index(0)], in: decoder),
                    value: try read(pair[1], at: steps + [.index(position), .index(1)], in: decoder)
                )
            }
        )
    }

    private static func reference(_ written: Value, at steps: [Place.Step]) throws -> Warp.Expression {
        guard case let .string(rendered) = written else {
            throw ReadingError("`ref` takes a path string like `a.b[0]`", at: steps)
        }

        do {
            return .reference(try PathParser().parse(rendered))
        } catch {
            throw ReadingError("`ref` '\(rendered)': \(error)", at: steps)
        }
    }

    // `{ as: { of: <value>, type: <type> } }`, and `as?` for the reading that
    // takes a mismatch as null.
    private static func cast(
        _ written: Value,
        optional: Bool,
        at inside: [Place.Step],
        in decoder: Decoder
    ) throws -> Warp.Expression {
        let key = (optional ? ExpressionTag.optionalCast : ExpressionTag.cast).key

        guard
            case let .dictionary(cast) = written,
            cast.count == 2,
            let subject = cast[Self.subjectKey],
            let spelled = cast[Self.typeKey]
        else {
            throw ExpressionFormError("`\(key)` takes `of`, the value, and `type`, the type, and nothing else")
        }

        // A type has two spellings and a cast takes either: the string a
        // built-in or a declared name is written as, and the mapping a
        // record or a procedure signature is written as.
        let type: TypeExpression

        do {
            if case let .string(spelling) = spelled {
                type = try TypeReader.parse(spelling, in: decoder.notation)
            } else {
                type = try TypeReader(from: ValueDecoder(below: decoder, key: Self.typeKey.spelling, holding: spelled, at: inside))
                    .type
            }
        } catch let error as TypeFormError {
            throw ExpressionFormError("{ \(key): }: \(error.message)")
        }

        return .cast(
            try Self.read(subject, at: inside + [.key(Self.subjectKey.spelling)], in: decoder),
            as: type,
            optional: optional
        )
    }

    private static func closure(
        _ written: Value,
        at steps: [Place.Step],
        in decoder: Decoder
    ) throws -> Warp.Expression {
        do {
            return .closure(
                try ProcedureReader(from: ValueDecoder(below: decoder, key: ExpressionTag.closure.key.spelling, holding: written, at: steps))
                    .procedure
            )
        } catch let refusal as ReadingError {
            // A reading that says where it is says it deeper than here, and
            // folding it into this form's sentence would spend the address
            // to say it again.
            throw refusal
        } catch {
            throw ExpressionFormError("`closure`: \(error)")
        }
    }

    private static func call(
        _ written: Value,
        at steps: [Place.Step],
        in decoder: Decoder
    ) throws -> Warp.Expression {
        do {
            return try CallForm(from: ValueDecoder(below: decoder, key: ExpressionTag.call.key.spelling, holding: written, at: steps))
                .expression
        } catch let refusal as ReadingError {
            throw refusal
        } catch {
            throw ExpressionFormError("`call`: \(error)")
        }
    }

    private static func template(
        in mapping: Value.Dictionary,
        at steps: [Place.Step],
        in decoder: Decoder
    ) throws -> Warp.Expression {
        // A notation may decline to offer a template, and then these keys are
        // refused rather than read as an ordinary record. Giving up a spelling
        // says a text may not write it; it does not hand the keys back to mean
        // something else.
        guard let interpolation = decoder.notation.interpolation else {
            throw ExpressionFormError(
                "this notation does not spell a template. Put the text together"
                    + " by sending the procedures that put text together"
            )
        }

        guard try mapping.named().map(\.name).contains(Interpolation.formatKey) else {
            // Only `with` remains, and `with` is `format`'s companion.
            throw ExpressionFormError(
                "`with` only accompanies `format` (found keys: \(try mapping.named().map(\.name)))"
            )
        }

        guard Set(try mapping.named().map(\.name)).subtracting(Interpolation.keys).isEmpty else {
            throw ExpressionFormError(
                "a record with `format` holds `format`, the template, and `with`, its bindings,"
                    + " and nothing else (found keys: \(try mapping.named().map(\.name)))"
            )
        }

        guard case let .string(template)? = mapping[Interpolation.formatKey] else {
            throw ExpressionFormError("`format` takes a template string")
        }

        let bindings: [Name: Warp.Expression]

        switch mapping[Interpolation.withKey] {
        case nil:
            bindings = [:]

        case let .dictionary(written)?:
            bindings = try written.named().reduce(into: [Name: Warp.Expression]()) { bound, entry in
                bound[entry.name] = try read(
                    entry.value,
                    at: steps + [.key(Interpolation.withKey.spelling), .key(entry.name.spelling)],
                    in: decoder
                )
            }

        case let other?:
            throw ExpressionFormError(
                "`format`'s `with` takes a record of bindings,"
                    + " got \(other.nominal)"
            )
        }

        let segments: [TemplateSegment]

        do {
            segments = try TemplateParser().parse(template)
        } catch {
            throw ExpressionFormError("`format`'s template: \(error)")
        }

        return try spent(segments, over: bindings, spending: interpolation)
    }

    // A template as the procedures that build it. Interpolation is a spelling rather
    // than a thing the language has: each piece becomes a literal or a value
    // asked how it reads, and the pieces are written one after another.
    //
    // Spent here, a placeholder is an ordinary reference, checked, linked and
    // refused the way every other reference is.
    private static func spent(
        _ segments: [TemplateSegment],
        over bindings: [Name: Warp.Expression],
        spending interpolation: Interpolation
    ) throws -> Warp.Expression {
        let pieces: [Warp.Expression] = try segments.map { segment in
            switch segment {
            case let .text(literal):
                return .literal(.string(literal))

            case let .ref(path):
                return .call(
                    Call(
                        selector: interpolation.read,
                        arguments: [try substituted(path, over: bindings)]
                    )
                )
            }
        }

        // One piece that is already text is that text. Nothing is written one
        // after another when there is nothing to write it after.
        if pieces.count == 1, case let .literal(.string(only)) = pieces[0] {
            return .literal(.string(only))
        }

        return .call(Call(selector: interpolation.joined, arguments: [.array(pieces), .literal(.string(""))]))
    }

    // A placeholder names a binding and then drills into it, so what it reads is
    // the binding's expression with the rest of the path walked from there. A
    // binding that is itself a reference keeps one path rather than growing a
    // call around itself.
    //
    // Every name in the path is substituted, not only the head. An index
    // reference is a path of its own inside this one, and leaving it as written
    // would have it read from whatever scope the statement runs in. A template
    // sees only its own bindings, so a name `with` does not bind is refused.
    private static func substituted(
        _ path: Path,
        over bindings: [Name: Warp.Expression]
    ) throws -> Warp.Expression {
        guard let head = path.head, let bound = bindings[head] else {
            throw ExpressionFormError(
                "`format`'s placeholder ${\(path.rendered)} names"
                    + " no binding this template was given"
            )
        }

        let rest = try path.segments.dropFirst().map { segment in
            try closing(segment, over: bindings)
        }

        guard !rest.isEmpty else { return bound }

        // Drilling continues a path, and only a path can be continued. Reading
        // the placeholder as written would reach the ambient scope, so it is
        // refused instead.
        guard case let .reference(prefix) = bound else {
            throw ExpressionFormError(
                "`format`'s placeholder ${\(path.rendered)} drills into"
                    + " '\(head)', which is bound to something other than a name"
            )
        }

        return .reference(prefix.appending(contentsOf: rest))
    }

    // A segment with any path inside it closed over the same bindings. Only an
    // index reference holds one; the rest name nothing.
    private static func closing(
        _ segment: PathSegment,
        over bindings: [Name: Warp.Expression]
    ) throws -> PathSegment {
        guard case let .indexRef(inner, optionally) = segment else { return segment }

        guard case let .reference(closed) = try substituted(inner, over: bindings) else {
            throw ExpressionFormError(
                "`format`'s index ${\(inner.rendered)} is bound to something"
                    + " other than a name, and an index reads a name"
            )
        }

        return .indexRef(closed, optional: optionally)
    }
}
