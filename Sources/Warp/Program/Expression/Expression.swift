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
//   struct    . Fields are expressions
//   dictionary. Entries are a key and a value, each an expression
//   call      . The procedure it names and its arguments by position
//
// The control constructs carry bodies. A name one binds inside itself is the
// statement's, under `Statement.nameInside`.
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
    case `struct`([Name: Expression])

    // A map: its entries in the order they are written, each a key and a
    // value. The entries are made in order, so a key written twice keeps the
    // later value.
    case dictionary([(key: Expression, value: Expression)])

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

    // A conditional is a statement: it answers nothing, so its arms are
    // statements alone. What an arm keeps it writes to an outer variable, and a
    // value leaves through `return`. A condition chooses a way through the body,
    // not a value.
    case conditional(Expression, then: Body, else: Body?)
    // A loop is a statement too, answering nothing. One written with no
    // condition declares that it does not finish: a round runs after every
    // round, and only a leave reaching past the loop ends it.
    case loop(while: Expression?, body: Body)

    // An attempt is a statement as well: a body, and the rescue that runs
    // where the body fails. What either keeps it writes to an outer variable.
    case attempt(Body, rescue: Body)
    case call(Call)

    // Carrying on somewhere further out than the next statement. It never
    // finishes: what comes after it in its body does not run, so a body may
    // not have anything after it.
    case leave(Leave)

    // Where a child of an expression stands, by the part it plays, as the steps
    // from the expression's own place to the child's. Every walk that names a
    // child's place takes it from here, so a place one walk writes down is the
    // place another looks up.
    public enum Child: Sendable {
        // An array's element at a position.
        case element(Int)

        // A struct's field.
        case field(Name)

        // A map literal's entry at a position, its key or its value.
        case entryKey(Int)
        case entryValue(Int)

        // The body a closure literal carries.
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

        // The statements a loop runs each round.
        case round

        // The statements an attempt runs, and the ones it runs where they fail.
        case attempted
        case rescue

        // What stands at the expression's own place: the value a leave carries.
        case held

        // MARK: - Property
        public var steps: [Place.Step] {
            switch self {
            case let .element(position): [.index(position)]
            case let .field(name): [.part(.fields), .key(name.spelling)]
            case let .entryKey(position): [.part(.entries), .index(position), .index(0)]
            case let .entryValue(position): [.part(.entries), .index(position), .index(1)]
            case .closure: [.part(.closure)]
            case let .subject(optional): [.part(.subject(optional: optional))]
            case .callee: [.part(.callee)]
            case .arguments: [.part(.arguments)]
            case let .argument(position): Self.arguments.steps + [.index(position)]
            case let .condition(holder): [.part(.condition(of: holder))]
            case .then: [.part(.then)]
            case .otherwise: [.part(.otherwise)]
            case .round: [.part(.body)]
            case .attempted: [.part(.body)]
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
        case .struct: .struct
        case .dictionary: .dictionary
        case .closure: .closure
        case .cast: .cast
        case .apply: .call
        case .conditional: .conditional
        case .loop: .loop
        case .attempt: .attempt
        case .call: .call
        case let .leave(leave): .leave(leave.reach)
        }
    }

    // The path of a plain reference, and nil for any other expression.
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

        default:
            return nil
        }
    }

    // Whether this construct answers nothing by its own grammar. A conditional
    // chooses a way through a body, a loop repeats one and an attempt runs
    // one under a rescue, not a value, so none has anything to give a slot
    // that holds an answer. What never finishes is `alwaysLeaves`'s to say,
    // refused with its own sentence.
    var answersNothing: Bool {
        switch self {
        case .conditional, .loop, .attempt:
            return true

        default:
            return false
        }
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
    // What never finishes, said once for the load, which sees a leave and a
    // loop with no condition, and the build, which sees a call answering
    // `Never`.
    static let nameOnWhatNeverFinishes = "never finishes, so it binds nothing and takes no name"
    static let afterWhatNeverFinishes = "never finishes, and what follows it here would never run"
    static let declarationOnABoundName =
        "this construct binds the name, a loop's round or"
            + " an attempt's failure, so what it holds is not declared here"

    // Whether this is a construct: a form that runs a body, or leaves.
    var isConstruct: Bool {
        switch self {
        case .conditional, .loop, .attempt, .leave:
            return true

        case .literal, .reference, .closure, .array, .struct, .dictionary, .apply, .call, .cast:
            return false
        }
    }

    // Every name this reads from around it: the head of a path in here, at
    // whatever depth, a closure's body and an index's own path included,
    // where no body in here introduced the name before reading it.
    var freeNames: Set<Name> {
        var free: Set<Name> = []

        gather(into: &free, naming: nil, outside: [])

        return free
    }

    // Whether every way through this expression leaves, read off the text
    // alone: a loop with a condition may run no round and an attempt's rescue
    // may finish normally, so neither counts, and a call is judged at the
    // build, where its signature is known.
    var alwaysLeaves: Bool {
        switch self {
        case .leave, .loop(nil, _):
            return true

        case let .conditional(_, then, otherwise):
            guard let otherwise else { return false }

            return then.alwaysLeaves && otherwise.alwaysLeaves

        default:
            return false
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
    // `name` is the statement's `nameInside`; `introduced` the names the
    // bodies around this introduced.
    private func gather(into free: inout Set<Name>, naming name: Name?, outside introduced: Set<Name>) {
        let named = introduced.union(name.map { name in [name] } ?? [])

        switch self {
        case .literal:
            break

        case let .reference(path):
            Self.gather(path, into: &free, outside: introduced)

        case let .array(elements):
            for element in elements {
                element.gather(into: &free, naming: nil, outside: introduced)
            }

        case let .struct(fields):
            for field in fields.values {
                field.gather(into: &free, naming: nil, outside: introduced)
            }

        case let .dictionary(entries):
            for entry in entries {
                entry.key.gather(into: &free, naming: nil, outside: introduced)
                entry.value.gather(into: &free, naming: nil, outside: introduced)
            }

        case let .closure(procedure):
            if let body = procedure.implementation.body {
                Self.gather(body, into: &free, outside: introduced.union(procedure.signature.names))
            }

        case let .apply(callee, arguments):
            callee.gather(into: &free, naming: nil, outside: introduced)

            for argument in arguments {
                argument.gather(into: &free, naming: nil, outside: introduced)
            }

        case let .cast(value, _, _):
            value.gather(into: &free, naming: nil, outside: introduced)

        case let .conditional(condition, then, otherwise):
            condition.gather(into: &free, naming: nil, outside: introduced)
            Self.gather(then, into: &free, outside: introduced)

            if let otherwise {
                Self.gather(otherwise, into: &free, outside: introduced)
            }

        case let .loop(condition, body):
            condition?.gather(into: &free, naming: nil, outside: named)
            Self.gather(body, into: &free, outside: named)

        case let .attempt(body, rescue):
            Self.gather(body, into: &free, outside: introduced)
            Self.gather(rescue, into: &free, outside: named)

        case let .call(call):
            for argument in call.arguments {
                argument.gather(into: &free, naming: nil, outside: introduced)
            }

        case let .leave(leave):
            leave.value?.gather(into: &free, naming: nil, outside: introduced)
        }
    }

    // A body in order: a name a statement introduces is the body's own from
    // the statement after it.
    private static func gather(_ body: Body, into free: inout Set<Name>, outside introduced: Set<Name>) {
        var introduced = introduced

        for statement in body.statements {
            if case let .assignment(path)? = statement.binding {
                gather(path, into: &free, outside: introduced)
            }

            statement.expression.gather(
                into: &free,
                naming: statement.nameInside,
                outside: introduced
            )

            if let name = statement.bindingAfter?.introduced {
                introduced.insert(name)
            }
        }
    }

    private static func gather(_ path: Path, into free: inout Set<Name>, outside introduced: Set<Name>) {
        for inner in path.expandingIndexReferences {
            if let head = inner.head, !introduced.contains(head) {
                free.insert(head)
            }
        }
    }
}
