//
//  Expression.swift
//  Warp
//
//  Created by JSilver on 8/8/26.
//

import Foundation

// Everything that computes. Control flow is here rather than beside it: a
// construct stands where a statement's value does, and the statement's name
// is how what it answers gets a name.
//
// The data types:
//
//   literal   . A `Value`, verbatim. The type system already says what data
//                is, so an expression does not restate it
//   reference . A name to resolve in the consuming scope
//   array     . Elements are expressions
//   record    . Fields are expressions
//   call      . The procedure it names and its arguments by position
//
// The control constructs carry a `Block` and, where a name has to exist inside that
// block, the name itself, so an expression means the same thing wherever it
// appears, instead of borrowing the name of whatever bound it.
//
// `call` is the one open case. A procedure, a bundled procedure and a host's own
// all lower to it, because they differ only in where the name is found, and
// finding it is the build's job, not the grammar's.
//
// There is no operator here. Equality, negation and the connectives are procedures
// like any other, so the grammar says what a program *is* and never what one
// computes. A connective declines to ask its later sides by taking procedures
// rather than values, which is a thing a declaration can say.
//
// How a document writes any of this is `WarpSyntax`.
public indirect enum Expression: Sendable {
    case literal(Value)
    case reference(Path)
    case array([Expression])
    case record([Name: Expression])

    // A procedure written where a value is wanted. Evaluating it captures the
    // scope it was written in, which is the whole of what makes it a closure.
    case closure(Procedure)

    // Calling a value rather than a name. `call` names a declaration the build
    // finds; this calls the value in hand, which the build judges by the
    // procedure type its reading carries.
    case apply(Expression, arguments: [Expression])

    // Reading a value as a type the text names. `any` declares nothing, so a
    // dot on one is refused at the build. This is the door: the author says what
    // they expect, the build judges every dot after it against that, and the run
    // asks the arriving value the one question the build could not.
    //
    // The `?` axis is `?.`'s, on a cast: a plain one refuses at the run what
    // did not arrive as the named type, and an optional one reads that
    // mismatch as null the way `?.` reads an absence, so the reading is `T?`
    // and the author says which of the two they meant.
    case cast(Expression, as: TypeExpression, optional: Bool)

    case block(Block)
    // A conditional is a statement: it answers nothing, so its arms are
    // statements alone. What an arm keeps it writes to an outer variable, and a
    // value leaves through `return`. A condition chooses a way through the body,
    // not a value.
    case conditional(Expression, then: Body, else: Body?)
    // The round is the statement's name, and a loop written nameless binds
    // none; the same for an attempt's failure.
    case loop(while: Expression, body: Block, round: Name?)
    case attempt(Block, rescue: Block, failure: Name?)
    case call(Call)

    // Carrying on somewhere further out than the next statement. The one case
    // that never even finishes: what comes after it in its body does not run,
    // so a body may not have anything after it.
    case leave(Leave)

    // Where a child of an expression stands, by the part it plays, as the steps
    // from the expression's own place to the child's. Every walk that names a
    // child's place takes it from here, so a place one walk writes down is the
    // place another looks up.
    public enum Child: Sendable {
        // An array's element at a position.
        case element(Int)

        // A record's field.
        case field(Name)

        // The block a closure literal carries.
        case closure

        // What a cast reads.
        case subject(optional: Bool)

        // The value a call of a value calls.
        case callee

        // An argument of a call or of a call of a value, at its position.
        case argument(Int)

        case condition(of: Place.ConditionHolder)
        case then
        case otherwise
        case rescue

        // What stands at the expression's own place: the block of a block, a
        // loop or an attempt, and the value a leave carries.
        case held

        // MARK: - Property
        public var steps: [Place.Step] {
            switch self {
            case let .element(position): [.index(position)]
            case let .field(name): [.part(.fields), .key(name.spelling)]
            case .closure: [.part(.closure)]
            case let .subject(optional): [.part(.subject(optional: optional))]
            case .callee: [.part(.callee)]
            case let .argument(position): [.part(.arguments), .index(position)]
            case let .condition(holder): [.part(.condition(of: holder))]
            case .then: [.part(.then)]
            case .otherwise: [.part(.otherwise)]
            case .rescue: [.part(.rescue)]
            case .held: []
            }
        }

        // MARK: - Initializer
        // MARK: - Public
        // MARK: - Private
    }

    // MARK: - Property
    // The name of the construct this is, where it stands as a statement's.
    // Everything with no construct of its own answers `value`.
    //
    // Here rather than worked out by each walk that reports a place, because
    // two walks calling one statement's construct two things is two documents
    // as far as an author following the names is concerned.
    //
    // It is what this implementation calls the type and **not** a key read
    // off any document: a host registers the forms it likes under the
    // spellings it likes, and `{ value: { call: … } }` and `{ call: … }` are
    // two texts that arrive here as one type.
    public var construct: Construct {
        switch self {
        case .literal: .literal
        case .reference: .reference
        case .array: .array
        case .record: .record
        case .closure: .closure
        case .cast: .cast
        case .apply: .call
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
    public var referencePath: Path? {
        guard case let .reference(path) = self else { return nil }

        return path
    }

    // The value of an expression that needs no scope. Nil the moment any part
    // must resolve at run time. Load-time gates (an atom validating its literal
    // operand, the builder judging a constant argument) use this to judge what
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

    // Whether this construct answers nothing by its own grammar. A conditional
    // chooses a way through a body, not a value, so it has nothing to give a
    // slot that holds an answer and nothing for a name to bind. What never
    // finishes is `alwaysLeaves`'s to say, refused with its own sentence.
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
    // predicate that decides them. The load and the build both refuse a
    // construct in an operand, with `constructInOperand`.
    public static let constructInOperand =
        "a construct runs a body, and a call's operand is data."
            + " A body a procedure is to run travels as a closure"
    public static let declarationOnABoundName =
        "this construct binds the name. A loop's round or"
            + " an attempt's failure, so what it holds is not declared here"
    public static let constructInCondition =
        "a construct runs a body, and a condition is data."
            + " What a body decides reaches a condition through a procedure"

    // Whether a construct (a type that runs a body, or leaves) sits anywhere
    // in this expression read as data. A closure is data (the body it carries
    // is its own), so the walk does not enter it.
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
                || arguments.contains { argument in argument.holdsConstruct }

        case let .call(call):
            return call.arguments.contains { argument in argument.holdsConstruct }

        // A cast runs no body (it names a type and judges what arrives against
        // it) so it holds a construct only where the value it reads does.
        case let .cast(value, _, _):
            return value.holdsConstruct

        case .block, .conditional, .loop, .attempt, .leave:
            return true
        }
    }

    // Whether every way through this expression leaves. Structural and
    // conservative: a loop may run no round and an attempt's rescue may finish
    // normally, so neither counts; a call is judged at the build, where its
    // signature is known. The build's type walk reads the same fact over the
    // full program, symbols included. This is the symbol-free half of that
    // judgment, and what it buys is the stage: a document is refused at the
    // load.
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
