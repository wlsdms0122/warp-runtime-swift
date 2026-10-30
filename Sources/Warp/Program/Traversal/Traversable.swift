//
//  Traversable.swift
//  Warp
//
//  Created by JSilver on 9/25/26.
//

import Foundation

// What can be walked for everything it holds: one walk over the language for
// every stage that has to see all of it, which differ only in what they keep.
//
// Where a thing was found is the caller's to name: it travels as a value the
// caller hands in, along with how to step into one, and a caller wanting
// nowhere hands in nothing. A step is a `Place.Step` rather than a name,
// because a statement is found by its name and by its position and only one
// of those is always there.
protocol Traversable {
    // Everything held in here, each with where it was found, appended to
    // `found`, each thing before what it holds.
    // Filled rather than returned, so a level of a tree nested to the bound
    // spends little stack and copies nothing it found.
    func walk<Trail>(at trail: Trail, stepping: (Trail, Place.Step) -> Trail, into found: inout [(Trail, Node)])
}

extension Traversable {
    // Everything held in here, each with where it was found.
    func walked<Trail>(at trail: Trail, stepping: (Trail, Place.Step) -> Trail) -> [(Trail, Node)] {
        var found: [(Trail, Node)] = []

        walk(at: trail, stepping: stepping, into: &found)

        return found
    }

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
