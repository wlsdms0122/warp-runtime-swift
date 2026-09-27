//
//  Traversable.swift
//  Warp
//
//  Created by JSilver on 9/25/26.
//

import Foundation

// One walk over everything an expression holds, for every stage that has to
// see all of it.
//
// Three of them ask for exactly this and differ only in what they keep: the
// declaration scan wants the closure literals a body buries, the same scan
// wants the types its casts name, and the check wants the selectors a module
// sends. Written out per collector, one walk over the language is written three
// times, and a case added to `Expression` reaches whichever copies somebody
// remembered.
//
// Where a thing was found is the caller's to name. A stage that reports has a
// place to extend, and a stage that only gathers has nothing to carry, so where
// a thing is travels as a value the caller hands in, along with how to step
// into one, and the caller wanting nowhere hands in nothing.
//
// A step is a `Place.Step` rather than a name, because a statement is found by
// its name and by its position and only one of those is always there. Handing
// the step over whole is what lets a caller keep both; a name would have made
// this walk choose between them on every stage's behalf.

// What can be walked for everything it holds. Three types answer it, and the
// convenient ways to ask are written once here rather than three times over.
// The same duplication this file exists to remove, at the smaller scale where
// it is easy not to notice.
public protocol Traversable {
    // Everything held in here, each with where it was found.
    func walked<Trail>(at trail: Trail, stepping: (Trail, Place.Step) -> Trail) -> [(Trail, Node)]
}

public extension Traversable {
    // Every expression held in here, each with where it was found.
    func subexpressions<Trail>(
        at trail: Trail,
        stepping: (Trail, Place.Step) -> Trail
    ) -> [(Trail, Expression)] {
        walked(at: trail, stepping: stepping).compactMap { found -> (Trail, Expression)? in
            guard case let .expression(expression) = found.1 else { return nil }

            return (found.0, expression)
        }
    }

    // The walk a stage that reports takes.
    func subexpressions(at place: Place) -> [(Place, Expression)] {
        subexpressions(at: place) { place, step in place.appending(step) }
    }

    // The walk a stage that only gathers takes. Nothing is carried, so nothing
    // is spelled.
    var subexpressions: [Expression] {
        subexpressions(at: ()) { _, _ in () }.map(\.1)
    }

    // The same walk, keeping the statements too. What is held where is a
    // fact of the language and a stage that reads both asks for both.
    var nodes: [Node] {
        walked(at: ()) { _, _ in () }.map(\.1)
    }

    // Every type a name in here says it holds, each with where it was said.
    func declaring(at place: Place) -> [(Place, TypeExpression)] {
        walked(at: place) { place, step in place.appending(step) }
            .compactMap { found -> (Place, TypeExpression)? in
                guard
                    case let .statement(statement) = found.1,
                    let declared = statement.binding?.declared
                else { return nil }

                return (found.0, declared)
            }
    }
}
