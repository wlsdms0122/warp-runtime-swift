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
            read = try TypeReader.parse(spelling) { name in readBy.qualified(name, as: .type) }
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

    func stripped(_ signature: Signature) -> Signature {
        Signature(
            parameters: signature.parameters.map { parameter in
                Parameter(
                    name: parameter.name,
                    type: parameter.type.map(stripped),
                    candidates: parameter.candidates,
                    description: parameter.description
                )
            },
            returns: signature.returns.map(stripped)
        )
    }

    // The bounds, gathered from every occurrence (the nested ones included,
    // because a nested signature's parameters are this signature's own slots)
    // and written once, at the declaring signature. A name two occurrences
    // bound differently is two claims about one thing: a signature the link
    // refuses has no document.
    func bounds(of signature: Signature) throws -> Value? {
        let held = signature.parameterBounds

        if let refusal = held.refusal {
            throw WritingError(refusal + ", so there is no `bounds` to write")
        }

        let bounds = held.table
            .filter { _, constraints in !constraints.isEmpty }
            .mapValues { constraints in Value.string(constraints.sorted().map(\.spelling).joined(separator: " & ")) }

        return bounds.isEmpty ? nil : .dictionary(bounds)
    }

    // MARK: - Private
    // What a type is written as, before the reading is asked about it.
    private func form(of type: TypeExpression) throws -> Value {
        switch type {
        case .any: return .string("any")
        case .never: return .string("never")
        case .null: return .string("null")
        case .bool: return .string("bool")
        case .int: return .string("int")
        case .double: return .string("double")
        case .string: return .string("string")

        // The range rides in the name's spelling (`int(0...255)`) the way the
        // reader takes it in. A bound with no spelling has nothing to ride in:
        // the language admits an infinity, because it orders like any other
        // bound, and a document that carried the words a message shows it in
        // would read back as an error. Said rather than written as something
        // else, the way an unwritable type is.
        case let .ranged(refinement):
            guard refinement.spellable else {
                throw WritingError(
                    "'\(type.rendered)' is bounded by a fraction no document spells,"
                        + " and a range is written as its bounds"
                )
            }

            return .string(type.rendered)

        case let .named(name):
            return .string(name.spelling)

        // No document spells this. It is a type the link worked out from a
        // body, and the link refuses one written into a declaration. Reaching
        // here means a type got past that, so it is said rather than silently
        // written as something else.
        case let .reading(of, path):
            throw WritingError(
                "`some \(Path([.key(of)] + path.segments).rendered)` is a type"
                    + " the build read out of a body,"
                    + " and no document writes one. A declaration says what a call"
                    + " fills"
            )

        // Bare, because an occurrence names the parameter and its constraint is
        // written once, in the `bounds` of the signature that declares the
        // name. A signature entry strips the bound before writing and emits it
        // there, so a bound still on the type here means no signature owns it,
        // and no surface of the document could carry it: writing the name alone
        // would be a document that reads back meaning something else.
        case let .parameter(name, constraints):
            guard constraints.isEmpty else {
                throw WritingError(
                    "'some \(name)' is bounded by"
                        + " '\(constraints.map(\.spelling).joined(separator: " & "))', and nothing"
                        + " here declares it. A bound is written in the `bounds` of"
                        + " a procedure's signature, which this type is not part of"
                )
            }

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

        // A record, a procedure and a type handed on once are all written as a
        // mapping, and the one key is what tells them apart.
        case let .record(fields):
            return .dictionary([TypeReader.recordKey: .dictionary(try fields.mapValues(value(of:)))])

        // Written under its own key, which is where a record can carry it: the
        // type a declared type is handed on once is usually written inline,
        // and there is no front of a record to write a keyword on.
        case let .linear(inner):
            return .dictionary([TypeReader.linearKey: try value(of: inner)])

        // All four marks are written the same way, so the writing is said once
        // below. They are matched one to a case because the mark a case carries
        // is what the writing needs and a pattern cannot hand it over.
        case let .variable(inner):
            return try value(of: inner, under: .variable)

        case let .inout(inner):
            return try value(of: inner, under: .inout)

        case let .consuming(inner):
            return try value(of: inner, under: .consuming)

        case let .borrowing(inner):
            return try value(of: inner, under: .borrowing)

        case let .procedure(type, constness, isolation):
            let spelling = TypeReader.procedureSpelling(constness, isolation)

            guard let type else { return .string(spelling) }

            // No bound check of its own: a procedure type written as a type has
            // no `bounds` surface, and the `.parameter` case refuses any bound
            // the walk below meets. One guard, wherever the walk started.
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

    // The type the reading gives back for this one's spelling. Names that
    // compose are spelled in name order, and one name composing is spelled as
    // the name, which the build reads back as the composition where the name
    // is a contract's.
    private func canonical(_ type: TypeExpression) -> TypeExpression {
        switch type {
        case let .composition(names):
            guard names.count == 1 else { return .composition(names.sorted()) }

            return .named(names[0])

        case let .array(element): return .array(canonical(element))
        case let .dictionary(element): return .dictionary(canonical(element))
        case let .nullable(inner): return .nullable(canonical(inner))
        case let .variable(inner): return .variable(canonical(inner))
        case let .inout(inner): return .inout(canonical(inner))
        case let .consuming(inner): return .consuming(canonical(inner))
        case let .borrowing(inner): return .borrowing(canonical(inner))
        default: return type
        }
    }

    // A built-in holding another type, under the reading's own key for it.
    private func value(of element: TypeExpression, in holding: TypeReader.Holding) throws -> Value {
        guard case let .string(spelling) = try form(of: element) else {
            return .dictionary([Name(normal: holding.rawValue): try value(of: element)])
        }

        return .string("\(holding.rawValue)<\(spelling)>")
    }

    // A marked slot is written with the mark in front of the inner type,
    // whichever form that type takes: a bare name, or a procedure form under
    // its one key. An inline record has no front to write a mark on, and a
    // declaration's field is the one place a procedure type goes anyway.
    private func value(of inner: TypeExpression, under mark: SlotMark) throws -> Value {
        // The same thing the reading refuses, refused where the writing is: a
        // slot says one thing about what it takes. Both marks would land in one
        // key, and a key the reading cannot take apart comes back as a record
        // whose field is named after them.
        if let refusal = SlotMark.refusal(marking: inner, under: mark) {
            throw WritingError(refusal)
        }

        switch try form(of: inner) {
        case let .string(written):
            return .string(mark.marking(written))

        case let .dictionary(form) where form.count == 1
            && TypeReader.readsAsAProcedure(form.entries[0].name):
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

    // The type with every occurrence's bound removed. What a signature's slots
    // spell, the bound having moved to the signature's own `bounds`. Nested
    // signatures are walked too: their parameters are the declaring signature's
    // slots, and the one `bounds` at the declaration speaks for every
    // occurrence in them.
    private func stripped(_ type: TypeExpression) -> TypeExpression {
        switch type {
        case let .parameter(name, _):
            return .parameter(name: name)

        // Neither carries a bound to strip: a composition is its bounds, and
        // a slot spells it whole.
        case .reading, .composition:
            return type

        case let .array(element):
            return .array(stripped(element))

        case let .dictionary(entry):
            return .dictionary(stripped(entry))

        case let .record(fields):
            return .record(fields.mapValues(stripped))

        case let .procedure(type, constness, isolation):
            return .procedure(type.map(stripped), constness, isolation)

        case let .nullable(inner):
            return .nullable(stripped(inner))

        case let .variable(inner):
            return .variable(stripped(inner))

        case let .inout(inner):
            return .inout(stripped(inner))

        case let .linear(inner):
            return .linear(stripped(inner))

        case let .consuming(inner):
            return .consuming(stripped(inner))

        case let .borrowing(inner):
            return .borrowing(stripped(inner))

        case .any, .never, .null, .bool, .int, .double, .string, .ranged, .named:
            return type
        }
    }

    private func stripped(_ type: ProcedureType) -> ProcedureType {
        ProcedureType(
            parameters: type.parameters.map(stripped),
            returns: type.returns.map(stripped)
        )
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
