//
//  Writer+Expression.swift
//  WarpSyntax
//
//  Created by JSilver on 8/20/26.
//

import Foundation
import Warp

// Where the two positions a document writes an expression in stop being the
// same. A statement is a name and one construct, so every shape the language has
// can be written there; inside another expression there is no name to give, so
// only the shapes that need none can.
public extension Writer {
    // MARK: - Public
    func value(of statement: Statement) throws -> Value {
        // The reader cannot produce a named branch, so this guards the caller
        // that builds statements directly, with the validator's own words:
        // writing one silently would make a document that reads back as
        // something else.
        if statement.binding != nil, statement.expression.takesNoName {
            throw WritingError(
                "a branch answers nothing, so its name could never bind."
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

    // Where the expression is going decides what may be written bare there. The
    // form keys are read as forms wherever data appears, so every slot reserves
    // those; a condition slot also reserves whatever the notation on the far
    // side recognises a condition by, since data written plainly there would
    // come back as one.
    //
    // The second half is empty for a document, which is what makes it worth
    // naming rather than assuming: a document's condition slot is an expression
    // like any other, and `.canonical` reserves nothing there. It stops being
    // empty exactly when the reading side is a notation, and then this is the
    // only thing standing between a record and a message.
    //
    // `constructs` names the keys a record standing directly in this slot
    // would be read as a construct under, which is only ever a statement's
    // `value`: the reader takes a record there as a construct when it has
    // exactly one key and that key is a construct's, and reads nothing that
    // way deeper down. What `reserving` names is read at every depth.
    func value(
        of expression: Expression,
        reserving reserved: Set<Name> = [],
        constructs: Set<Name> = []
    ) throws -> Value {
        let reserved = reserved.union(ExpressionReader.formKeys)

        switch expression {
        // Data that happens to look like a form has to say it is data, and data
        // that could not be mistaken for one says nothing.
        case let .literal(value):
            switch try Self.spelling(of: value, reserving: reserved, constructs: constructs) {
            case .plainly: return value
            case .quoted: return .dictionary(["value": value])
            }

        case let .reference(path):
            return .dictionary(["ref": .string(path.rendered)])

        case let .array(elements):
            return .array(try elements.map { element in try value(of: element) })

        // A record of expressions is not data, so `{ value: }` cannot rescue
        // it. Quoting one would say the fields are literals rather than things
        // to evaluate. A record whose own field names are read as a form here
        // has no document, and saying so beats writing one that means something
        // else.
        case let .record(fields):
            let taken = Self.taken(Set(fields.keys), reserving: reserved, constructs: constructs)

            guard taken.isEmpty else {
                throw WritingError(
                    "a record with the field(s) \(taken.sorted()) is read as a form"
                        + " where it is written, and a record of expressions cannot be quoted"
                )
            }

            return .dictionary(try fields.mapValues { field in try value(of: field) })

        case let .closure(procedure):
            return .dictionary([ExpressionReader.closureKey: try value(of: procedure)])

        // The mark rides on the key, the way `?.` rides on a segment: one
        // spelling says the mismatch refuses and the other says it reads as
        // null, and the shape itself is written once either way.
        case let .cast(read, type, optional):
            return .dictionary([
                optional ? "as?" : "as": try value(of: type),
                ExpressionReader.subjectKey: try value(of: read),
            ])

        case let .call(call):
            return .dictionary(["call": try message(of: call)])

        // Everything left is a construct, and this notation spells constructs
        // in statement position only. Some of them need to be there (a loop, an
        // iteration, a fan-out over a collection and an attempt each bind a
        // name inside themselves and take it from the statement they are
        // written as) and the rest are there because the expression grammar is
        // a fixed set and they are not in it.
        default:
            throw WritingError(
                "\(Self.shape(of: expression)) has no spelling where a value is wanted."
                    + " This notation writes it as a statement"
            )
        }
    }

    // MARK: - Private
    // What the reading side would take for a condition rather than for data.
    // Nothing for a document, which has no notation to take it for one.
    private var conditionKeys: Set<Name> {
        readBy.condition?.keys ?? []
    }

    // A construct key and what goes under it. The key comes from the registry
    // rather than from the form, because a notation may have respelled it or
    // given it up.
    private func construct(
        of expression: Expression,
        named id: String?
    ) throws -> (Name, Value) {
        switch expression {
        case let .call(call):
            return (try spelling(CallForm.self), try message(of: call))

        case let .apply(callee, arguments):
            var written: [Name: Value] = ["procedure": try value(of: callee)]

            if !arguments.isEmpty {
                written["arguments"] = .dictionary(
                    try arguments.mapValues { argument in try value(of: argument) }
                )
            }

            return (try spelling(InvokeForm.self), .dictionary(written))

        case let .block(block):
            return (try spelling(GroupForm.self), .dictionary(try fields(of: block, in: GroupForm.self)))

        // A name on a branch was already refused where the statement's envelope
        // is written. `takesNoName`, the one predicate every door asks.
        case let .conditional(condition, then, otherwise):
            var written: [Name: Value] = [
                "when": try value(of: condition, reserving: conditionKeys),
                "then": .array(try then.map(value(of:)))
            ]

            if let otherwise {
                written["else"] = .array(try otherwise.map(value(of:)))
            }

            return (try spelling(BranchForm.self), .dictionary(written))

        case let .loop(condition, body, round):
            try named(round, matches: id, in: "loop", binding: "round")

            var written: [Name: Value] = [
                "while": try value(of: condition, reserving: conditionKeys)
            ]

            written.merge(try fields(of: body, in: LoopForm.self)) { one, _ in one }

            return (try spelling(LoopForm.self), .dictionary(written))

        case let .iteration(material, body, element):
            try named(element, matches: id, in: "each", binding: "element")

            var written: [Name: Value] = ["in": try value(of: material)]

            written.merge(
                try fields(of: Block(body: body), in: EachForm.self)
            ) { one, _ in one }

            return (try spelling(EachForm.self), .dictionary(written))

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
        // is under the word that says "this statement is just a value".
        default:
            return (StatementReader.valueKey, try value(of: expression, constructs: Set(registry.keys)))
        }
    }

    private func message(of call: Call) throws -> Value {
        var written: [Name: Value] = ["procedure": .string(call.selector.spelling)]

        if let receiver = call.receiver {
            written[ExpressionReader.subjectKey] = try value(of: receiver)
        }

        if !call.arguments.isEmpty {
            written["arguments"] = .dictionary(
                try call.arguments.mapValues { argument in try value(of: argument) }
            )
        }

        return .dictionary(written)
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

        if form?.requiresBody == true || !block.body.isEmpty {
            written["body"] = .array(try block.body.map(value(of:)))
        }

        if let result = block.result {
            written["result"] = try value(of: result)
        }

        return written
    }

    private func spelling(_ form: any ConstructForm.Type) throws -> Name {
        guard let key = registry.key(for: form) else {
            throw WritingError(
                "this notation registers no word for \(form). A shape it gave up"
                    + " the word for is one it can no longer write"
            )
        }

        return key
    }

    // A construct takes the name it binds from the statement it is written as,
    // so one built with any other name has no document. It is reachable: a
    // caller assembling the language's shapes directly is under no obligation to
    // make the two agree, and finds out here rather than at a run that reads a
    // name nothing bound.
    private func named(
        _ bound: Name,
        matches id: String?,
        in construct: String,
        binding: String
    ) throws {
        guard bound.spelling != id else { return }

        throw WritingError(
            "a \(construct) binds its \(binding) under the name of the statement it is"
                + " written as, and this one binds '\(bound)' inside '\(id ?? "a nameless statement")'"
        )
    }

    private func key(of binding: Statement.Binding) -> Name {
        switch binding {
        case .constant: "let"
        case .variable: "var"
        case .assignment: "set"
        }
    }

    // How data has to be written to come back as itself: as it stands, or
    // quoted because something in it would otherwise be read as a form.
    //
    // The third answer is a refusal rather than a case. A procedure is code
    // that has already closed over a scope, and a document holds neither.
    // Quoting one would put something in the text that reading it back could
    // not answer with, which is the same reason a natively implemented word has
    // no document.
    private enum Spelling {
        case plainly
        case quoted
    }

    // The keys under which a record with these fields would be read as
    // something other than a record: a reserved key wherever it stands, and a
    // construct's key where the record is the one field under a statement's
    // `value`. The reader's own two conditions, asked here as the writer.
    private static func taken(
        _ keys: Set<Name>,
        reserving reserved: Set<Name>,
        constructs: Set<Name>
    ) -> Set<Name> {
        var taken = keys.intersection(reserved)

        if keys.count == 1 {
            taken.formUnion(keys.intersection(constructs))
        }

        return taken
    }

    private static func spelling(
        of value: Value,
        reserving reserved: Set<Name>,
        constructs: Set<Name> = []
    ) throws -> Spelling {
        switch value {
        case .null, .bool, .int, .double, .string, .bytes:
            return .plainly

        case let .array(elements):
            return try elements.reduce(.plainly) { carried, element in
                try spelling(of: element, reserving: reserved) == .plainly ? carried : .quoted
            }

        case .record, .dictionary:
            guard let record = value.asDictionary,
                taken(Set(record.names), reserving: reserved, constructs: constructs).isEmpty
            else {
                return .quoted
            }

            return try record.values.reduce(.plainly) { carried, field in
                try spelling(of: field, reserving: reserved) == .plainly ? carried : .quoted
            }

        case .procedure:
            throw WritingError(
                "a procedure closed over a scope is not data, and a document holds data"
            )
        }
    }

    private static func shape(of expression: Expression) -> String {
        switch expression {
        case .leave: "leaving"
        case .literal: "a literal"
        case .reference: "a reference"
        case .array: "an array"
        case .record: "a record"
        case .closure: "a closure"
        case .apply: "an invocation"
        case .block: "a group"
        case .conditional: "a branch"
        case .loop: "a loop"
        case .iteration: "an iteration"
        case .attempt: "an attempt"
        case .call: "a message"
        case .cast: "a cast"
        }
    }
}
