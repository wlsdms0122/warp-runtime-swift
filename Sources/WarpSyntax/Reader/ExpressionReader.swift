//
//  ExpressionReader.swift
//  WarpSyntax
//
//  Created by JSilver on 8/16/26.
//

import Foundation
import Warp

// The expression grammar. `Expression` has constructs and no spelling; this is the
// spelling. No expression hides inside a string, so every expression is
// written as data:
//
//   scalar                  . A literal, and strings are always literal text
//   array                   . Elements are expressions
//   { ref: a.b[0] }         . A name to resolve in the scope that reads it
//   { struct: { … } }       . A struct whose fields are expressions
//   { dictionary: [[k, v]] }. A dictionary whose keys and values are expressions
//   { call: <call> }        . A call where a value is wanted, the same form a
//                              statement writes
//   { closure: <procedure> }. A procedure written where a value is wanted
//   { as: { of:, type: } }  . The value read as that type; `as?` reads a
//                              mismatch as null
//
// A mapping is one of these by its one key, so a field name is never a key
// the grammar reads: a struct is written under `struct` whatever its fields
// are called.
//
// A string is never re-parsed into anything live.
struct ExpressionReader: Decodable {
    // MARK: - Property
    // What a cast reads and the type it reads it as, inside the cast's own
    // mapping.
    static let subjectKey: Name = "of"
    static let typeKey: Name = "type"

    let expression: Warp.Expression

    // MARK: - Initializer
    init(from decoder: Decoder) throws {
        self.expression = try Self.read(try ValueReader(from: decoder).value, in: decoder)
    }

    // MARK: - Public
    // The decoder comes along because a closure carries statements, which are
    // read standing where the expression stands.
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

            case .dictionary:
                return try read(mapping: ValueDecoder(standing: value, at: steps, in: decoder), in: decoder)

            // A form is a key the grammar reserves, and a name under which a
            // value stands is not one of them. So a struct value the document
            // writes is read as the literal it spells, name included, and a procedure
            // as the value it is, for the `Validator` to refuse; reading
            // either as a form would drop what it is refused for.
            case .struct, .procedure:
                return .literal(value)

            case let .existential(existential):
                return try read(existential.value, at: steps, in: decoder)
            }
        } catch let error as ExpressionFormError {
            throw ReadingError(error.message, at: steps)
        }
    }

    // One form, one function, each with its own refusals. `mapping` stands on
    // the mapping the form is written as.
    private static func read(mapping: ValueDecoder, in decoder: Decoder) throws -> Warp.Expression {
        let steps = mapping.steps
        let named = try mapping.named()
        let names = named.map(\.name)

        switch Tagging(named, reading: ExpressionTag.init) {
        case let .one(tag, written):
            let inside = steps + [.key(tag.rawValue)]

            switch tag {
            case .reference: return try reference(written, at: inside)
            case .struct: return try fields(under: written, at: inside, in: decoder)
            case .dictionary: return try entries(written, at: inside, in: decoder)
            case .call: return try call(written, at: steps, in: decoder)
            case .closure: return try closure(written, at: steps, in: decoder)
            case .cast: return try cast(written, optional: false, at: inside, in: decoder)
            case .optionalCast: return try cast(written, optional: true, at: inside, in: decoder)
            }

        // A tag stands alone in its mapping.
        case let .among(tags):
            throw ExpressionFormError(
                "\(tags.map { tag in "`\(tag)`" }.joined(separator: ", ")) stands alone in its mapping."
                    + " A struct with that field is written under `struct`"
                    + " (found keys: \(names))"
            )

        case .none:
            break
        }

        throw ExpressionFormError(
            "a mapping where a value is wanted is one of"
                + " \(ExpressionTag.allCases.map { tag in "`\(tag.key)`" }.sorted().joined(separator: ", ")),"
                + " under its one key. A struct is written under `struct`"
                + " (found keys: \(names))"
        )
    }

    // `{ struct: { … } }`: the fields, each an expression, in the key order
    // of the mapping that writes them, so that a struct literal with two bad
    // fields refuses the same one every run.
    private static func fields(
        under written: Value,
        at steps: [Place.Step],
        in decoder: Decoder
    ) throws -> Warp.Expression {
        // A struct value is data written as itself, so it reads as the literal
        // it writes, and the load holds a literal to holding no struct.
        if case .struct = written {
            return .literal(written)
        }

        guard case .dictionary = written else {
            throw ExpressionFormError("`struct` takes a mapping of its fields")
        }

        let named = try ValueDecoder(standing: written, at: steps, in: decoder).named()

        return .struct(
            try named.reduce(into: [Name: Warp.Expression]()) { fields, entry in
                fields[entry.name] = try read(entry.value, at: steps + [.key(entry.name.spelling)], in: decoder)
            }
        )
    }

    // `{ dictionary: [[<key>, <value>], …] }`: the entries in the order
    // written, each a list of two expressions.
    private static func entries(
        _ written: Value,
        at steps: [Place.Step],
        in decoder: Decoder
    ) throws -> Warp.Expression {
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
            return .reference(try PathParser().parse(rendered, at: steps.count))
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

        // A type is written as a string, and anything else is refused where
        // it stands, under `type`.
        let type: TypeExpression

        do {
            if case let .string(spelling) = spelled {
                type = try TypeReader(at: inside + [.key(Self.typeKey.spelling)]).written(spelling).unbounded()
            } else {
                let below = ValueDecoder(below: decoder, key: Self.typeKey.spelling, holding: spelled, at: inside)

                type = try TypeReader.Written(from: below).unbounded()
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
            let key = ExpressionTag.closure.key.spelling
            let below = ValueDecoder(below: decoder, key: key, holding: written, at: steps)

            return .closure(try ProcedureReader(from: below).procedure)
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
            let below = ValueDecoder(below: decoder, key: ExpressionTag.call.key.spelling, holding: written, at: steps)

            return try CallForm(from: below).expression
        } catch let refusal as ReadingError {
            throw refusal
        } catch {
            throw ExpressionFormError("`call`: \(error)")
        }
    }
}
