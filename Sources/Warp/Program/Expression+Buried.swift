//
//  Expression+Buried.swift
//  Warp
//
//  Created by JSilver
//

import Foundation

// One walk over everything an expression holds, for every stage that has to
// see all of it.
//
// Three of them ask for exactly this and differ only in what they keep: the
// declaration scan wants the closure literals a body buries, the same scan
// wants the shapes its casts name, and an envelope wants the selectors a
// module sends. Written out per collector, one shape of the language is
// written three times — and a case added to `Expression` reaches whichever
// copies somebody remembered.
//
// Where a thing was found is the caller's to name. A stage that reports has a
// place to extend, and a stage that only gathers has nothing to carry — so
// where a thing is travels as a value the caller hands in, along with how to
// step into one, and the caller wanting nowhere hands in nothing.
//
// A step is a `Place.Step` rather than a word, because a statement is found by
// its name and by its position and only one of those is always there. Handing
// the step over whole is what lets a caller keep both; a word would have made
// this walk choose between them on every stage's behalf.

// What can be walked for everything it holds. Three types answer it, and the
// two convenient ways to ask are written once here rather than three times
// over — the same duplication this file exists to remove, at the smaller
// scale where it is easy not to notice.
public protocol Burying {
    // Everything held in here, each with where it was found.
    func buried<Trail>(at trail: Trail, stepping: (Trail, Place.Step) -> Trail) -> [(Trail, Expression)]
}

public extension Burying {
    // The walk a stage that reports takes.
    func buried(at place: Place) -> [(Place, Expression)] {
        buried(at: place) { place, step in place.appending(step) }
    }

    // The walk a stage that only gathers takes. Nothing is carried, so nothing
    // is spelled.
    var buried: [Expression] {
        buried(at: ()) { _, _ in () }.map(\.1)
    }
}

extension Expression: Burying {}
extension Block: Burying {}
extension [Statement]: Burying {}

public extension Expression {
    func buried<Trail>(
        at trail: Trail,
        stepping: (Trail, Place.Step) -> Trail
    ) -> [(Trail, Expression)] {
        // A closure names its own place: the literal and the body it carries
        // are found under one name, so a report says which closure without
        // having to say it twice.
        let here: Trail = if case .closure = self { stepping(trail, .key("closure")) } else { trail }

        func inner(_ expression: Expression, under key: String? = nil) -> [(Trail, Expression)] {
            expression.buried(
                at: key.map { key in stepping(here, .key(key)) } ?? here,
                stepping: stepping
            )
        }

        // What a call is written with, walked in name order and each given its
        // own place. Order because a `Dictionary` walks in whatever order its
        // seed decided, and the stages downstream stop at the first refusal —
        // which one an author is shown would be a fact of the run rather than
        // of the text. Its own place because two of them reported from the
        // same one would say a thing is wrong and not say which.
        func arguments(_ children: [String: Expression]) -> [(Trail, Expression)] {
            named(children, under: stepping(here, .key("arguments")))
        }

        func named(_ children: [String: Expression], under place: Trail) -> [(Trail, Expression)] {
            children.sorted { mine, theirs in mine.key < theirs.key }
                .flatMap { name, child in
                    child.buried(at: stepping(place, .key(name)), stepping: stepping)
                }
        }

        let held: [(Trail, Expression)] = switch self {
        case .literal, .reference:
            []

        case let .closure(procedure):
            procedure.block?.buried(at: here, stepping: stepping) ?? []

        case let .cast(value, _, _):
            inner(value, under: "of")

        // A leave writes what it carries directly under its own construct key,
        // which the statement holding it already stepped into.
        case let .leave(leave):
            leave.value.map { value in inner(value) } ?? []

        case let .array(array):
            array.enumerated().flatMap { position, element in
                element.buried(at: stepping(here, .index(position)), stepping: stepping)
            }

        case let .record(record):
            named(record, under: here)

        case let .invoke(callee, written):
            inner(callee, under: "procedure") + arguments(written)

        case let .dispatch(dispatch):
            (dispatch.receiver.map { receiver in inner(receiver, under: "of") } ?? [])
                + arguments(dispatch.arguments)

        case let .block(block):
            block.buried(at: here, stepping: stepping)

        case let .conditional(condition, then, otherwise):
            inner(condition, under: "when")
                + then.buried(at: stepping(here, .key("then")), stepping: stepping)
                + (otherwise?.buried(at: stepping(here, .key("else")), stepping: stepping) ?? [])

        case let .loop(condition, body, _):
            inner(condition, under: "where") + body.buried(at: here, stepping: stepping)

        case let .iteration(material, body, _):
            inner(material, under: "in")
                + body.buried(at: stepping(here, .key("body")), stepping: stepping)

        case let .attempt(block, rescue, _):
            block.buried(at: here, stepping: stepping)
                + rescue.buried(at: stepping(here, .key("rescue")), stepping: stepping)
        }

        return [(here, self)] + held
    }
}

public extension Block {
    func buried<Trail>(
        at trail: Trail,
        stepping: (Trail, Place.Step) -> Trail
    ) -> [(Trail, Expression)] {
        body.buried(at: stepping(trail, .key("body")), stepping: stepping)
            + (result.map { result in
                result.buried(at: stepping(trail, .key("result")), stepping: stepping)
            } ?? [])
    }
}

public extension [Statement] {
    // A statement is found under its own name — or, one run for its effect
    // alone, under its position, which is the only thing there is to call it —
    // and then under the construct key it writes, the way a document nests it.
    func buried<Trail>(
        at trail: Trail,
        stepping: (Trail, Place.Step) -> Trail
    ) -> [(Trail, Expression)] {
        enumerated().flatMap { position, statement in
            statement.expression.buried(
                at: stepping(
                    stepping(trail, .statement(name: statement.id, at: position)),
                    .landmark(statement.expression.constructKey)
                ),
                stepping: stepping
            )
        }
    }
}
