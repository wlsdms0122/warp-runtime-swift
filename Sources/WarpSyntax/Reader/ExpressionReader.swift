//
//  ExpressionReader.swift
//  WarpSyntax
//
//  Created by JSilver on 8/16/26.
//

import Foundation
import Warp

// The expression grammar. `Expression` has shapes and no spelling; this is the
// spelling — no front end may hide an expression inside a string, so any
// notation that can write an object can write every expression:
//
//   scalar             — a literal, and strings are always literal text
//   { ref: a.b[0] }    — a name to resolve in the consuming scope
//   { value: <data> }  — the escape for data that looks like a form. It builds
//                        a plain literal: quotation is a fact about this
//                        notation, not about the expression it writes
//   { format:, with: } — closed interpolation: the template sees only its
//                        declared bindings, nothing from the ambient scope
//   { closure: <procedure> }
//                      — a procedure written where a value is wanted. An
//                        expression rather than a construct because that is
//                        where one is needed: a closure is written as an
//                        argument far more often than as a statement
//   { call: <message> } — a message where a value is wanted. The same form a
//                        statement writes, and here because the language puts
//                        no such limit on it: every spelling that stands in for
//                        a word builds one of these somewhere inside an
//                        expression, so a document that could only write one as
//                        a statement could not say plainly what its own
//                        spellings mean
//   record / array     — elements are expressions
//
// A string is never re-parsed into anything live — the injection surface the
// old `${}` grammar carried does not exist here.
public struct ExpressionReader: Decodable {
    // MARK: - Property
    // The object keys that make a record an expression form. A record that
    // carries one of these as plain data must be quoted — `{ value: ... }`.
    //
    // Fixed, where construct words are a `ConstructRegistry` a caller composes. The
    // asymmetry is deliberate, and this set is why: it is the quoting boundary.
    // A construct word is read in statement position, where a document is already
    // writing code; these are read wherever data appears, so widening the set
    // turns records that were data into forms. Under a movable boundary the same
    // document means different things in different notations, and the way an author
    // finds out is a payload silently becoming a reference.
    static let formKeys: Set<Name> = [
        "ref", "value", "format", "with", closureKey, "call", "as", "as?",
    ]

    // The key a closure literal is written under. Named because a place read
    // in a document's words asks for it, and a word spelled in two files is a
    // word the two can come to disagree about.
    static let closureKey: Name = "closure"

    // What a cast reads and what a message is sent to are written under one
    // key, and the two readers meet only in the text — so the word is here
    // rather than in each of them.
    static let subjectKey: Name = "of"

    public let expression: Expression

    // MARK: - Initializer
    public init(from decoder: Decoder) throws {
        self.expression = try Self.read(try ValueReader(from: decoder).value, in: decoder)
    }

    // MARK: - Public
    // MARK: - Internal
    // The decoder comes along because one form needs more than the value: a
    // closure carries statements, and which words a statement may write is the
    // registry's answer, which travels in the decoder rather than in the data.
    //
    // Not public: a form reading an expression goes through `init(from:)`, which
    // is where a refusal from this grammar is given the address of the walk
    // that asked for it. A door around that boundary is a way to refuse with no
    // address at all, and one existed for exactly as long as this was public.
    static func read(_ value: Value, in decoder: Decoder? = nil) throws -> Expression {
        try read(value, at: decoder?.steps ?? [], in: decoder)
    }

    // MARK: - Private
    // An expression is a value with a value inside it, so reading one is a walk
    // like any other and it records where it is like any other. The decoder
    // stops at the key the expression is written under and everything below
    // that is this walk's own descent, which is why the steps travel here as
    // well as in the decoder — a walk that carried only the decoder's would
    // answer for a record ten fields deep with the address of the record.
    //
    // This is also where the grammar's refusal is given an address. It is
    // written wherever an expression is spelled, so it carries none of its own,
    // and the innermost walk that was reading is the one that knows. A refusal
    // that already has an address is deeper than this one and passes.
    private static func read(
        _ value: Value,
        at steps: [Place.Step],
        in decoder: Decoder?
    ) throws -> Expression {
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

            case let .record(record):
                return try read(object: record, at: steps, in: decoder)

            // A document is text. Nothing it parses to is ever a procedure, so
            // this arm is unreachable rather than unwritten — a closure reaches
            // the language by being spelled, and spelling it is a form.
            case .procedure:
                throw ExpressionFormError("a document cannot contain a procedure value")
            }
        } catch let error as ExpressionFormError {
            throw ReadingError(error.message, at: steps)
        }
    }

    private static func read(
        object: Record,
        at steps: [Place.Step],
        in decoder: Decoder?
    ) throws -> Expression {
        let formKeys = Set(object.names).intersection(Self.formKeys)

        // No form key: an ordinary record of expressions.
        guard !formKeys.isEmpty else {
            // In the record's order, so that a record with two bad fields
            // refuses the same one every run.
            return .record(
                try object.entries.reduce(into: [Name: Expression]()) { fields, entry in
                    fields[entry.name] = try read(
                        entry.value,
                        at: steps + [.key(entry.name.spelling)],
                        in: decoder
                    )
                }
            )
        }

        if object.names.contains("ref") {
            guard object.count == 1 else {
                throw ExpressionFormError(
                    "a record with `ref` must be exactly { ref: <path> } —"
                        + " wrap it in { value: ... } if the keys are plain data"
                        + " (found keys: \(object.names))"
                )
            }

            guard case let .string(rendered)? = object["ref"] else {
                throw ExpressionFormError(
                    "{ ref: } takes a path string like a.b[0]"
                )
            }

            do {
                return .reference(try TemplateParser().parseRefPath(rendered))
            } catch {
                throw ExpressionFormError("{ ref: \(rendered) } — \(error)")
            }
        }

        if object.names.contains("as") || object.names.contains("as?") {
            guard !(object.names.contains("as") && object.names.contains("as?")) else {
                throw ExpressionFormError(
                    "a cast names one shape — `as` and `as?` are the two ways to"
                        + " read a mismatch, not two shapes to read"
                )
            }

            let optional = object.names.contains("as?")
            let key: Name = optional ? "as?" : "as"

            guard object.count == 2, let written = object[key], let read = object[Self.subjectKey] else {
                throw ExpressionFormError(
                    "a record with `\(key)` must be exactly { \(key): <type>, of: <value> }"
                        + " — wrap it in { value: ... } if the keys are plain data"
                        + " (found keys: \(object.names))"
                )
            }

            // A type has two spellings and a cast takes either: the string a
            // built-in or a declared name is written as, and the mapping a
            // record or a procedure signature is written as. Reading only the
            // first would put a shape out of a cast's reach for no reason but
            // how it is written.
            let type: TypeExpression

            do {
                if case let .string(spelling) = written {
                    type = try TypeReader.parse(spelling)
                } else {
                    guard let decoder else {
                        throw ExpressionFormError(
                            "{ \(key): } written as a mapping cannot be read here"
                                + " — this surface reads a type by its name alone"
                        )
                    }

                    type = try TypeReader(from: ValueDecoder(
                        value: written,
                        codingPath: decoder.codingPath + [AnyCodingKey(stringValue: key.spelling)],
                        steps: steps + [.key(key.spelling)],
                        userInfo: decoder.userInfo
                    ))
                    .type
                }
            } catch let error as TypeFormError {
                throw ExpressionFormError("{ \(key): } — \(error.message)")
            }

            return .cast(
                try Self.read(read, at: steps + [.key(Self.subjectKey.spelling)], in: decoder),
                as: type,
                optional: optional
            )
        }

        if object.names.contains(Self.closureKey) {
            guard object.count == 1, let written = object[Self.closureKey] else {
                throw ExpressionFormError(
                    "a record with `closure` must be exactly { closure: <procedure> }"
                        + " (found keys: \(object.names))"
                )
            }

            guard let decoder else {
                throw ExpressionFormError(
                    "{ closure: } cannot be read here — a closure carries statements,"
                        + " and this surface reads expressions alone"
                )
            }

            do {
                return .closure(
                    try ProcedureReader(from: ValueDecoder(
                        value: written,
                        codingPath: decoder.codingPath + [AnyCodingKey(stringValue: Self.closureKey.spelling)],
                        steps: steps + [.key(Self.closureKey.spelling)],
                        userInfo: decoder.userInfo
                    ))
                    .procedure
                )
            } catch let refusal as ReadingError {
                // A reading that says where it is says it deeper than here, and
                // folding it into this form's sentence would spend the address
                // to say the words again.
                throw refusal
            } catch {
                throw ExpressionFormError("{ closure: } — \(error)")
            }
        }

        if object.names.contains("call") {
            guard object.count == 1, let written = object["call"] else {
                throw ExpressionFormError(
                    "a record with `call` must be exactly { call: <message> }"
                        + " (found keys: \(object.names))"
                )
            }

            guard let decoder else {
                throw ExpressionFormError(
                    "{ call: } cannot be read here — a message may carry bodies,"
                        + " and this surface reads expressions alone"
                )
            }

            do {
                // A message written where a value is wanted has no statement to
                // take a name from, and nothing in a message wants one.
                return try CallForm(from: ValueDecoder(
                    value: written,
                    codingPath: decoder.codingPath + [AnyCodingKey(stringValue: "call")],
                    steps: steps + [.key("call")],
                    userInfo: decoder.userInfo
                ))
                .expression(boundTo: "")
            } catch let refusal as ReadingError {
                throw refusal
            } catch {
                throw ExpressionFormError("{ call: } — \(error)")
            }
        }

        if object.names.contains("value") {
            guard object.count == 1, let payload = object["value"] else {
                throw ExpressionFormError(
                    "a record with `value` must be exactly { value: <data> } —"
                        + " wrap the whole record in { value: ... } if the keys are"
                        + " plain data (found keys: \(object.names))"
                )
            }

            return .literal(payload)
        }

        // A notation may decline to offer a template, and then these keys are
        // refused rather than read as an ordinary record. Giving up a spelling
        // says a document may not write it — it does not hand the words back to
        // mean something else, which is why the set of form keys is the same in
        // every notation whether or not each one is offered.
        let notation = decoder?.userInfo[.notation] as? Notation ?? .canonical

        guard let interpolation = notation.interpolation else {
            throw ExpressionFormError(
                "this notation does not spell a template — put the text together"
                    + " by sending the words that put text together"
            )
        }

        guard object.names.contains("format") else {
            // Only `with` remains — with is format's companion, meaningless alone.
            throw ExpressionFormError(
                "`with` only accompanies `format` — wrap the record in"
                    + " { value: ... } if the keys are plain data"
                    + " (found keys: \(object.names))"
            )
        }

        guard Set(object.names).subtracting(["format", "with"]).isEmpty else {
            throw ExpressionFormError(
                "a record with `format` must be exactly { format: <template>,"
                    + " with: <bindings> } — wrap it in { value: ... } if the keys"
                    + " are plain data (found keys: \(object.names))"
            )
        }

        guard case let .string(template)? = object["format"] else {
            throw ExpressionFormError("{ format: } takes a template string")
        }

        let bindings: [Name: Expression]

        switch object["with"] {
        case nil:
            bindings = [:]

        case let .record(withRecord)?:
            bindings = try withRecord.entries.reduce(into: [Name: Expression]()) { bound, entry in
                bound[entry.name] = try read(
                    entry.value,
                    at: steps + [.key("with"), .key(entry.name.spelling)],
                    in: decoder
                )
            }

        case let other?:
            throw ExpressionFormError(
                "{ format: } `with` takes a record of bindings,"
                    + " got \(other.type)"
            )
        }

        let segments: [TemplateSegment]

        do {
            segments = try TemplateParser().parse(template)
        } catch {
            throw ExpressionFormError("{ format: } template — \(error)")
        }

        // The format surface is closed: every placeholder must name a declared
        // binding. An undeclared name is an author mistake caught at load, never
        // an ambient lookup at run time.
        try validateClosed(segments, over: Set(bindings.keys))

        return try lowered(segments, over: bindings, spending: interpolation)
    }

    // A template as the words that build it. Interpolation is a spelling rather
    // than a thing the language has: each piece becomes a literal or a value
    // asked how it reads, and the pieces are written one after another.
    //
    // Lowering here is what makes a placeholder an ordinary reference. It is
    // checked, linked and refused the way every other reference is, instead of
    // being a shape only the template walk knew how to read.
    private static func lowered(
        _ segments: [TemplateSegment],
        over bindings: [Name: Expression],
        spending interpolation: Interpolation
    ) throws -> Expression {
        let pieces: [Expression] = try segments.map { segment in
            switch segment {
            case let .text(literal):
                return .literal(.string(literal))

            case let .ref(path):
                return .dispatch(
                    Dispatch(
                        receiver: try substituted(path, over: bindings),
                        selector: interpolation.read
                    )
                )
            }
        }

        // One piece that is already text is that text. Nothing is written one
        // after another when there is nothing to write it after.
        if pieces.count == 1, case let .literal(.string(only)) = pieces[0] {
            return .literal(.string(only))
        }

        return .dispatch(Dispatch(receiver: .array(pieces), selector: interpolation.joined))
    }

    // A placeholder names a binding and then drills into it, so what it reads is
    // the binding's expression with the rest of the path walked from there. A
    // binding that is itself a reference keeps one path rather than growing a
    // dispatch around itself.
    //
    // Every name in the path is substituted, not only the head. An index
    // reference is a path of its own inside this one, and leaving it as written
    // would have it read from whatever scope the statement runs in — which is
    // the one thing a closed template must never do, and which `validateClosed`
    // has already made the author declare a binding for.
    private static func substituted(
        _ path: [PathSegment],
        over bindings: [Name: Expression]
    ) throws -> Expression {
        guard let head = path.head, let bound = bindings[head] else {
            throw ExpressionFormError(
                "{ format: } placeholder ${\(path.rendered)} names"
                    + " no binding this template was given"
            )
        }

        let rest = try Array(path.dropFirst()).map { segment in
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

        return .reference(prefix + rest)
    }

    // A segment with any path inside it closed over the same bindings. Only an
    // index reference holds one; the rest name nothing.
    private static func closing(
        _ segment: PathSegment,
        over bindings: [Name: Expression]
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

    private static func validateClosed(
        _ segments: [TemplateSegment],
        over declared: Set<Name>
    ) throws {
        for segment in segments {
            guard case let .ref(path) = segment else { continue }

            for referenced in path.expandingIndexReferences {
                guard let head = referenced.head, declared.contains(head) else {
                    throw ExpressionFormError(
                        "{ format: } placeholder ${\(referenced.rendered)} names"
                            + " '\(referenced.head?.spelling ?? referenced.rendered)', which is"
                            + " not declared in `with` — a format template sees only"
                            + " its own bindings"
                    )
                }
            }
        }
    }
}
