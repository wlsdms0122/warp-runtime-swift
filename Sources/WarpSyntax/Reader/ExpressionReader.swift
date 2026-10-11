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
// are called. A notation may read a bare mapping as a record, and the tags
// stand alone there too.
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
    // The decoder comes along because one form needs more than the value: a
    // closure carries statements, and which construct keys a statement may
    // write is the registry's answer, which travels in the decoder rather than
    // in the data. A form reading an expression goes through `init(from:)`,
    // where a refusal from this grammar is given the address of the walk that
    // asked for it.
    static func read(_ value: Value, in decoder: Decoder) throws -> Warp.Expression {
        try read(value, at: decoder.steps, in: decoder)
    }

    // MARK: - Private
    // An expression is a value with a value inside it, so reading one is a walk
    // like any other and it records where it is like any other. The decoder
    // stops at the key the expression is written under and everything below
    // that is this walk's own descent, which is why the steps travel here as
    // well as in the decoder. A walk that carried only the decoder's would
    // answer for a record ten fields deep with the address of the record.
    //
    // This is also where the grammar's refusal is given an address. It is
    // written wherever an expression is spelled, so it carries none of its own,
    // and the innermost walk that was reading is the one that knows. A refusal
    // that already has an address is deeper than this one and passes.
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
                return try read(record: fields, at: steps, in: decoder)

            // A form is keys the notation reserved, and a name under which a
            // value stands is not one of them. So a value the document named
            // is read as the literal it spells, name included, and a procedure
            // as the value it is, for the `Validator` to refuse; reading
            // either as a form would drop what it is refused for.
            case let .record(record) where record.name != nil:
                return .literal(value)

            case .procedure:
                return .literal(value)

            case let .record(record):
                return try read(record: record.asDictionary, at: steps, in: decoder)
            }
        } catch let error as ExpressionFormError {
            throw ReadingError(error.message, at: steps)
        }
    }

    // One form, one function. What a form refuses with is written in that
    // function alone, so the walk down through a nested call carries the
    // frame of the call form and not the sentences of the five it is not.
    private static func read(
        record: Value.Dictionary,
        at steps: [Place.Step],
        in decoder: Decoder
    ) throws -> Warp.Expression {
        switch Tagging(record.entries, reading: ExpressionTag.init) {
        case let .one(tag, written):
            let inside = steps + [.key(tag.rawValue)]

            switch tag {
            case .reference: return try reference(written, at: inside)
            case .record: return try fields(under: written, at: inside, in: decoder)
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
                    + " A record with that field is written { record: { … } }"
                    + " (found keys: \(record.names))"
            )

        case .none:
            break
        }

        if let spelled = try spelled(record, at: steps, in: decoder) { return spelled }

        if !Set(record.names).isDisjoint(with: Interpolation.keys) { return try template(in: record, at: steps, in: decoder) }

        guard decoder.notation.readsBareRecords else {
            throw ExpressionFormError(
                "a mapping where a value is wanted is one of"
                    + " \(ExpressionTag.allCases.map { tag in "`\(tag.key)`" }.sorted().joined(separator: ", ")),"
                    + " under its one key. A record is written { record: { … } }"
                    + " (found keys: \(record.names))"
            )
        }

        return try fields(in: record, at: steps, in: decoder)
    }

    // A mapping the notation spells, read by the notation. Asked only of a
    // mapping that is not a tag's, and nothing where the notation spells
    // nothing or does not claim it.
    private static func spelled(
        _ record: Value.Dictionary,
        at steps: [Place.Step],
        in decoder: Decoder
    ) throws -> Warp.Expression? {
        guard
            let spelling = decoder.notation.spelling,
            spelling.claims(Set(record.names), in: decoder.notation)
        else { return nil }

        return try spelling.expression(
            from: ValueDecoder(standing: .dictionary(record), at: steps, in: decoder),
            in: decoder.notation
        )
    }

    // `{ record: { … } }`: the fields, each an expression.
    private static func fields(
        under written: Value,
        at steps: [Place.Step],
        in decoder: Decoder
    ) throws -> Warp.Expression {
        // A named record is data written as itself, so it reads as the literal
        // it writes, and the load holds a literal to writing no record's name.
        if case let .record(named) = written, named.name != nil {
            return .literal(written)
        }

        guard let record = written.asDictionary else {
            throw ExpressionFormError("{ record: } takes a mapping of its fields")
        }

        return try fields(in: record, at: steps, in: decoder)
    }

    // A record of expressions, in the record's order, so that a record with
    // two bad fields refuses the same one every run.
    private static func fields(
        in record: Value.Dictionary,
        at steps: [Place.Step],
        in decoder: Decoder
    ) throws -> Warp.Expression {
        .record(
            try record.entries.reduce(into: [Name: Warp.Expression]()) { fields, entry in
                fields[entry.name] = try read(
                    entry.value,
                    at: steps + [.key(entry.name.spelling)],
                    in: decoder
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
            let cast = written.asDictionary,
            cast.count == 2,
            let subject = cast[Self.subjectKey],
            let spelled = cast[Self.typeKey]
        else {
            throw ExpressionFormError("{ \(key): } takes { of: <value>, type: <type> }")
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
            throw ExpressionFormError("{ closure: }: \(error)")
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
            throw ExpressionFormError("{ call: }: \(error)")
        }
    }

    private static func template(
        in record: Value.Dictionary,
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

        guard record.names.contains(Interpolation.formatKey) else {
            // Only `with` remains, and `with` is `format`'s companion.
            throw ExpressionFormError(
                "`with` only accompanies `format` (found keys: \(record.names))"
            )
        }

        guard Set(record.names).subtracting(Interpolation.keys).isEmpty else {
            throw ExpressionFormError(
                "a record with `format` must be exactly { format: <template>,"
                    + " with: <bindings> } (found keys: \(record.names))"
            )
        }

        guard case let .string(template)? = record[Interpolation.formatKey] else {
            throw ExpressionFormError("{ format: } takes a template string")
        }

        let bindings: [Name: Warp.Expression]

        switch record[Interpolation.withKey] {
        case nil:
            bindings = [:]

        case let .dictionary(withRecord)?:
            bindings = try withRecord.entries.reduce(into: [Name: Warp.Expression]()) { bound, entry in
                bound[entry.name] = try read(
                    entry.value,
                    at: steps + [.key(Interpolation.withKey.spelling), .key(entry.name.spelling)],
                    in: decoder
                )
            }

        case let other?:
            throw ExpressionFormError(
                "{ format: } `with` takes a record of bindings,"
                    + " got \(other.nominal)"
            )
        }

        let segments: [TemplateSegment]

        do {
            segments = try TemplateParser().parse(template)
        } catch {
            throw ExpressionFormError("{ format: } template: \(error)")
        }

        return try lowered(segments, over: bindings, spending: interpolation)
    }

    // A template as the procedures that build it. Interpolation is a spelling rather
    // than a thing the language has: each piece becomes a literal or a value
    // asked how it reads, and the pieces are written one after another.
    //
    // Lowering here is what makes a placeholder an ordinary reference. It is
    // checked, linked and refused the way every other reference is, instead of
    // being a type only the template walk knew how to read.
    private static func lowered(
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
                "{ format: } placeholder ${\(path.rendered)} names"
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
                "{ format: } placeholder ${\(path.rendered)} drills into"
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
                "{ format: } index ${\(inner.rendered)} is bound to something"
                    + " other than a name, and an index reads a name"
            )
        }

        return .indexRef(closed, optional: optionally)
    }
}
