//
//  Expression.swift
//  Warp
//
//  Created by JSilver on 8/8/26.
//

import Foundation

// Everything that computes. Control flow is here rather than beside it: a
// construct that runs a body still answers with a value, and `id: <construct>`
// is how that value gets a name.
//
// The data shapes:
//
//   literal   . A `Value`, verbatim. The type system already says what data
//                is, so an expression does not restate it
//   reference . A name to resolve in the consuming scope. A name the scope
//                does not hold reads as null
//   array     . Elements are expressions
//   record    . Fields are expressions
//   call      . A message: a selector, a receiver, arguments. The one
//                calling shape, and the only open one
//
// The control shapes carry a `Block` and, where a name has to exist inside that
// block, the name itself, so an expression means the same thing wherever it
// appears, instead of borrowing the id of whatever bound it.
//
// `call` is the one open case. A procedure, a bundled word and a caller's own
// all lower to it, because they differ only in where the selector is found, and
// finding it is the link's job, not the grammar's.
//
// There is no operator here. Equality, negation and the connectives are words
// like any other, so the grammar says what a program *is* and never what one
// computes. A connective declines to ask its later sides by taking procedures
// rather than values, which is a thing a declaration can say.
//
// How a document writes any of this is `WarpSyntax`.
public indirect enum Expression: Sendable {
    case literal(Value)
    case reference([PathSegment])
    case array([Expression])
    case record([Name: Expression])

    // A procedure written where a value is wanted. Evaluating it captures the
    // scope it was written in, which is the whole of what makes it a closure.
    case closure(Procedure)

    // Calling a value rather than a name. `call` asks a table and a call graph
    // what a selector means, and the linker settles that before any run; this
    // asks the value in hand, and only a run can. Two spellings because they are
    // two questions: fusing them would mean a local name could quietly stand in
    // for a linked one, and linking would stop being a promise.
    case apply(Expression, arguments: [Name: Expression])

    // Reading a value as a shape the text names. `any` declares nothing, so a
    // dot on one is refused at the link. This is the door: the author says what
    // they expect, the link judges every dot after it against that, and the run
    // asks the arriving value the one question the link could not.
    //
    // The `?` axis is `?.`'s, on a cast: a plain one refuses at the run what
    // did not arrive as the named shape, and an optional one reads that
    // mismatch as null the way `?.` reads an absence, so the reading is `T?`
    // and the author says which of the two they meant.
    case cast(Expression, as: TypeExpression, optional: Bool)

    case block(Block)
    // A branch is a statement: it answers nothing, so its arms are statements
    // alone, the way a walk's body is. What an arm keeps it writes to an outer
    // variable, and a value leaves through `return`. A condition chooses a way
    // through the body, not a value.
    case conditional(Expression, then: [Statement], else: [Statement]?)
    // Repetition carries no budget of its own. Bounding a loop is the author's
    // to write (a counter and `std.control.abort` say it exactly) and stopping
    // one is the receiver's cancellation; a kernel budget would promise neither
    // side anything it can rely on.
    case loop(while: Expression, body: Block, round: Name)
    case attempt(Block, rescue: Block, failure: Name)
    case call(Call)

    // Carrying on somewhere further out than the next statement. The one shape
    // that never even finishes: what comes after it in its body does not run,
    // so a body may not have anything after it.
    case leave(Leave)

    // MARK: - Property
    // The word for the construct this is, where it stands as a statement's.
    // Everything with no construct of its own answers `value`.
    //
    // Here rather than worked out by each walk that reports a place, because
    // two walks calling one statement's construct two things is two documents
    // as far as an author following the words is concerned.
    //
    // It is what this implementation calls the shape and **not** a word read
    // off any document: a caller registers the forms it likes under the
    // spellings it likes, and `{ value: { call: … } }` and `{ call: … }` are
    // two texts that arrive here as one shape.
    public var construct: Construct {
        switch self {
        case .literal: .literal
        case .reference: .reference
        case .array: .array
        case .record: .record
        case .closure: .closure
        case .cast: .cast
        case .apply: .apply
        case .block: .block
        case .conditional: .conditional
        case .loop: .loop
        case .attempt: .attempt
        case .call: .call
        case let .leave(leave): .leave(leave.reach)
        }
    }

    // The path of a plain reference. An effect that requires one names it
    // through this.
    public var referencePath: [PathSegment]? {
        guard case let .reference(path) = self else { return nil }

        return path
    }

    // The value of an expression that needs no scope. Nil the moment any part
    // must resolve at run time. Load-time gates (an atom validating its literal
    // operand, the linker judging a constant argument) use this to judge what
    // can be judged before any run.
    public var constantValue: Value? {
        switch self {
        case let .literal(value):
            return value

        case let .array(array):
            let values = array.compactMap(\.constantValue)

            return values.count == array.count ? .array(values) : nil

        case let .record(record):
            let values = record.compactMapValues(\.constantValue)

            return values.count == record.count ? .record(Record(name: nil, values)) : nil

        default:
            return nil
        }
    }

    // Whether this construct answers nothing by its own grammar. A branch
    // chooses a way through a body, not a value, so it has nothing to give a
    // slot that holds an answer and nothing for a name to bind. The reader, the
    // validator and the writer each ask this; the other nameless family (what
    // never finishes) is `alwaysLeaves`'s to say, and stays its own question
    // because the two facts are refused with two different sentences.
    public var answersNothing: Bool {
        if case .conditional = self { return true }

        return false
    }

    // Whether the construct decides what the statement's name holds: a loop's
    // round, an attempt's failure. The name is the construct's to bind, so what
    // it holds is not the author's to declare.
    public var namesItsOwn: Bool {
        switch self {
        case .loop, .attempt:
            return true

        default:
            return false
        }
    }

    // The sentences the construct rule refuses with, stated once beside the
    // predicate that decides them. The check wraps them as validation refusals
    // and the link as link refusals, so the two stages cannot say different
    // things.
    public static let constructInOperand =
        "a construct runs a body, and a call's operand is data."
            + " A body a word is to run travels as a closure"
    public static let declarationOnABoundName =
        "this construct binds the name. A loop's round, a walk's element,"
            + " an attempt's failure, so what it holds is not declared here"
    public static let constructInCondition =
        "a construct runs a body, and a condition is data."
            + " What a body decides reaches a condition through a word"

    // Whether a construct (a shape that runs a body, or leaves) sits anywhere
    // in this expression read as data. A call's operand is data the pure half
    // reads, so the check and the link both refuse one by asking this; a
    // closure is data (the body it carries is its own), so the walk does not
    // enter it.
    public var holdsConstruct: Bool {
        switch self {
        case .literal, .reference, .closure:
            return false

        case let .array(array):
            return array.contains { element in element.holdsConstruct }

        case let .record(record):
            return record.values.contains { field in field.holdsConstruct }

        case let .apply(callee, arguments):
            return callee.holdsConstruct
                || arguments.values.contains { argument in argument.holdsConstruct }

        case let .call(call):
            return call.receiver?.holdsConstruct ?? false
                || call.arguments.values.contains { argument in argument.holdsConstruct }

        // A cast runs no body (it names a shape and judges what arrives against
        // it) so it holds a construct only where the value it reads does.
        case let .cast(value, _, _):
            return value.holdsConstruct

        case .block, .conditional, .loop, .attempt, .leave:
            return true
        }
    }

    // Whether every way through this expression leaves. Structural and
    // conservative: a loop may run no round and an attempt's rescue may finish
    // normally, so neither counts; a call is judged at the link, where its
    // signature is known. The link's type walk reads the same fact over the
    // full program, symbols included. This is the symbol-free half of that
    // judgment, and what it buys is the stage: a document is refused before
    // anything is linked.
    public var alwaysLeaves: Bool {
        switch self {
        case .leave:
            return true

        case let .conditional(_, then, otherwise):
            guard let otherwise else { return false }

            return then.alwaysLeaves && otherwise.alwaysLeaves

        case let .block(block):
            return block.alwaysLeaves

        default:
            return false
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
