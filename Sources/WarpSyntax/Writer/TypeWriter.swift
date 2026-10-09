//
//  TypeWriter.swift
//  WarpSyntax
//
//  Created by JSilver on 10/1/26.
//

import Foundation
import Warp

// A type written the way `TypeReader` reads it: a spelling where the type has
// one, and a mapping under the one key its form is read by where it has none.
struct TypeWriter {
    // MARK: - Property
    // Who reads the spelling back, which says what a declared name written
    // short stands for.
    let readBy: Notation

    // MARK: - Initializer
    // MARK: - Public
    // A spelling is kept only where the reading takes it back as this type.
    func value(of type: TypeExpression) throws -> Value {
        let written = try form(of: type)

        guard case let .string(spelling) = written else { return written }

        let read: TypeExpression

        do {
            read = try TypeReader.parse(spelling, in: readBy)
        } catch {
            throw WritingError("the type is written '\(spelling)', which the reading refuses: \(error)")
        }

        guard read == canonical(type) else {
            throw WritingError(
                "the type is written '\(spelling)', which the reading takes as \(read.rendered),"
                    + " and a document has no way to tell the two apart"
            )
        }

        return written
    }

    // The bounds, written once, at the signature that declares the names.
    func bounds(of signature: Signature) -> Value? {
        guard !signature.bounds.isEmpty else { return nil }

        return .dictionary(
            signature.bounds.mapValues { named in
                Value.string(named.sorted().map(\.spelling).joined(separator: " & "))
            }
        )
    }

    // MARK: - Private
    // What a type is written as, before the reading is asked about it.
    private func form(of type: TypeExpression) throws -> Value {
        switch type {
        case .any: return .string(TypeSpelling.any.spelling)
        case .never: return .string(TypeSpelling.never.spelling)
        case .null: return .string(TypeSpelling.null.spelling)
        case .bool: return .string(TypeSpelling.bool.spelling)
        case .int: return .string(TypeSpelling.int.spelling)
        case .double: return .string(TypeSpelling.double.spelling)
        case .string: return .string(TypeSpelling.string.spelling)
        case .selfType: return .string(TypeSpelling.selfType.spelling)

        case let .named(name):
            return .string(name.spelling)

        // No document spells this. It is a type the build worked out from a
        // body, and the load refuses one written into a declaration; a draft
        // holding one is said rather than written as something else.
        case let .projection(of, path):
            throw WritingError(
                "`some \(Path([.key(of)] + path.segments).rendered)` is a type"
                    + " the build read out of a body,"
                    + " and no document writes one. A declaration says what a call"
                    + " fills"
            )

        // Bare: a slot names the parameter, and its bound is the signature's.
        case let .parameter(name):
            return .string("some \(name)")

        case let .composition(names):
            return .string(names.sorted().map(\.spelling).joined(separator: " & "))

        // Written as the name it is where the element has one, and under its
        // own key where the element has none. An array of procedures is the
        // case with none.
        case let .array(element):
            return try value(of: element, in: .array)

        case let .dictionary(element):
            return try value(of: element, in: .dictionary)

        // Spelt with the trailing `?` the reader takes, which is why the
        // declared half has to have a name of its own. A record has no spelling
        // for a `?` to trail.
        case let .nullable(inner):
            return .string(
                "\(try spelt(inner, at: "before `?`. A record is declared and written by its name, like `Task?`"))?"
            )

        // A record and a procedure are both written as a mapping, and the one
        // key is what tells them apart.
        case let .record(fields):
            return .dictionary([TypeReader.recordKey: .dictionary(try fields.mapValues(value(of:)))])

        // Both marks are written the same way, so the writing is said once
        // below. They are matched one to a case because the mark a case carries
        // is what the writing needs and a pattern cannot hand it over.
        case let .variable(inner):
            return try value(of: inner, under: .variable)

        case let .inout(inner):
            return try value(of: inner, under: .inout)

        case let .procedure(type, constness, isolation):
            guard let type else { return .string(TypeReader.procedureSpelling(constness, isolation, as: .name)) }

            let spelling = TypeReader.procedureSpelling(constness, isolation, as: .key)

            var written: [Name: Value] = [:]

            if !type.parameters.isEmpty {
                written[TypeReader.ProcedureTypeReader.CodingKeys.parameters.name] = .array(
                    try type.parameters.map(value(of:))
                )
            }

            if let returns = type.returns {
                written[TypeReader.ProcedureTypeReader.CodingKeys.returns.name] = try value(of: returns)
            }

            return .dictionary([try Name(spelling): .dictionary(written)])
        }
    }

    // The type the reading gives back for this one's spelling. One name
    // composing is spelled as the name, which the build reads back as the
    // composition where the name is a contract's.
    private func canonical(_ type: TypeExpression) -> TypeExpression {
        switch type {
        case let .composition(names):
            guard names.count == 1, let name = names.first else { return type }

            return .named(name)

        case let .array(element): return .array(canonical(element))
        case let .dictionary(element): return .dictionary(canonical(element))
        case let .nullable(inner): return .nullable(canonical(inner))
        case let .variable(inner): return .variable(canonical(inner))
        case let .inout(inner): return .inout(canonical(inner))
        default: return type
        }
    }

    // A built-in holding another type, under the reading's own key for it.
    private func value(of element: TypeExpression, in holding: TypeReader.Holding) throws -> Value {
        guard case let .string(spelling) = try form(of: element) else {
            return .dictionary([Name(normal: holding.rawValue): try value(of: element)])
        }

        return .string("\(holding.spelling)<\(spelling)>")
    }

    // A marked slot is written with the mark in front of the inner type,
    // whichever form that type takes: a bare name, or a procedure form under
    // its one key. An inline record has no front to write a mark on, and a
    // declaration's field is the one place a procedure type goes anyway.
    private func value(of inner: TypeExpression, under mark: SlotMark) throws -> Value {
        switch try form(of: inner) {
        case let .string(written):
            return .string(mark.marking(written))

        case let .dictionary(form) where form.count == 1
            && TypeReader.readsAsAProcedure(form.entries[0].name):
            // A key carries one mark, and a key carrying two reads back as a
            // record whose field is named after them.
            if let inside = SlotMark.marked(inner) {
                throw WritingError(
                    "`\(inside.rawValue)` is written inside `\(mark.rawValue)`, and a procedure's key"
                        + " carries one mark"
                )
            }

            return .dictionary([
                try Name(mark.marking(form.entries[0].name.spelling)): form.entries[0].value
            ])

        default:
            throw WritingError(
                "`\(mark.rawValue)` is written in front of a type name, and"
                    + " \(inner.rendered) is not written as one. Declare it under a"
                    + " name and write `\(mark.rawValue)` on the name"
            )
        }
    }

    // One fact (only a type with a spelling of its own composes) said with the
    // place the author wrote, so the refusal points at their text.
    private func spelt(_ type: TypeExpression, at context: String) throws -> String {
        guard case let .string(name) = try form(of: type) else {
            throw WritingError("only a type with a name is written \(context)")
        }

        return name
    }
}
