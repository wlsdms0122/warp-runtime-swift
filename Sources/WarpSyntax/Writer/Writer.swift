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

    // Which notation the result is read by: the far side, not this side. It
    // decides whether a parameter is written as one pair, which only a
    // notation that reads pairs takes back. A loader's notation says what an
    // input is written in, and this says who the output is for; a front end is
    // where the two differ.
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
                (draft.imports ?? draft.uses).sorted().map { name in .string(name.spelling) }
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
                        try procedures.mapValues { asked in
                            var written = try fields(of: asked.signature)

                            if asked.constness == .const { written["const"] = .bool(true) }
                            if asked.isolation == .isolated { written["isolated"] = .bool(true) }

                            return .dictionary(written)
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
                try draft.variables.mapValues { variable -> Value in
                    guard let declared = variable.declared else { return try value(of: variable.start) }

                    return .dictionary([
                        VariableReader.typeKey: try value(of: declared),
                        VariableReader.valueKey: try value(of: variable.start)
                    ])
                }
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

        // Written where it says something a reader would not fill in.
        if procedure.access != .internal {
            written[ProcedureReader.CodingKeys.access.name] = .string(procedure.access.rawValue)
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
                "`some \(Path([.key(of)] + path.segments).rendered)` is a type"
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
                written["parameters"] = .array(try type.parameters.map(value(of:)))
            }

            if let returns = type.returns {
                written["returns"] = try value(of: returns)
            }

            return .dictionary([try Name(spelling): .dictionary(written)])
        }
    }

    public func value(of parameter: Parameter) throws -> Value {
        var written: [Name: Value] = ["name": .string(parameter.name.spelling)]

        if let type = parameter.type {
            written["type"] = try value(of: type)
        }

        if let candidates = parameter.candidates {
            written["enum"] = .array(candidates.map(Value.string))
        }

        if let description = parameter.description {
            written["description"] = .string(description)
        }

        // A record holding nothing but the name is one pair, which a notation
        // offering the pair form reads as a name and its type. There it is
        // written as the pair holding nothing.
        guard written.count > 1 || !readBy.pairedParameter else {
            return .dictionary([parameter.name: .dictionary([:])])
        }

        return .dictionary(written)
    }

    // Where the two positions a document writes an expression in stop being the
    // same. A statement is a name and one construct, so every construct the language has
    // can be written there; inside another expression there is no name to give, so
    // only the types that need none can.
    public func value(of statement: Statement) throws -> Value {
        // The reader cannot produce a named conditional, so this guards the caller
        // that builds statements directly, with the validator's own terms:
        // writing one silently would make a document that reads back as
        // something else.
        if statement.binding != nil, statement.expression.answersNothing {
            throw WritingError(
                "a conditional answers nothing, so its name could never bind."
                    + " It takes no name"
            )
        }

        if statement.binding?.declared != nil, statement.expression.namesItsOwn {
            throw WritingError(Expression.declarationOnABoundName)
        }

        var written: [Name: Value] = [:]

        if let binding = statement.binding {
            written[key(of: binding)] = .string(binding.spelled)

            if let declared = binding.declared {
                written[StatementReader.typeKey] = try value(of: declared)
            }
        }

        // A variable holding null is what a bare `var` introduces, and the bare
        // spelling is the one canonical writing of that fact.
        if
            case .variable? = statement.binding,
            case .literal(.null) = statement.expression
        {
            return .dictionary(written)
        }

        let (key, body) = try construct(of: statement.expression, named: statement.binding?.spelled)

        written[StatementReader.valueKey] = key == StatementReader.valueKey ? body : .dictionary([key: body])

        return .dictionary(written)
    }

    // An expression as a document writes it: a scalar as itself, an array as
    // the array of what it holds, and anything else under the one key its
    // form is read by.
    public func value(of expression: Expression) throws -> Value {
        switch expression {
        case let .literal(value):
            return try literal(value)

        case let .reference(path):
            return .dictionary([ExpressionTag.reference.key: .string(path.rendered)])

        case let .array(elements):
            return .array(try elements.map { element in try value(of: element) })

        case let .record(fields):
            return .dictionary([ExpressionTag.record.key: .dictionary(Value.Dictionary(try fields.mapValues { field in try value(of: field) }))])

        case let .closure(procedure):
            return .dictionary([ExpressionTag.closure.key: try value(of: procedure)])

        // The mark rides on the key, the way `?.` rides on a segment: one
        // spelling says the mismatch refuses and the other says it reads as
        // null, and the type itself is written once either way.
        case let .cast(read, type, optional):
            return .dictionary([
                (optional ? ExpressionTag.optionalCast : ExpressionTag.cast).key: .dictionary([
                    ExpressionReader.subjectKey: try value(of: read),
                    ExpressionReader.typeKey: try value(of: type)
                ])
            ])

        case let .call(call):
            return .dictionary([ExpressionTag.call.key: try self.call(of: call)])

        case let .apply(callee, arguments):
            return .dictionary([ExpressionTag.call.key: try self.call(of: callee, handing: arguments)])

        // Everything left is a construct, and this notation spells constructs
        // in statement position only. Some of them need to be there (a loop and
        // an attempt each bind a name inside themselves and take it from the
        // statement they are written as) and the rest are there because the
        // expression grammar is a fixed set and they are not in it.
        default:
            throw WritingError(
                "\(Self.construct(of: expression)) has no spelling where a value is wanted."
                    + " This notation writes it as a statement"
            )
        }
    }

    // The keys a block writes, with whoever reads it asked whether an empty
    // `body` is written or dropped. Asked rather than remembered: a writer
    // carrying its own list of which forms demand the key is a list that goes
    // stale the moment a form is added, and what it writes then is a document
    // its own reader refuses.
    //
    // Every caller names its reader, and `nil` is a reader rather than a
    // default. A rescue and a procedure are read by their own readers, which
    // take `body` as a key that may be absent. Said out loud because a way of
    // writing a block without saying who reads it is a way of skipping the
    // question, and skipping it is the failure this asks about.
    internal func fields(
        of block: Block,
        in form: (any ConstructForm.Type)?
    ) throws -> [Name: Value] {
        var written: [Name: Value] = [:]

        if form?.requiresBody == true || !block.body.statements.isEmpty {
            written["body"] = .array(try block.body.statements.map(value(of:)))
        }

        if let result = block.result {
            written["result"] = try value(of: result)
        }

        return written
    }

    // A signature is written flat into whatever declares it. A procedure and a
    // procedure type both spell it as their own keys rather than nesting it.
    func fields(of signature: Signature) throws -> [Name: Value] {
        var written: [Name: Value] = [:]

        if !signature.parameters.isEmpty {
            written["parameters"] = .array(try signature.parameters.map(value(of:)))
        }

        if let returns = signature.returns {
            written["returns"] = try value(of: returns)
        }

        return written
    }

    // MARK: - Private
    // A construct key and what goes under it. The key comes from the registry
    // rather than from the form, because a notation may have respelled it or
    // given it up.
    private func construct(
        of expression: Expression,
        named id: String?
    ) throws -> (Name, Value) {
        switch expression {
        // A call is a tag, read where a statement's value is the way it is
        // everywhere else, so no table respells it.
        case let .call(call):
            return (ExpressionTag.call.key, try self.call(of: call))

        case let .apply(callee, arguments):
            return (ExpressionTag.call.key, try self.call(of: callee, handing: arguments))

        case let .block(block):
            return (try spelling(BlockForm.self), .dictionary(try fields(of: block, in: BlockForm.self)))

        // A name on a conditional was already refused where the statement's envelope
        // is written. `answersNothing`, the one predicate every door asks.
        case let .conditional(condition, then, otherwise):
            var written: [Name: Value] = [
                "when": try value(of: condition),
                "then": .array(try then.statements.map(value(of:)))
            ]

            // An empty `else` runs what no `else` runs, so it is written the
            // one way: not at all.
            if let otherwise, !otherwise.statements.isEmpty {
                written["else"] = .array(try otherwise.statements.map(value(of:)))
            }

            return (try spelling(ConditionalForm.self), .dictionary(written))

        case let .loop(condition, body, round):
            try named(round, matches: id, in: "loop", binding: "round")

            var written: [Name: Value] = [
                "while": try value(of: condition)
            ]

            written.merge(try fields(of: body, in: LoopForm.self)) { one, _ in one }

            return (try spelling(LoopForm.self), .dictionary(written))

        case let .leave(leave):
            switch leave.reach {
            case .procedure:
                var carried = Value.null

                if let written = leave.value {
                    carried = try value(of: written)
                }

                return (try spelling(ReturnForm.self), carried)

            case .construct:
                return (try spelling(BreakForm.self), leave.target.map { name in Value.string(name.spelling) } ?? .null)

            case .round:
                return (try spelling(ContinueForm.self), leave.target.map { name in Value.string(name.spelling) } ?? .null)
            }

        case let .attempt(attempted, rescue, failure):
            try named(failure, matches: id, in: "attempt", binding: "failure")

            var written = try fields(of: attempted, in: AttemptForm.self)

            written["rescue"] = .dictionary(try fields(of: rescue, in: nil))

            return (try spelling(AttemptForm.self), .dictionary(written))

        // Whatever is left needs no name, so it is written as the expression it
        // is under the key that says "this statement is just a value".
        default:
            return (StatementReader.valueKey, try value(of: expression))
        }
    }

    // A call of a value, under the same key a call of a declaration is. A
    // string under `procedure` reads back as a name, so a value that is
    // literal text has no spelling there.
    private func call(of callee: Expression, handing arguments: [Expression]) throws -> Value {
        if case .literal(.string) = callee {
            throw WritingError("a call of literal text has no spelling: text under `procedure` names a declaration")
        }

        var written: [Name: Value] = ["procedure": try value(of: callee)]

        if !arguments.isEmpty {
            written["arguments"] = .array(try arguments.map { argument in try value(of: argument) })
        }

        return .dictionary(written)
    }

    private func call(of call: Call) throws -> Value {
        var written: [Name: Value] = ["procedure": .string(call.selector.spelling)]

        if !call.arguments.isEmpty {
            written["arguments"] = .array(try call.arguments.map { argument in try value(of: argument) })
        }

        return .dictionary(written)
    }

    private func spelling(_ form: any ConstructForm.Type) throws -> Name {
        guard let key = registry.key(for: form) else {
            throw WritingError(
                "this notation registers no key for \(form). A construct it gave"
                    + " the key up for is one it can no longer write"
            )
        }

        return key
    }

    // A construct takes the name it binds from the statement it is written as,
    // so one built with any other name has no document. It is reachable: a
    // caller assembling the language's types directly is under no obligation to
    // make the two agree, and finds out here rather than at a run that reads a
    // name nothing bound.
    private func named(
        _ bound: Name?,
        matches id: String?,
        in construct: String,
        binding: String
    ) throws {
        guard bound?.spelling != id else { return }

        throw WritingError(
            "a \(construct) binds its \(binding) under the name of the statement it is"
                + " written as, and this one binds '\(bound?.spelling ?? "nothing")'"
                + " inside '\(id ?? "a nameless statement")'"
        )
    }

    private func key(of binding: Statement.Binding) -> Name {
        switch binding {
        case .constant: "let"
        case .variable: "var"
        case .assignment: "set"
        }
    }

    // Data as a document writes it: a record under `record` like every
    // record, whatever its fields are called.
    private func literal(_ value: Value) throws -> Value {
        switch value {
        case .null, .bool, .int, .double, .string, .bytes:
            return value

        // A named record is data wherever it stands, and is read as such.
        case let .record(record) where record.name != nil:
            return value

        case let .array(elements):
            return .array(try elements.map(literal))

        // A dictionary and a record read back apart only by the type they
        // stand in, and `record` reads back as a record. A dictionary is
        // written as a record cast to the dictionary it is, which names what
        // it holds, and only its author can say that.
        case .dictionary:
            throw WritingError(
                "a dictionary has no document of its own. Write a record and cast it"
                    + " to the `dictionary<T>` it is"
            )

        case .record:
            let fields = try (value.asDictionary?.entries ?? []).map { entry in
                (name: entry.name, value: try literal(entry.value))
            }

            return .dictionary([ExpressionTag.record.key: .dictionary(try Value.Dictionary(fields))])

        case .procedure:
            throw WritingError(
                "a procedure closed over a scope is not data, and a document holds data"
            )
        }
    }

    private static func construct(of expression: Expression) -> String {
        switch expression {
        case .leave: "leaving"
        case .literal: "a literal"
        case .reference: "a reference"
        case .array: "an array"
        case .record: "a record"
        case .closure: "a closure"
        case .apply: "a call of a value"
        case .block: "a block"
        case .conditional: "a conditional"
        case .loop: "a loop"
        case .attempt: "an attempt"
        case .call: "a call"
        case .cast: "a cast"
        }
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

    private func stripped(_ signature: Signature) -> Signature {
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

    private func stripped(_ type: ProcedureType) -> ProcedureType {
        ProcedureType(
            parameters: type.parameters.map(stripped),
            returns: type.returns.map(stripped)
        )
    }

    // The bounds, gathered from every occurrence (the nested ones included,
    // because a nested signature's parameters are this signature's own slots)
    // and written once, at the declaring signature. A name two occurrences
    // bound differently is two claims about one thing: a signature the link
    // refuses has no document.
    private func bounds(of signature: Signature) throws -> Value? {
        let held = signature.parameterBounds

        if let refusal = held.refusal {
            throw WritingError(refusal + ", so there is no `bounds` to write")
        }

        let bounds = held.table
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
