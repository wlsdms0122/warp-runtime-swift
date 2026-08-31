//
//  Writer.swift
//  WarpSyntax
//
//  Created by JSilver on 8/20/26.
//

import Foundation
import Warp

// The other direction: a program written back out as data. `Loader` reads a
// document and answers with a module; this takes a module and answers with the
// document that would load into it.
//
// It exists because a program has to be able to leave the machine that built it.
// Building the language's shapes directly is what a front end with a syntax of
// its own does, and a caller assembling procedures in native code does the same
// — but neither can hand what it built to anything running elsewhere unless the
// result can be written down. Reading was half a door.
//
// Only the shapes that stand one to one with the language are written. Nothing
// here reaches for a spelling — no `is`, no template, no `abort` — because a
// spelling is a claim about what the reading side implements, and the point of
// writing plainly is to make that claim as small as it can be. A program that
// arrived spelled is written back unspelled, and it means the same thing.
public struct Writer: Sendable {
    // MARK: - Property
    public let registry: ConstructRegistry

    // Which notation the result has to survive being read by — the far side,
    // not this side. Nothing here writes a spelling, so this never spells
    // anything; it is used to *avoid* writing data that the reader over there
    // would take for one.
    //
    // The contract is that writing and reading are inverses, and a reading side
    // with spellings is a different far side from one without. A record with a
    // field called `of` is data in a document and a condition in a notation that
    // recognises one by its subject, so writing it plainly is only safe when
    // whoever reads it back agrees.
    //
    // It is deliberately not paired with a `Loader`'s notation, because they
    // answer different questions: a loader's says what the input is written in,
    // and this says who the output is for. A front end is exactly where the two
    // differ — it reads its own notation and writes for the wire.
    public let readBy: Notation

    // MARK: - Initializer
    // Canonical by default, because a document that travels is read by a
    // runtime, and a runtime has no notation.
    public init(registry: ConstructRegistry = .standard, readBy: Notation = .canonical) {
        self.registry = registry
        self.readBy = readBy
    }

    // MARK: - Public
    public func value(of module: Module) throws -> Value {
        // Written every time, because a document that travels is the only kind
        // worth writing and neither question can be asked of it later. What it
        // costs is two keys; what it buys is that a reader too old for it, or
        // without the words it calls, says so instead of finding out part of the
        // way through.
        var written: [String: Value] = [
            Envelope.versionKey: .int(Envelope.version),
            Envelope.needsKey: .array(Envelope.needs(of: module).sorted().map(Value.string)),
            "procedures": .object(try module.procedures.mapValues(value(of:)))
        ]

        if let name = module.name {
            written["name"] = .string(name)
        }

        if let description = module.description {
            written["description"] = .string(description)
        }

        if !module.types.isEmpty {
            written["types"] = .object(try module.types.mapValues(value(of:)))
        }

        if !module.constraints.isEmpty {
            written["constraints"] = .object(
                try module.constraints.mapValues { members in
                    .array(try members.map(value(of:)))
                }
            )
        }

        if !module.constants.isEmpty {
            written["const"] = .object(
                try module.constants.mapValues { constant in try value(of: constant) }
            )
        }

        return .object(written)
    }

    public func value(of procedure: Procedure) throws -> Value {
        // A body is what a document declares. A word backed by native code has
        // nothing a document could carry, and writing its name alone would make
        // a document that loads into something else.
        guard case let .body(block) = procedure.implementation else {
            throw WritingError(
                "a procedure implemented in native code has no document —"
                    + " what a caller brings is declared where the run is assembled"
            )
        }

        var written: [String: Value] = [:]

        if let description = procedure.description {
            written["description"] = .string(description)
        }

        // Stripped here, at the declaration, because this is the one place a
        // bound has a `bounds` to move to. Everything below the declaration —
        // slots, nested procedure types — writes types as they arrive and
        // refuses a bound it meets, so a bound can neither be written twice
        // nor quietly dropped.
        written.merge(try fields(of: stripped(procedure.signature))) { one, _ in one }
        written.merge(try fields(of: block, in: nil)) { one, _ in one }

        if let bounds = try bounds(of: procedure.signature) {
            written["bounds"] = bounds
        }

        return .object(written)
    }

    public func value(of type: TypeExpression) throws -> Value {
        switch type {
        case .any: return .string("any")
        case .never: return .string("never")
        case .null: return .string("null")
        case .bool: return .string("bool")
        case .int: return .string("int")
        case .double: return .string("double")
        case .string: return .string("string")
        case .bytes: return .string("bytes")
        case .number: return .string("number")

        // The range rides in the name's spelling — `int(0...255)` — the way
        // the reader takes it in. A bound with no spelling has nothing to ride
        // in: the language admits an infinity, because it orders like any
        // other bound, and a document that carried the words a message shows
        // it in would read back as an error. Said rather than written as
        // something else, the way an unwritable shape is.
        case let .ranged(refinement):
            guard refinement.spellable else {
                throw WritingError(
                    "'\(type.rendered)' is bounded by a fraction no document spells,"
                        + " and a range is written as its bounds"
                )
            }

            return .string(type.rendered)

        // A declared name is written as itself, and a document reads a name it
        // knows as the type it knows. Nothing stops a module declaring a type
        // called `int`; a document just has no way to say which one it meant.
        case let .named(name):
            guard TypeReader.builtinNames.contains(name) else { return .string(name) }

            throw WritingError(
                "a type declared as '\(name)' is written the same way the built-in one is,"
                    + " and a document has no way to tell them apart"
            )

        // Bare, because an occurrence names the parameter and its constraint
        // is written once, in the `bounds` of the signature that declares the
        // name. A signature entry strips the bound before writing and emits
        // it there — so a bound still on the type here means no signature owns
        // it, and no surface of the document could carry it: writing the name
        // alone would be a document that reads back meaning something else.
        // No document spells this — it is a shape the link worked out from a
        // body, and the link refuses one written into a declaration. Reaching
        // here means a type got past that, so it is said rather than silently
        // written as something else.
        case let .reading(of, path):
            throw WritingError(
                "`some \(([PathSegment.key(of)] + path).rendered)` is a shape"
                    + " the link read out of a body,"
                    + " and no document writes one — a declaration says what a call"
                    + " fills"
            )

        case let .variable(name, constraint):
            guard constraint == nil else {
                throw WritingError(
                    "'some \(name)' is bounded by '\(constraint ?? "")', and nothing"
                        + " here declares it — a bound is written in the `bounds` of"
                        + " a procedure's signature, which this type is not part of"
                )
            }

            return .string("some \(name)")

        case let .array(element):
            return .string("array<\(try spelt(element, at: "inside array<…>"))>")

        case let .object(element):
            return .string("object<\(try spelt(element, at: "inside object<…>"))>")

        // Spelt with the trailing `?` the reader takes, which is why the
        // declared half has to have a name of its own — a record has no
        // spelling for a `?` to trail.
        case let .nullable(inner):
            return .string(
                "\(try spelt(inner, at: "before `?` — a record is declared and written by its name, like `Task?`"))?"
            )

        // A record and a procedure are both written as a mapping, and the one
        // key that tells them apart belongs to the procedure. A record whose
        // only field is that key would come back as the other one.
        case let .record(fields):
            guard fields.count != 1 || !TypeReader.procedureKeys.contains(fields.keys.first!) else {
                throw WritingError(
                    "a record whose only field is '\(fields.keys.first!)' is written the same"
                        + " way a procedure type is, and a document has no way to tell"
                        + " them apart"
                )
            }

            return .object(try fields.mapValues(value(of:)))

        case let .procedure(signature, purity):
            let word = purity == .pure ? "pure procedure" : "procedure"

            guard let signature else { return .string(word) }

            // No bound check of its own: a procedure type written as a type
            // has no `bounds` surface, and the `.variable` case refuses any
            // bound the walk below meets — one guard, wherever the walk
            // started.
            return .object([word: .object(try fields(of: signature))])
        }
    }

    public func value(of parameter: Parameter) throws -> Value {
        var written: [String: Value] = [:]

        if let type = parameter.type {
            written["type"] = try value(of: type)
        }

        if let oneOf = parameter.oneOf {
            written["oneOf"] = .array(oneOf.map(Value.string))
        }

        if let fallback = parameter.default {
            written["default"] = fallback
        }

        if let hint = parameter.hint {
            written["hint"] = .string(hint)
        }

        // The shorthand where nothing but the type was said. Written because the
        // pair has to round-trip through the shorthand as well as around it.
        if written.count == 1, case let .string(only)? = written["type"] {
            return .string(only)
        }

        return .object(written)
    }

    // MARK: - Private
    // A signature is written flat into whatever declares it — a procedure and a
    // procedure type both spell it as their own keys rather than nesting it.
    func fields(of signature: Signature) throws -> [String: Value] {
        var written: [String: Value] = [:]

        if let receiver = signature.receiver {
            written["receiver"] = .string(receiver)
        }

        if !signature.parameters.isEmpty {
            written["parameters"] = .object(try signature.parameters.mapValues(value(of:)))
        }

        if let returns = signature.returns {
            written["returns"] = try value(of: returns)
        }

        return written
    }

    // The type with every occurrence's bound removed — what a signature's
    // slots spell, the bound having moved to the signature's own `bounds`.
    // Nested signatures are walked too: their parameters are the declaring
    // signature's slots, and the one `bounds` at the declaration speaks for
    // every occurrence in them.
    private func stripped(_ type: TypeExpression) -> TypeExpression {
        switch type {
        case let .variable(name, _):
            return .variable(name: name)

        // Carries no bound to strip.
        case .reading:
            return type

        case let .array(element):
            return .array(stripped(element))

        case let .object(entry):
            return .object(stripped(entry))

        case let .record(fields):
            return .record(fields.mapValues(stripped))

        case let .procedure(signature, purity):
            return .procedure(signature.map(stripped), purity)

        case let .nullable(inner):
            return .nullable(stripped(inner))

        case .any, .never, .null, .bool, .int, .double, .number, .string, .bytes, .ranged, .named:
            return type
        }
    }

    private func stripped(_ signature: Signature) -> Signature {
        Signature(
            receiver: signature.receiver,
            parameters: signature.parameters.mapValues { parameter in
                Parameter(
                    type: parameter.type.map(stripped),
                    oneOf: parameter.oneOf,
                    default: parameter.default,
                    hint: parameter.hint
                )
            },
            returns: signature.returns.map(stripped)
        )
    }

    // The bounds, gathered from every occurrence — the nested ones included,
    // because a nested signature's parameters are this signature's own slots —
    // and written once, at the declaring signature. A name two occurrences
    // bound differently is two claims about one thing: a signature the link
    // refuses has no document.
    private func bounds(of signature: Signature) throws -> Value? {
        var mentioned: [String: Set<String>] = [:]
        signature.parameterConstraints(into: &mentioned)

        var bounds: [String: Value] = [:]

        for (name, constraints) in mentioned.sorted(by: { $0.key < $1.key }) {
            guard constraints.count <= 1 else {
                throw WritingError(
                    "'some \(name)' is bounded by"
                        + " \(constraints.sorted().joined(separator: " and "))"
                        + " — one parameter takes one constraint, so there is no"
                        + " `bounds` to write"
                )
            }

            if let bound = constraints.first {
                bounds[name] = .string(bound)
            }
        }

        return bounds.isEmpty ? nil : .object(bounds)
    }

    // One fact — only a type with a spelling of its own composes — said with
    // the place the author wrote, so the refusal points at their text.
    private func spelt(_ type: TypeExpression, at context: String) throws -> String {
        guard case let .string(name) = try value(of: type) else {
            throw WritingError("only a type with a name is written \(context)")
        }

        return name
    }
}
