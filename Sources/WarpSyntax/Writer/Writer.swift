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
// It exists because a program has to be able to leave the machine that built
// it. Building the language's types directly is what a front end with a syntax
// of its own does, and a caller assembling procedures in native code does the
// same, but neither can hand what it built to anything running elsewhere unless
// the result can be written down. Reading was half a door.
//
// Only the types that stand one to one with the language are written. Nothing
// here reaches for a spelling (no `is`, no template, no `abort`) because a
// spelling is a claim about what the reading side implements, and the point of
// writing plainly is to make that claim as small as it can be. A program that
// arrived spelled is written back unspelled, and it means the same thing.
public struct Writer: Sendable {
    // MARK: - Property
    public let registry: ConstructRegistry

    // Which notation the result has to survive being read by. The far side, not
    // this side. Nothing here writes a spelling, so this never spells anything;
    // it is used to *avoid* writing data that the reader over there would take
    // for one.
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
    // differ. It reads its own notation and writes for the wire.
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
        try value(of: module.draft)
    }

    // A draft and not only a module, because what a document *is* is answered by
    // writing it back out, and that answer is owed for a text whose program does
    // not hold together. Nothing here judges.
    public func value(of draft: Draft) throws -> Value {
        // Written every time, because a document that travels is the only kind
        // worth writing and neither question can be asked of it later. What it
        // costs is two keys; what it buys is that a reader too old for it, or
        // without the procedures it calls, says so instead of finding out part of the
        // way through.
        //
        // The version is this writer's and the imports are the program's: which
        // types were used is a fact about the writing, and what a program takes
        // from its link is a fact about the program. A draft that claimed
        // nothing is written with what it sends, since a document that says
        // nothing is not one and there is nobody left to ask.
        var written: [Name: Value] = [
            Envelope.versionKey: .int(Envelope.version),
            Envelope.importsKey: .array(
                (draft.imports ?? draft.sends).sorted().map { name in .string(name.spelling) }
            ),
            ModuleReader.CodingKeys.procedures.name:
                .dictionary(try draft.procedures.mapValues(value(of:)))
        ]

        if let description = draft.description {
            written[ModuleReader.CodingKeys.description.name] = .string(description)
        }

        if !draft.types.isEmpty {
            written[ModuleReader.CodingKeys.types.name] = .dictionary(try draft.types.mapValues(value(of:)))
        }

        if !draft.constraints.isEmpty {
            written[ModuleReader.CodingKeys.constraints.name] = .dictionary(
                try draft.constraints.mapValues { members in
                    .array(try members.map(value(of:)))
                }
            )
        }

        if !draft.contracts.isEmpty {
            written[ModuleReader.CodingKeys.contracts.name] = .dictionary(
                try draft.contracts.mapValues { procedures in
                    .dictionary(
                        try procedures.mapValues { procedure in
                            .dictionary(try fields(of: procedure))
                        }
                    )
                }
            )
        }

        if !draft.claims.isEmpty {
            written[ModuleReader.CodingKeys.satisfies.name] = .dictionary(
                draft.claims.mapValues { contracts in
                    .array(contracts.sorted().map { name in .string(name.spelling) })
                }
            )
        }

        if !draft.constants.isEmpty {
            written[ModuleReader.CodingKeys.const.name] = .dictionary(
                try draft.constants.mapValues { constant in try value(of: constant) }
            )
        }

        if !draft.variables.isEmpty {
            written[ModuleReader.CodingKeys.variables.name] = .dictionary(
                try draft.variables.mapValues { variable in try value(of: variable) }
            )
        }

        return .dictionary(written)
    }

    public func value(of procedure: Procedure) throws -> Value {
        // A body is what a document declares. A procedure backed by native code has
        // nothing a document could carry, and writing its name alone would make
        // a document that loads into something else.
        guard case let .body(block) = procedure.implementation else {
            throw WritingError(
                "a procedure implemented in native code has no document."
                    + " What a caller brings is declared where the run is assembled"
            )
        }

        var written: [Name: Value] = [:]

        if let description = procedure.description {
            written[ProcedureReader.CodingKeys.description.name] = .string(description)
        }

        // Stripped here, at the declaration, because this is the one place a
        // bound has a `bounds` to move to. Everything below the declaration
        // (slots, nested procedure types) writes types as they arrive and
        // refuses a bound it meets, so a bound can neither be written twice nor
        // quietly dropped.
        written.merge(try fields(of: stripped(procedure.signature))) { one, _ in one }
        written.merge(try fields(of: block, in: nil)) { one, _ in one }

        if let bounds = try bounds(of: procedure.signature) {
            written["bounds"] = bounds
        }

        return .dictionary(written)
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

        // The range rides in the name's spelling (`int(0...255)`) the way the
        // reader takes it in. A bound with no spelling has nothing to ride in:
        // the language admits an infinity, because it orders like any other
        // bound, and a document that carried the procedures a message shows it in
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

        // A declared name is written as itself, so the reading has to take that
        // spelling back as the same name. Nothing stops a module declaring a
        // type called `int`, or `var Task`, or `array<int>`; a document just
        // has no way to say which one it meant.
        case let .named(name):
            guard TypeReader.readsBackAsAName(name) else {
                throw WritingError(
                    "a type declared as '\(name)' is written the same way the reading"
                        + " takes for something else, and a document has no way to tell"
                        + " them apart"
                )
            }

            return .string(name.spelling)

        // Bare, because an occurrence names the parameter and its constraint is
        // written once, in the `bounds` of the signature that declares the
        // name. A signature entry strips the bound before writing and emits it
        // there, so a bound still on the type here means no signature owns it,
        // and no surface of the document could carry it: writing the name alone
        // would be a document that reads back meaning something else. No
        // document spells this. It is a type the link worked out from a body,
        // and the link refuses one written into a declaration. Reaching here
        // means a type got past that, so it is said rather than silently
        // written as something else.
        case let .reading(of, path):
            throw WritingError(
                "`some \(([PathSegment.key(of)] + path).rendered)` is a type"
                    + " the build read out of a body,"
                    + " and no document writes one. A declaration says what a call"
                    + " fills"
            )

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
            guard let spelling = try named(element) else {
                return .dictionary([try Name("array"): try value(of: element)])
            }

            return .string("array<\(spelling)>")

        case let .dictionary(element):
            guard let spelling = try named(element) else {
                return .dictionary([try Name("dictionary"): try value(of: element)])
            }

            return .string("dictionary<\(spelling)>")

        // Spelt with the trailing `?` the reader takes, which is why the
        // declared half has to have a name of its own. A record has no spelling
        // for a `?` to trail.
        // A mark stands in front of the whole spelling, the trailing `?`
        // included, so `var Task?` is read as a `var` of a nullable and there
        // is no spelling left for a nullable of a `var`. Refused rather than
        // written, or two types would share one spelling and only one of them
        // would come back.
        case let .nullable(inner):
            if let inside = SlotMark.marked(inner) {
                throw WritingError(
                    "`?` is written on \(inner.rendered), and a `\(inside.rawValue)`"
                        + " stands in front of the `?` rather than under it, so the two"
                        + " would share one spelling and only one would come back"
                )
            }

            return .string(
                "\(try spelt(inner, at: "before `?`. A record is declared and written by its name, like `Task?`"))?"
            )

        // A record, a procedure and a type handed on once are all written as a
        // mapping, and the key is what tells them apart. A record whose only
        // field is a key the reading takes some other way would come back as
        // that other thing, or not come back at all.
        case let .record(fields):
            guard fields.count != 1 || !TypeReader.reserves(fields.keys.first!) else {
                throw WritingError(
                    "a record whose only field is '\(fields.keys.first!)' is read as"
                        + " the form that key belongs to, and a document has no way"
                        + " to tell the two apart"
                )
            }

            return .dictionary(try fields.mapValues(value(of:)))

        // Written under its own key, which is where a record can carry it: the
        // type a declared type is handed on once is usually written inline,
        // and there is no front of a record to write a keyword on.
        case let .linear(inner):
            return .dictionary([try Name(TypeReader.linearKey): try value(of: inner)])

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

        case let .procedure(signature, constness, isolation):
            let spelling = TypeReader.procedureSpelling(constness, isolation)

            guard let signature else { return .string(spelling) }

            // No bound check of its own: a procedure type written as a type has
            // no `bounds` surface, and the `.parameter` case refuses any bound
            // the walk below meets. One guard, wherever the walk started.
            return .dictionary([try Name(spelling): .dictionary(try fields(of: signature))])
        }
    }

    public func value(of parameter: Parameter) throws -> Value {
        var written: [Name: Value] = [:]

        if let type = parameter.type {
            written["type"] = try value(of: type)
        }

        if let candidates = parameter.candidates {
            written["enum"] = .array(candidates.map(Value.string))
        }

        if let fallback = parameter.default {
            written["default"] = fallback
        }

        if let description = parameter.description {
            written["description"] = .string(description)
        }

        return .dictionary(written)
    }

    // MARK: - Private
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

        switch try value(of: inner) {
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

    // A signature is written flat into whatever declares it. A procedure and a
    // procedure type both spell it as their own keys rather than nesting it.
    func fields(of signature: Signature) throws -> [Name: Value] {
        var written: [Name: Value] = [:]

        if let receiver = signature.receiver {
            written["receiver"] = .string(receiver.spelling)
        }

        if !signature.parameters.isEmpty {
            written["parameters"] = .dictionary(try signature.parameters.mapValues(value(of:)))
        }

        if let returns = signature.returns {
            written["returns"] = try value(of: returns)
        }

        return written
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

        case let .procedure(signature, constness, isolation):
            return .procedure(signature.map(stripped), constness, isolation)

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
                    candidates: parameter.candidates,
                    default: parameter.default,
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
    private func bounds(of signature: Signature) throws -> Value? {
        let held: [Name: [Name]]

        switch signature.parameterBounds {
        case let .held(bounds):
            held = bounds

        case let .disagreeing(name, one, other):
            throw WritingError(Signature.ParameterBounds.refusal(name, one, other) + ", so there is no `bounds` to write")
        }

        let bounds = held
            .filter { _, constraints in !constraints.isEmpty }
            .mapValues { constraints in Value.string(constraints.sorted().map(\.spelling).joined(separator: " & ")) }

        return bounds.isEmpty ? nil : .dictionary(bounds)
    }

    // One fact (only a type with a spelling of its own composes) said with the
    // place the author wrote, so the refusal points at their text.
    // The name this type is written as, or nil where it is written as a
    // mapping instead.
    private func named(_ type: TypeExpression) throws -> String? {
        guard case let .string(name) = try value(of: type) else { return nil }

        return name
    }

    private func spelt(_ type: TypeExpression, at context: String) throws -> String {
        guard case let .string(name) = try value(of: type) else {
            throw WritingError("only a type with a name is written \(context)")
        }

        return name
    }
}
