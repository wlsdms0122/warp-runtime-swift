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
// The data constructs:
//
//   literal   . A `Value`, verbatim. The type system already says what data
//                is, so an expression does not restate it
//   reference . A name to resolve in the scope that reads it
//   array     . Elements are expressions
//   record    . Fields are expressions
//   call      . The procedure it names and its arguments by position
//
// The control constructs carry a `Block` and, where a name has to exist inside that
// block, the name itself, so an expression means the same thing wherever it
// appears, rather than taking the name of whatever bound it.
//
// `call` is the one open case. A procedure, a bundled procedure and a host's own
// all lower to it, because they differ only in where the name is found, and
// finding it is the build's job, not the grammar's. Equality, negation and the
// connectives are procedures like any other.
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

    // Reading a value as a type the text names. `Any` declares nothing, so a
    // dot on one is refused at the build. A cast is where a value the build
    // could not type is held to one: the author says what they expect, the
    // build judges every dot after it against that, and the run asks the
    // arriving value the one question the build could not.
    //
    // The `?` axis is `?.`'s, on a cast: a plain one fails with
    // `cast_refused` where the value did not arrive as the named type, and an
    // optional one reads that mismatch as null the way `?.` reads an absence,
    // so the reading is `T?` and the author says which of the two they meant.
    case cast(Expression, as: TypeExpression, optional: Bool)

    case block(Block)
    // A conditional is a statement: it answers nothing, so its arms are
    // statements alone. What an arm keeps it writes to an outer variable, and a
    // value leaves through `return`. A condition chooses a way through the body,
    // not a value.
    case conditional(Expression, then: Body, else: Body?)
    // The round is the name the statement this is the value of introduces,
    // and a loop under no such name binds none; the same for an attempt's
    // failure.
    case loop(while: Expression, body: Block)
    case attempt(Block, rescue: Block)
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

        // What a call or a call of a value is written with, as a whole.
        case arguments

        // One argument of a call or of a call of a value, at its position.
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
            case .arguments: [.part(.arguments)]
            case let .argument(position): Self.arguments.steps + [.index(position)]
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
    // It is what this implementation calls the construct and **not** a key
    // read off any document: a host registers the forms it likes under the
    // spellings it likes, and `{ value: { call: … } }` and `{ call: … }` are
    // two texts that arrive here as one construct.
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

    // The path of a plain reference.
    public var referencePath: Path? {
        guard case let .reference(path) = self else { return nil }

        return path
    }

    // The value of an expression that needs no scope. Nil the moment any part
    // must resolve at run time.
    var constantValue: Value? {
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
    var answersNothing: Bool {
        if case .conditional = self { return true }

        return false
    }

    // Whether the construct decides what the statement's name holds: a loop's
    // round, an attempt's failure. The name is the construct's to bind, so what
    // it holds is not the author's to declare.
    var namesItsOwn: Bool {
        switch self {
        case .loop, .attempt:
            return true

        default:
            return false
        }
    }

    // Sentences the load refuses with, stated beside the predicates that
    // decide them.
    static let constructWhereAValueIsWanted =
        "a construct runs a body, and is written only as a statement's value."
            + " A statement before this one runs the body and its name is read here,"
            + " or a closure carries the body"
    static let valueCallInOperand =
        "calls a value, and which procedure that is, is the run's"
            + " answer, so an operand cannot be read without running"
            + " it. A statement calls it and the operand reads its name"
    // What never finishes, said once for the load, which sees a leave, and
    // the build, which sees a call answering `Never`.
    static let nameOnWhatNeverFinishes = "never finishes, so it binds nothing and takes no name"
    static let afterWhatNeverFinishes = "never finishes, and what follows it here would never run"
    static let resultAfterWhatNeverFinishes = "follows a body that never finishes, and would never be reached"
    static let declarationOnABoundName =
        "this construct binds the name, a loop's round or"
            + " an attempt's failure, so what it holds is not declared here"

    // Whether a construct (a form that runs a body, or leaves) sits anywhere
    // in this expression read as data. A closure is data (the body it carries
    // is its own), so the walk does not enter it.
    var holdsConstruct: Bool {
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

    // Whether a value call sits anywhere in this expression read as data. A
    // closure is data, so the walk does not enter it, and a construct is
    // `holdsConstruct`'s to say.
    var callsValue: Bool {
        switch self {
        case .literal, .reference, .closure, .block, .conditional, .loop, .attempt, .leave:
            return false

        case let .array(array):
            return array.contains { element in element.callsValue }

        case let .record(record):
            return record.values.contains { field in field.callsValue }

        case .apply:
            return true

        case let .call(call):
            return call.arguments.contains { argument in argument.callsValue }

        case let .cast(value, _, _):
            return value.callsValue
        }
    }

    // Every name a path in here is headed by, at whatever depth, a closure's
    // body and an index's own path included.
    //
    // Flat, because a body may not introduce a name the module bound, so a
    // head spelled as a module's constant is that constant wherever it
    // stands.
    var pathHeads: Set<Name> {
        subexpressions.reduce(into: Set<Name>()) { names, held in
            guard case let .reference(path) = held else { return }

            names.formUnion(path.expandingIndexReferences.compactMap(\.head))
        }
    }

    // Whether every way through this expression leaves. Structural and
    // conservative: a loop may run no round and an attempt's rescue may finish
    // normally, so neither counts; a call is judged at the build, where its
    // signature is known. This is the half of that fact the load reads.
    var alwaysLeaves: Bool {
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
